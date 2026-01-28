"""
Enhanced Service para Loans.

Provee queries con JOINs para obtener datos completos sin TODOs.
Patrón usado en: statements, debt_payments.
"""
from typing import Optional, Dict, Any
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


class LoanEnhancedService:
    """
    Servicio mejorado para obtener préstamos con datos relacionados.
    
    Usa SQL directo con JOINs para evitar N+1 queries y construcción manual de DTOs.
    """
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_loan_with_details(self, loan_id: int) -> Optional[Dict[str, Any]]:
        """
        Obtiene un préstamo con todos los datos relacionados.
        
        Returns:
            Dict con todos los campos incluyendo:
            - client_name (en lugar de user_id solo)
            - associate_name (en lugar de associate_user_id solo)
            - status_name (en lugar de status_id solo)
            - approver_name, rejecter_name
        """
        result = await self.db.execute(text("""
            SELECT 
                l.id,
                l.user_id,
                CONCAT(u_client.first_name, ' ', u_client.last_name) AS client_name,
                l.associate_user_id,
                CONCAT(u_assoc.first_name, ' ', u_assoc.last_name) AS associate_name,
                l.amount,
                l.interest_rate,
                l.commission_rate,
                l.term_biweeks,
                l.profile_code,
                l.status_id,
                ls.name AS status_name,
                l.contract_id,
                l.approved_at,
                l.approved_by,
                CONCAT(u_approver.first_name, ' ', u_approver.last_name) AS approver_name,
                l.rejected_at,
                l.rejected_by,
                CONCAT(u_rejecter.first_name, ' ', u_rejecter.last_name) AS rejecter_name,
                l.rejection_reason,
                l.notes,
                l.created_at,
                l.updated_at,
                -- Campos calculados guardados en BD (si existen), sino calcular manualmente
                COALESCE(l.total_payment, l.amount * (1 + (l.interest_rate / 100))) AS total_to_pay,
                COALESCE(l.biweekly_payment, (l.amount * (1 + (l.interest_rate / 100))) / l.term_biweeks) AS payment_amount,
                -- ⭐ Agregar columnas reales para el DTO completo
                l.biweekly_payment,
                l.total_payment,
                l.total_interest,
                l.total_commission,
                l.commission_per_payment,
                l.associate_payment,
                -- ⭐ Campo para validar si puede eliminarse (tiene pagos en statements)
                EXISTS (
                    SELECT 1 FROM payments p 
                    WHERE p.loan_id = l.id 
                    AND p.cut_period_id IS NOT NULL
                ) AS has_statement_payments
            FROM loans l
            JOIN users u_client ON u_client.id = l.user_id
            JOIN loan_statuses ls ON ls.id = l.status_id
            LEFT JOIN users u_assoc ON u_assoc.id = l.associate_user_id
            LEFT JOIN users u_approver ON u_approver.id = l.approved_by
            LEFT JOIN users u_rejecter ON u_rejecter.id = l.rejected_by
            WHERE l.id = :loan_id
        """), {"loan_id": loan_id})
        
        row = result.fetchone()
        
        if not row:
            return None
        
        return {
            "id": row[0],
            "user_id": row[1],
            "client_name": row[2],
            "associate_user_id": row[3],
            "associate_name": row[4],
            "amount": float(row[5]),
            "interest_rate": float(row[6]),
            "commission_rate": float(row[7]),
            "term_biweeks": row[8],
            "profile_code": row[9],
            "status_id": row[10],
            "status_name": row[11],
            "contract_id": row[12],
            "approved_at": row[13],
            "approved_by": row[14],
            "approver_name": row[15],
            "rejected_at": row[16],
            "rejected_by": row[17],
            "rejecter_name": row[18],
            "rejection_reason": row[19],
            "notes": row[20],
            "created_at": row[21],
            "updated_at": row[22],
            "total_to_pay": float(row[23]) if row[23] else 0.0,
            "payment_amount": float(row[24]) if row[24] else 0.0,
            "biweekly_payment": float(row[25]) if row[25] else None,
            "total_payment": float(row[26]) if row[26] else None,
            "total_interest": float(row[27]) if row[27] else 0.0,
            "total_commission": float(row[28]) if row[28] else 0.0,
            "commission_per_payment": float(row[29]) if row[29] else 0.0,
            "associate_payment": float(row[30]) if row[30] else 0.0,
            "has_statement_payments": bool(row[31]),  # True si tiene pagos en statements
        }
