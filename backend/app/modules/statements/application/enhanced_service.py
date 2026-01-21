"""
Módulo de servicios mejorados para Statements.
Elimina la necesidad de TODOs en las rutas.
"""

from typing import Dict, Any, List, Optional
from decimal import Decimal
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..application.dtos import StatementResponseDTO, StatementSummaryDTO


class StatementEnhancedService:
    """
    Servicio mejorado para statements con JOINs automáticos.
    Elimina los TODOs de las rutas al proveer datos completos.
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_statement_with_details(self, statement_id: int) -> Optional[Dict[str, Any]]:
        """
        Obtiene un statement con TODOS los datos relacionados (JOINs).
        
        Returns:
            Dict con todos los campos incluyendo:
            - associate_name (en lugar de "TODO")
            - period_code (en lugar de "TODO")
            - status_name (en lugar de "TODO")
            - payment_method_name (en lugar de None)
        """
        query = text("""
            SELECT 
                aps.id,
                aps.statement_number,
                aps.user_id,
                CONCAT(u.first_name, ' ', u.last_name) as associate_name,
                aps.cut_period_id,
                cp.cut_code as period_code,
                aps.total_payments_count,
                aps.total_amount_collected,
                aps.total_to_credicuenta,
                aps.commission_earned,
                aps.commission_rate_applied,
                aps.status_id,
                ss.name as status_name,
                aps.generated_date,
                aps.sent_date,
                aps.due_date,
                aps.paid_date,
                aps.paid_amount,
                aps.payment_method_id,
                pm.name as payment_method_name,
                aps.payment_reference,
                aps.late_fee_amount,
                aps.late_fee_applied,
                aps.created_at,
                aps.updated_at
            FROM associate_payment_statements aps
            JOIN users u ON aps.user_id = u.id
            JOIN cut_periods cp ON aps.cut_period_id = cp.id
            JOIN statement_statuses ss ON aps.status_id = ss.id
            LEFT JOIN payment_methods pm ON aps.payment_method_id = pm.id
            WHERE aps.id = :statement_id
        """)
        
        result = self.db.execute(query, {"statement_id": statement_id}).fetchone()
        
        if not result:
            return None
        
        # Calcular campos derivados
        paid_amount = result.paid_amount or Decimal("0.00")
        # total_to_credicuenta es el monto que el asociado debe pagar a CrediCuenta
        remaining_amount = result.total_to_credicuenta - paid_amount + result.late_fee_amount
        
        # Determinar estado
        is_paid = paid_amount >= result.total_to_credicuenta
        from datetime import datetime
        is_overdue = (
            not is_paid and 
            result.due_date < datetime.now().date()
        )
        days_overdue = (
            (datetime.now().date() - result.due_date).days 
            if is_overdue else 0
        )
        
        return {
            "id": result.id,
            "statement_number": result.statement_number,
            "user_id": result.user_id,
            "associate_name": result.associate_name,  # ✅ Ya no es "TODO"
            "cut_period_id": result.cut_period_id,
            "cut_period_code": result.period_code,  # ✅ Ya no es "TODO"
            "total_payments_count": result.total_payments_count,
            "total_amount_collected": result.total_amount_collected,
            "total_to_credicuenta": result.total_to_credicuenta,
            "commission_earned": result.commission_earned,
            "commission_rate_applied": result.commission_rate_applied,
            "status_id": result.status_id,
            "status_name": result.status_name,  # ✅ Ya no es "TODO"
            "generated_date": result.generated_date,
            "sent_date": result.sent_date,
            "due_date": result.due_date,
            "paid_date": result.paid_date,
            "paid_amount": paid_amount,
            "payment_method_id": result.payment_method_id,
            "payment_method_name": result.payment_method_name,  # ✅ Ya no es None
            "payment_reference": result.payment_reference,
            "late_fee_amount": result.late_fee_amount,
            "late_fee_applied": result.late_fee_applied,
            "is_paid": is_paid,
            "is_overdue": is_overdue,
            "days_overdue": days_overdue,
            "remaining_amount": remaining_amount,
            "created_at": result.created_at,
            "updated_at": result.updated_at
        }
    
    def list_statements_with_details(
        self,
        user_id: Optional[int] = None,
        cut_period_id: Optional[int] = None,
        status_filter: Optional[str] = None,
        is_overdue: Optional[bool] = None,
        limit: int = 10,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """
        Lista statements con filtros y todos los datos relacionados.
        
        Returns:
            Lista de dicts con todos los campos completos (sin TODOs)
        """
        # Base query
        base_query = """
            SELECT 
                aps.id,
                aps.statement_number,
                CONCAT(u.first_name, ' ', u.last_name) as associate_name,
                cp.cut_code as cut_period_code,
                aps.total_payments_count,
                aps.total_amount_collected,
                aps.total_to_credicuenta,
                aps.commission_earned,
                ss.name as status_name,
                aps.generated_date,
                aps.due_date,
                aps.paid_date,
                aps.paid_amount,
                aps.late_fee_amount,
                aps.late_fee_applied
            FROM associate_payment_statements aps
            JOIN users u ON aps.user_id = u.id
            JOIN cut_periods cp ON aps.cut_period_id = cp.id
            JOIN statement_statuses ss ON aps.status_id = ss.id
        """
        
        # Construir WHERE dinámicamente
        conditions = []
        params = {"limit": limit, "offset": offset}
        
        if user_id is not None:
            conditions.append("aps.user_id = :user_id")
            params["user_id"] = user_id
        
        if cut_period_id is not None:
            conditions.append("aps.cut_period_id = :cut_period_id")
            params["cut_period_id"] = cut_period_id
        
        if status_filter is not None:
            conditions.append("ss.name = :status_name")
            params["status_name"] = status_filter
        
        if is_overdue is not None:
            if is_overdue:
                conditions.append("aps.due_date < CURRENT_DATE AND aps.paid_date IS NULL")
        
        where_clause = " WHERE " + " AND ".join(conditions) if conditions else ""
        
        full_query = text(
            base_query + where_clause + 
            " ORDER BY aps.generated_date DESC LIMIT :limit OFFSET :offset"
        )
        
        results = self.db.execute(full_query, params).fetchall()
        
        return [
            {
                "id": r.id,
                "statement_number": r.statement_number,
                "associate_name": r.associate_name,  # ✅ Ya no es "TODO"
                "cut_period_code": r.cut_period_code,  # ✅ Ya no es "TODO"
                "total_payments_count": r.total_payments_count,
                "total_amount_collected": r.total_amount_collected,
                "total_to_credicuenta": r.total_to_credicuenta,
                "commission_earned": r.commission_earned,
                "status_name": r.status_name,  # ✅ Ya no es "TODO"
                "is_overdue": r.due_date < __import__('datetime').date.today() and r.paid_date is None,
                "remaining_amount": r.total_to_credicuenta - (r.paid_amount or Decimal("0.00")) + r.late_fee_amount,
                "due_date": r.due_date,
                "paid_date": r.paid_date,
                "paid_amount": r.paid_amount or Decimal("0.00"),
                "late_fee_amount": r.late_fee_amount,
                "late_fee_applied": r.late_fee_applied
            }
            for r in results
        ]
