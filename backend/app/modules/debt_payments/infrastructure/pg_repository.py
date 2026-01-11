"""
Repositorio PostgreSQL para Debt Payments.
"""
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import text

from ..domain.entities import DebtPayment
from .models import DebtPaymentModel


class PgDebtPaymentRepository:
    """
    Repositorio para gestionar pagos de deuda en PostgreSQL.
    
    La lógica FIFO se maneja automáticamente por el trigger de base de datos.
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def create(
        self,
        associate_profile_id: int,
        payment_amount: float,
        payment_date: str,
        payment_method_id: int,
        payment_reference: Optional[str],
        registered_by: int,
        notes: Optional[str]
    ) -> DebtPayment:
        """
        Registra un nuevo pago de deuda.
        
        El trigger `trigger_apply_debt_payment_fifo` se ejecuta automáticamente:
        1. Aplica FIFO para liquidar items de deuda (oldest first)
        2. Actualiza consolidated_debt en associate_profiles
        3. Llena applied_breakdown_items con el detalle
        
        Args:
            associate_profile_id: ID del perfil del asociado
            payment_amount: Monto del abono
            payment_date: Fecha del pago
            payment_method_id: Método de pago
            payment_reference: Referencia bancaria (opcional)
            registered_by: Usuario que registra el pago
            notes: Notas adicionales (opcional)
        
        Returns:
            DebtPayment: Entidad con el pago registrado y items aplicados
        """
        model = DebtPaymentModel(
            associate_profile_id=associate_profile_id,
            payment_amount=payment_amount,
            payment_date=payment_date,
            payment_method_id=payment_method_id,
            payment_reference=payment_reference,
            registered_by=registered_by,
            notes=notes
        )
        
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        
        return self._to_entity(model)
    
    def find_by_id(self, payment_id: int) -> Optional[DebtPayment]:
        """Buscar pago por ID."""
        model = self.db.query(DebtPaymentModel).filter(
            DebtPaymentModel.id == payment_id
        ).first()
        
        return self._to_entity(model) if model else None
    
    def find_by_associate(
        self,
        associate_profile_id: int,
        limit: int = 50,
        offset: int = 0
    ) -> List[DebtPayment]:
        """Listar pagos de un asociado."""
        models = self.db.query(DebtPaymentModel).filter(
            DebtPaymentModel.associate_profile_id == associate_profile_id
        ).order_by(
            DebtPaymentModel.payment_date.desc(),
            DebtPaymentModel.id.desc()
        ).limit(limit).offset(offset).all()
        
        return [self._to_entity(m) for m in models]
    
    def get_associate_debt_summary(self, associate_profile_id: int) -> Optional[dict]:
        """
        Obtiene el resumen de deuda de un asociado desde la vista.
        
        Utiliza v_associate_debt_summary que ya tiene toda la información agregada.
        """
        result = self.db.execute(text("""
            SELECT 
                associate_profile_id,
                associate_name,
                current_consolidated_debt,
                pending_debt_items,
                liquidated_debt_items,
                total_pending_debt,
                total_paid_to_debt,
                oldest_debt_date,
                last_payment_date,
                total_debt_payments_count,
                available_credit,
                credit_limit
            FROM v_associate_debt_summary
            WHERE associate_profile_id = :associate_id
        """), {"associate_id": associate_profile_id}).fetchone()
        
        if not result:
            return None
        
        return {
            "associate_profile_id": result[0],
            "associate_name": result[1],
            "current_consolidated_debt": float(result[2]) if result[2] else 0.0,
            "pending_debt_items": result[3] or 0,
            "liquidated_debt_items": result[4] or 0,
            "total_paid_to_debt": float(result[6]) if result[6] else 0.0,
            "oldest_debt_date": result[7],
            "last_payment_date": result[8],
            "total_payments_count": result[9] or 0,
            "available_credit": float(result[10]) if result[10] else 0.0,
            "credit_limit": float(result[11]) if result[11] else 0.0
        }
    
    def _to_entity(self, model: DebtPaymentModel) -> DebtPayment:
        """Convertir modelo a entidad de dominio."""
        return DebtPayment(
            id=model.id,
            associate_profile_id=model.associate_profile_id,
            payment_amount=model.payment_amount,
            payment_date=model.payment_date,
            payment_method_id=model.payment_method_id,
            payment_reference=model.payment_reference,
            registered_by=model.registered_by,
            applied_breakdown_items=model.applied_breakdown_items or [],
            notes=model.notes,
            created_at=model.created_at,
            updated_at=model.updated_at
        )
