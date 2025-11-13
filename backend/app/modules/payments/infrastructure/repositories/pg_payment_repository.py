"""
Implementación PostgreSQL del repositorio de pagos.

Implementa PaymentRepository usando SQLAlchemy y PostgreSQL.
"""
from datetime import date
from decimal import Decimal
from typing import List, Optional

from sqlalchemy import select, and_, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.payments.domain.entities import Payment
from app.modules.payments.domain.repositories import PaymentRepository
from app.modules.payments.infrastructure.models import PaymentModel


# =============================================================================
# MAPPERS: Model ↔ Entity
# =============================================================================

def _map_payment_model_to_entity(model: PaymentModel) -> Payment:
    """
    Convierte PaymentModel (SQLAlchemy) a Payment (entidad de dominio).
    
    Args:
        model: Instancia de PaymentModel
        
    Returns:
        Instancia de Payment (entidad pura)
    """
    return Payment(
        id=model.id,
        loan_id=model.loan_id,
        payment_number=model.payment_number,
        expected_amount=Decimal(str(model.expected_amount)) if model.expected_amount is not None else None,
        interest_amount=Decimal(str(model.interest_amount)) if model.interest_amount is not None else None,
        principal_amount=Decimal(str(model.principal_amount)) if model.principal_amount is not None else None,
        commission_amount=Decimal(str(model.commission_amount)) if model.commission_amount is not None else None,
        associate_payment=Decimal(str(model.associate_payment)) if model.associate_payment is not None else None,
        balance_remaining=Decimal(str(model.balance_remaining)) if model.balance_remaining is not None else None,
        amount_paid=Decimal(str(model.amount_paid)),
        payment_date=model.payment_date,
        payment_due_date=model.payment_due_date,
        is_late=model.is_late,
        status_id=model.status_id,
        cut_period_id=model.cut_period_id,
        marked_by=model.marked_by,
        marked_at=model.marked_at,
        marking_notes=model.marking_notes,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _map_payment_entity_to_model(entity: Payment, model: Optional[PaymentModel] = None) -> PaymentModel:
    """
    Convierte Payment (entidad) a PaymentModel (SQLAlchemy).
    
    Args:
        entity: Instancia de Payment
        model: PaymentModel existente a actualizar (opcional)
        
    Returns:
        Instancia de PaymentModel
    """
    if model is None:
        model = PaymentModel()
    
    # No setear id si es None (se autogenera en BD)
    if entity.id is not None:
        model.id = entity.id
    
    model.loan_id = entity.loan_id
    model.payment_number = entity.payment_number
    model.expected_amount = entity.expected_amount
    model.interest_amount = entity.interest_amount
    model.principal_amount = entity.principal_amount
    model.commission_amount = entity.commission_amount
    model.associate_payment = entity.associate_payment
    model.balance_remaining = entity.balance_remaining
    model.amount_paid = entity.amount_paid
    model.payment_date = entity.payment_date
    model.payment_due_date = entity.payment_due_date
    model.is_late = entity.is_late
    model.status_id = entity.status_id
    model.cut_period_id = entity.cut_period_id
    model.marked_by = entity.marked_by
    model.marked_at = entity.marked_at
    model.marking_notes = entity.marking_notes
    
    return model


# =============================================================================
# REPOSITORIO POSTGRESQL
# =============================================================================

class PgPaymentRepository(PaymentRepository):
    """
    Implementación PostgreSQL de PaymentRepository.
    
    Usa SQLAlchemy AsyncSession para operaciones asíncronas.
    """
    
    def __init__(self, db: AsyncSession):
        """
        Constructor.
        
        Args:
            db: Sesión asíncrona de SQLAlchemy
        """
        self._db = db
    
    async def find_by_id(self, payment_id: int) -> Optional[Payment]:
        """
        Busca un pago por su ID.
        
        Args:
            payment_id: ID del pago
            
        Returns:
            Payment si existe, None si no
        """
        stmt = select(PaymentModel).where(PaymentModel.id == payment_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_payment_model_to_entity(model) if model else None
    
    async def find_by_loan_id(
        self,
        loan_id: int,
        pending_only: bool = False
    ) -> List[Payment]:
        """
        Busca todos los pagos de un préstamo.
        
        Args:
            loan_id: ID del préstamo
            pending_only: Si True, solo pagos pendientes
            
        Returns:
            Lista de Payment ordenados por payment_number
        """
        stmt = select(PaymentModel).where(PaymentModel.loan_id == loan_id)
        
        if pending_only:
            # Asumiendo que status_id=1 es "Pendiente" (ajustar según catálogo)
            stmt = stmt.where(PaymentModel.status_id == 1)
        
        stmt = stmt.order_by(PaymentModel.payment_number)
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_payment_model_to_entity(m) for m in models]
    
    async def find_pending_by_loan_id(self, loan_id: int) -> List[Payment]:
        """
        Busca pagos pendientes de un préstamo.
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            Lista de Payment pendientes
        """
        return await self.find_by_loan_id(loan_id, pending_only=True)
    
    async def find_overdue_payments(self, loan_id: Optional[int] = None) -> List[Payment]:
        """
        Busca pagos vencidos (is_late=True).
        
        Args:
            loan_id: Filtrar por préstamo específico (opcional)
            
        Returns:
            Lista de Payment vencidos
        """
        stmt = select(PaymentModel).where(PaymentModel.is_late == True)
        
        if loan_id is not None:
            stmt = stmt.where(PaymentModel.loan_id == loan_id)
        
        stmt = stmt.order_by(PaymentModel.payment_due_date)
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_payment_model_to_entity(m) for m in models]
    
    async def register_payment(
        self,
        payment_id: int,
        amount_paid: Decimal,
        payment_date: date,
        marked_by: int,
        notes: Optional[str] = None
    ) -> Payment:
        """
        Registra un pago (marca como pagado).
        
        ⚠️ IMPORTANTE: Este método NO actualiza el crédito del asociado manualmente.
        El trigger update_associate_credit_on_payment en PostgreSQL se ejecuta
        automáticamente cuando se actualiza amount_paid.
        
        Args:
            payment_id: ID del pago
            amount_paid: Monto pagado
            payment_date: Fecha del pago
            marked_by: ID del usuario que registra el pago
            notes: Notas adicionales
            
        Returns:
            Payment actualizado
            
        Raises:
            ValueError: Si el pago no existe
        """
        # 1. Buscar el pago
        stmt = select(PaymentModel).where(PaymentModel.id == payment_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        if not model:
            raise ValueError(f"Payment {payment_id} not found")
        
        # 2. Actualizar campos
        model.amount_paid = amount_paid
        model.payment_date = payment_date
        model.marked_by = marked_by
        model.marked_at = func.now()
        model.marking_notes = notes
        
        # 3. Determinar nuevo status_id
        # Asumiendo: 1=Pendiente, 2=Pagado, 3=Pago Parcial (ajustar según catálogo)
        if model.expected_amount is not None:
            if amount_paid >= model.expected_amount:
                model.status_id = 2  # Pagado
            elif amount_paid > Decimal('0'):
                model.status_id = 3  # Pago Parcial
        else:
            # Si no hay expected_amount, considerar pagado si amount_paid > 0
            model.status_id = 2 if amount_paid > Decimal('0') else 1
        
        # 4. Guardar (trigger DB se ejecuta automáticamente)
        await self._db.flush()
        await self._db.refresh(model)
        
        return _map_payment_model_to_entity(model)
    
    async def update_status(
        self,
        payment_id: int,
        status_id: int,
        marked_by: int,
        reason: Optional[str] = None
    ) -> Payment:
        """
        Actualiza el estado de un pago manualmente.
        
        Args:
            payment_id: ID del pago
            status_id: Nuevo status_id
            marked_by: ID del usuario que actualiza
            reason: Razón del cambio
            
        Returns:
            Payment actualizado
            
        Raises:
            ValueError: Si el pago no existe
        """
        stmt = select(PaymentModel).where(PaymentModel.id == payment_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        if not model:
            raise ValueError(f"Payment {payment_id} not found")
        
        model.status_id = status_id
        model.marked_by = marked_by
        model.marked_at = func.now()
        model.marking_notes = reason
        
        await self._db.flush()
        await self._db.refresh(model)
        
        return _map_payment_model_to_entity(model)
    
    async def get_payment_summary(self, loan_id: int) -> dict:
        """
        Obtiene resumen de pagos de un préstamo.
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            Diccionario con:
            - total_payments: Total de pagos programados
            - payments_paid: Pagos completados
            - payments_pending: Pagos pendientes
            - payments_overdue: Pagos vencidos
            - total_paid_amount: Suma de amount_paid
            - total_expected_amount: Suma de expected_amount
        """
        # Contar pagos por estado (asumiendo status_id: 1=Pendiente, 2=Pagado)
        stmt_counts = select(
            func.count(PaymentModel.id).label('total_payments'),
            func.sum(
                func.cast(PaymentModel.status_id == 2, PaymentModel.id.type)
            ).label('payments_paid'),
            func.sum(
                func.cast(PaymentModel.status_id == 1, PaymentModel.id.type)
            ).label('payments_pending'),
            func.sum(
                func.cast(PaymentModel.is_late == True, PaymentModel.id.type)
            ).label('payments_overdue'),
            func.coalesce(func.sum(PaymentModel.amount_paid), Decimal('0')).label('total_paid_amount'),
            func.coalesce(func.sum(PaymentModel.expected_amount), Decimal('0')).label('total_expected_amount'),
        ).where(PaymentModel.loan_id == loan_id)
        
        result = await self._db.execute(stmt_counts)
        row = result.one()
        
        return {
            'total_payments': row.total_payments or 0,
            'payments_paid': row.payments_paid or 0,
            'payments_pending': row.payments_pending or 0,
            'payments_overdue': row.payments_overdue or 0,
            'total_paid_amount': Decimal(str(row.total_paid_amount)),
            'total_expected_amount': Decimal(str(row.total_expected_amount)),
        }
    
    async def get_next_payment_due(self, loan_id: int) -> Optional[Payment]:
        """
        Obtiene el siguiente pago pendiente de un préstamo.
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            Payment del siguiente pago pendiente, None si no hay
        """
        stmt = (
            select(PaymentModel)
            .where(
                and_(
                    PaymentModel.loan_id == loan_id,
                    PaymentModel.status_id == 1  # Pendiente
                )
            )
            .order_by(PaymentModel.payment_number)
            .limit(1)
        )
        
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_payment_model_to_entity(model) if model else None
    
    async def get_last_payment(self, loan_id: int) -> Optional[Payment]:
        """
        Obtiene el último pago registrado de un préstamo.
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            Payment del último pago, None si no hay pagos
        """
        stmt = (
            select(PaymentModel)
            .where(
                and_(
                    PaymentModel.loan_id == loan_id,
                    PaymentModel.status_id == 2  # Pagado
                )
            )
            .order_by(desc(PaymentModel.payment_date))
            .limit(1)
        )
        
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_payment_model_to_entity(model) if model else None
    
    async def find_by_cut_period(self, cut_period_id: int) -> List[Payment]:
        """
        Obtiene todos los pagos de un periodo de corte.
        
        Args:
            cut_period_id: ID del periodo de corte
            
        Returns:
            Lista de pagos del periodo ordenados por loan_id, payment_number
        """
        stmt = (
            select(PaymentModel)
            .where(PaymentModel.cut_period_id == cut_period_id)
            .order_by(PaymentModel.loan_id, PaymentModel.payment_number)
        )
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_payment_model_to_entity(m) for m in models]

    async def mark_payment(
        self,
        payment_id: int,
        amount_paid: Decimal,
        marked_by: int,
        marked_at: date,
        notes: Optional[str] = None
    ) -> Payment:
        """
        Marca un pago como pagado (total o parcial).
        
        Args:
            payment_id: ID del pago
            amount_paid: Monto pagado
            marked_by: ID del usuario que marcó el pago
            marked_at: Fecha/hora en que se marcó
            notes: Notas opcionales del pago
            
        Returns:
            Entidad Payment actualizada
            
        Raises:
            ValueError: Si el pago no existe
        """
        # Buscar el pago
        stmt = select(PaymentModel).where(PaymentModel.id == payment_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        if not model:
            raise ValueError(f"Payment {payment_id} not found")
        
        # Actualizar campos
        model.amount_paid = float(amount_paid)
        model.marked_by = marked_by
        model.marked_at = marked_at
        model.marking_notes = notes
        
        # Persistir cambios
        await self._db.flush()
        await self._db.refresh(model)
        
        # Retornar entidad actualizada
        return _map_payment_model_to_entity(model)
