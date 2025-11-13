"""
Implementación PostgreSQL del repositorio de préstamos.

⭐ CRÍTICO: Este módulo interactúa con funciones DB de fechas.
Sistema de doble calendario implementado en: calculate_first_payment_date()
"""
from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional

from sqlalchemy import select, func, and_, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.loans.domain.entities import Loan, LoanBalance
from app.modules.loans.domain.repositories import LoanRepository
from app.modules.loans.infrastructure.models import LoanModel


# =============================================================================
# MAPPERS: Model ↔ Entity
# =============================================================================

def _map_loan_model_to_entity(model: LoanModel) -> Loan:
    """
    Convierte LoanModel (SQLAlchemy) a Loan (entidad de dominio).
    
    Args:
        model: Instancia de LoanModel
        
    Returns:
        Instancia de Loan (entidad pura)
    """
    return Loan(
        id=model.id,
        user_id=model.user_id,
        associate_user_id=model.associate_user_id,
        amount=Decimal(str(model.amount)),
        interest_rate=Decimal(str(model.interest_rate)),
        commission_rate=Decimal(str(model.commission_rate)),
        term_biweeks=model.term_biweeks,
        profile_code=model.profile_code,
        # Campos calculados (pueden ser None si no se han calculado)
        biweekly_payment=Decimal(str(model.biweekly_payment)) if model.biweekly_payment is not None else None,
        total_payment=Decimal(str(model.total_payment)) if model.total_payment is not None else None,
        total_interest=Decimal(str(model.total_interest)) if model.total_interest is not None else None,
        total_commission=Decimal(str(model.total_commission)) if model.total_commission is not None else None,
        commission_per_payment=Decimal(str(model.commission_per_payment)) if model.commission_per_payment is not None else None,
        associate_payment=Decimal(str(model.associate_payment)) if model.associate_payment is not None else None,
        # Resto de campos
        status_id=model.status_id,
        contract_id=model.contract_id,
        approved_at=model.approved_at,
        approved_by=model.approved_by,
        rejected_at=model.rejected_at,
        rejected_by=model.rejected_by,
        rejection_reason=model.rejection_reason,
        notes=model.notes,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _map_loan_entity_to_model(entity: Loan, model: Optional[LoanModel] = None) -> LoanModel:
    """
    Convierte Loan (entidad) a LoanModel (SQLAlchemy).
    
    Args:
        entity: Instancia de Loan
        model: LoanModel existente a actualizar (opcional)
        
    Returns:
        Instancia de LoanModel
    """
    if model is None:
        model = LoanModel()
    
    # No setear id si es None (se autogenera en BD)
    if entity.id is not None:
        model.id = entity.id
    
    model.user_id = entity.user_id
    model.associate_user_id = entity.associate_user_id
    model.amount = entity.amount
    model.interest_rate = entity.interest_rate
    model.commission_rate = entity.commission_rate
    model.term_biweeks = entity.term_biweeks
    model.profile_code = entity.profile_code
    
    # Campos calculados (solo setear si no son None)
    if entity.biweekly_payment is not None:
        model.biweekly_payment = entity.biweekly_payment
    if entity.total_payment is not None:
        model.total_payment = entity.total_payment
    if entity.total_interest is not None:
        model.total_interest = entity.total_interest
    if entity.total_commission is not None:
        model.total_commission = entity.total_commission
    if entity.commission_per_payment is not None:
        model.commission_per_payment = entity.commission_per_payment
    if entity.associate_payment is not None:
        model.associate_payment = entity.associate_payment
    
    model.status_id = entity.status_id
    model.contract_id = entity.contract_id
    model.approved_at = entity.approved_at
    model.approved_by = entity.approved_by
    model.rejected_at = entity.rejected_at
    model.rejected_by = entity.rejected_by
    model.rejection_reason = entity.rejection_reason
    model.notes = entity.notes
    
    # created_at y updated_at son gestionados por la BD
    
    return model


# =============================================================================
# REPOSITORIO POSTGRESQL
# =============================================================================

class PostgreSQLLoanRepository(LoanRepository):
    """
    Implementación PostgreSQL del repositorio de préstamos.
    
    Usa AsyncSession para operaciones asíncronas.
    Interactúa con funciones DB críticas:
    - calculate_first_payment_date() ⭐ ORÁCULO DEL DOBLE CALENDARIO
    - calculate_loan_remaining_balance()
    - check_associate_credit_available()
    """
    
    def __init__(self, session: AsyncSession):
        """
        Constructor.
        
        Args:
            session: Sesión asíncrona de SQLAlchemy
        """
        self.session = session
    
    # =============================================================================
    # QUERIES (Lectura)
    # =============================================================================
    
    async def find_by_id(self, loan_id: int) -> Optional[Loan]:
        """
        Busca un préstamo por su ID.
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            Loan si existe, None si no
        """
        result = await self.session.execute(
            select(LoanModel).where(LoanModel.id == loan_id)
        )
        model = result.scalar_one_or_none()
        
        return _map_loan_model_to_entity(model) if model else None
    
    async def find_all(
        self,
        status_id: Optional[int] = None,
        user_id: Optional[int] = None,
        associate_user_id: Optional[int] = None,
        limit: int = 50,
        offset: int = 0
    ) -> List[Loan]:
        """
        Lista préstamos con filtros opcionales.
        
        Args:
            status_id: Filtrar por estado (opcional)
            user_id: Filtrar por cliente (opcional)
            associate_user_id: Filtrar por asociado (opcional)
            limit: Máximo de registros (default 50)
            offset: Desplazamiento para paginación (default 0)
            
        Returns:
            Lista de préstamos
        """
        # Construir query base
        query = select(LoanModel)
        
        # Aplicar filtros dinámicos
        conditions = []
        if status_id is not None:
            conditions.append(LoanModel.status_id == status_id)
        if user_id is not None:
            conditions.append(LoanModel.user_id == user_id)
        if associate_user_id is not None:
            conditions.append(LoanModel.associate_user_id == associate_user_id)
        
        if conditions:
            query = query.where(and_(*conditions))
        
        # Ordenar por más reciente primero
        query = query.order_by(LoanModel.created_at.desc())
        
        # Paginación
        query = query.limit(limit).offset(offset)
        
        # Ejecutar
        result = await self.session.execute(query)
        models = result.scalars().all()
        
        return [_map_loan_model_to_entity(m) for m in models]
    
    async def count(
        self,
        status_id: Optional[int] = None,
        user_id: Optional[int] = None,
        associate_user_id: Optional[int] = None
    ) -> int:
        """
        Cuenta préstamos con filtros opcionales.
        
        Args:
            status_id: Filtrar por estado (opcional)
            user_id: Filtrar por cliente (opcional)
            associate_user_id: Filtrar por asociado (opcional)
            
        Returns:
            Total de préstamos que coinciden con filtros
        """
        # Construir query base
        query = select(func.count(LoanModel.id))
        
        # Aplicar filtros dinámicos
        conditions = []
        if status_id is not None:
            conditions.append(LoanModel.status_id == status_id)
        if user_id is not None:
            conditions.append(LoanModel.user_id == user_id)
        if associate_user_id is not None:
            conditions.append(LoanModel.associate_user_id == associate_user_id)
        
        if conditions:
            query = query.where(and_(*conditions))
        
        # Ejecutar
        result = await self.session.execute(query)
        return result.scalar()
    
    async def get_balance(self, loan_id: int) -> Optional[LoanBalance]:
        """
        Obtiene el balance actual de un préstamo.
        
        Usa la función DB: calculate_loan_remaining_balance()
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            LoanBalance si el préstamo existe, None si no
        """
        # Primero verificar que el préstamo existe
        loan = await self.find_by_id(loan_id)
        if not loan:
            return None
        
        # Calcular balance usando función DB
        remaining_query = select(
            func.calculate_loan_remaining_balance(loan_id)
        )
        remaining_result = await self.session.execute(remaining_query)
        remaining_balance = Decimal(str(remaining_result.scalar()))
        
        # Obtener total pagado desde payments
        # TODO: Cuando implementemos payments, usar:
        # SELECT SUM(amount_paid) FROM payments WHERE loan_id = loan_id
        # Por ahora, calculamos como: total - remaining
        total_amount = loan.amount
        total_paid = total_amount - remaining_balance
        
        # Contar pagos completados
        # TODO: Cuando implementemos payments, usar:
        # SELECT COUNT(*) FROM payments WHERE loan_id = loan_id AND status_id = PAID
        # Por ahora, asumimos 0
        payments_completed = 0
        
        return LoanBalance(
            loan_id=loan.id,
            total_amount=total_amount,
            total_paid=total_paid,
            remaining_balance=remaining_balance,
            payment_count=loan.term_biweeks,
            payments_completed=payments_completed
        )
    
    # =============================================================================
    # COMMANDS (Escritura) - IMPLEMENTAR EN SPRINT 2
    # =============================================================================
    
    async def create(self, loan: Loan) -> Loan:
        """
        Crea un nuevo préstamo.
        
        Args:
            loan: Entidad Loan (sin ID)
            
        Returns:
            Loan con ID asignado por la BD
        """
        model = _map_loan_entity_to_model(loan)
        self.session.add(model)
        await self.session.flush()  # Para obtener el ID generado
        await self.session.refresh(model)  # Refrescar datos de BD (created_at, etc.)
        
        return _map_loan_model_to_entity(model)
    
    async def update(self, loan: Loan) -> Loan:
        """
        Actualiza un préstamo existente.
        
        Args:
            loan: Entidad Loan con ID
            
        Returns:
            Loan actualizado
        """
        # Obtener modelo existente
        result = await self.session.execute(
            select(LoanModel).where(LoanModel.id == loan.id)
        )
        model = result.scalar_one_or_none()
        
        if not model:
            raise ValueError(f"Préstamo con ID {loan.id} no encontrado")
        
        # Actualizar campos
        _map_loan_entity_to_model(loan, model)
        await self.session.flush()
        await self.session.refresh(model)
        
        return _map_loan_model_to_entity(model)
    
    async def delete(self, loan_id: int) -> bool:
        """
        Elimina un préstamo (solo si está en PENDING o REJECTED).
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            True si se eliminó, False si no existía
        """
        result = await self.session.execute(
            select(LoanModel).where(LoanModel.id == loan_id)
        )
        model = result.scalar_one_or_none()
        
        if not model:
            return False
        
        # Validar que pueda eliminarse
        if model.status_id not in (1, 6):  # PENDING o REJECTED
            raise ValueError(
                f"No se puede eliminar préstamo en estado {model.status_id}. "
                f"Solo se pueden eliminar préstamos PENDING o REJECTED."
            )
        
        await self.session.delete(model)
        await self.session.flush()
        
        return True
    
    # =============================================================================
    # VALIDACIONES Y HELPERS ⭐ FUNCIONES DB
    # =============================================================================
    
    async def check_associate_credit_available(
        self,
        associate_user_id: int,
        amount: Decimal
    ) -> bool:
        """
        Verifica si el asociado tiene crédito disponible suficiente.
        
        Usa la función DB: check_associate_credit_available()
        
        Args:
            associate_user_id: ID del usuario asociado
            amount: Monto del préstamo solicitado
            
        Returns:
            True si tiene crédito suficiente, False si no
        """
        # Primero obtener el associate_profile_id del user_id usando query nativa
        profile_query = text(
            "SELECT id FROM associate_profiles WHERE user_id = :user_id"
        )
        
        profile_result = await self.session.execute(
            profile_query,
            {"user_id": associate_user_id}
        )
        profile_row = profile_result.fetchone()
        
        if not profile_row:
            # Si no tiene perfil de asociado, no puede otorgar préstamos
            return False
        
        associate_profile_id = profile_row[0]
        
        # Llamar función DB con el associate_profile_id correcto
        query = select(
            func.check_associate_credit_available(
                associate_profile_id,
                amount
            )
        )
        result = await self.session.execute(query)
        has_credit = result.scalar()
        
        return bool(has_credit)
    
    async def calculate_first_payment_date(self, approval_date: date) -> date:
        """
        Calcula la fecha del primer pago según el doble calendario.
        
        ⭐ CRÍTICO: Usa la función DB calculate_first_payment_date()
        
        Esta función implementa el sistema de doble calendario:
        - Aprobación días 1-7: Primer pago día 15 del mismo mes
        - Aprobación días 8-22: Primer pago último día del mismo mes
        - Aprobación días 23-31: Primer pago día 15 del siguiente mes
        
        Args:
            approval_date: Fecha de aprobación del préstamo
            
        Returns:
            Fecha del primer pago
            
        Raises:
            ValueError: Si approval_date es inválido o la función DB falla
        """
        try:
            # Llamar función DB (IMMUTABLE, STRICT, PARALLEL SAFE)
            query = select(
                func.calculate_first_payment_date(approval_date)
            )
            result = await self.session.execute(query)
            first_payment_date = result.scalar()
            
            if first_payment_date is None:
                raise ValueError(
                    f"La función DB calculate_first_payment_date() retornó NULL "
                    f"para approval_date={approval_date}. Fecha inválida."
                )
            
            return first_payment_date
            
        except Exception as e:
            raise ValueError(
                f"Error al calcular primera fecha de pago para {approval_date}: {str(e)}"
            ) from e
    
    async def has_pending_loans(self, user_id: int) -> bool:
        """
        Verifica si el cliente tiene préstamos pendientes de aprobación.
        
        Args:
            user_id: ID del cliente
            
        Returns:
            True si tiene préstamos PENDING, False si no
        """
        query = select(func.count(LoanModel.id)).where(
            and_(
                LoanModel.user_id == user_id,
                LoanModel.status_id == 1  # PENDING
            )
        )
        result = await self.session.execute(query)
        count = result.scalar()
        
        return count > 0
    
    async def is_client_defaulter(self, user_id: int) -> bool:
        """
        Verifica si el cliente está marcado como moroso.
        
        NOTA: Esta lógica está en la tabla users (is_defaulter).
        Por ahora retornamos False, se implementará cuando tengamos
        el módulo de users completo.
        
        Args:
            user_id: ID del cliente
            
        Returns:
            True si es moroso, False si no
        """
        # TODO: Implementar cuando tengamos UserModel
        # query = select(UserModel.is_defaulter).where(UserModel.id == user_id)
        # result = await self.session.execute(query)
        # is_defaulter = result.scalar()
        # return bool(is_defaulter)
        
        return False  # Por ahora, ningún cliente es moroso


__all__ = [
    'PostgreSQLLoanRepository',
    '_map_loan_model_to_entity',
    '_map_loan_entity_to_model',
]
