"""
Enhanced Service para Debt Payments.

Provee queries con JOINs para obtener datos completos sin TODOs.
"""
from typing import Optional, List, Dict, Any
from sqlalchemy import text
from sqlalchemy.orm import Session


class DebtPaymentEnhancedService:
    """
    Servicio mejorado para obtener pagos de deuda con datos relacionados.
    
    Usa SQL directo con JOINs para evitar N+1 queries y construcción manual de DTOs.
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_payment_with_details(self, payment_id: int) -> Optional[Dict[str, Any]]:
        """
        Obtiene un pago de deuda con todos los datos relacionados.
        
        Returns:
            Dict con todos los campos incluyendo:
            - associate_name (en lugar de ID)
            - payment_method_name (en lugar de ID)
            - registered_by_name (en lugar de ID)
            - applied_breakdown_items (JSONB)
        """
        result = self.db.execute(text("""
            SELECT 
                adp.id,
                adp.associate_profile_id,
                CONCAT(u_assoc.first_name, ' ', u_assoc.last_name) AS associate_name,
                adp.payment_amount,
                adp.payment_date,
                adp.payment_method_id,
                pm.name AS payment_method_name,
                adp.payment_reference,
                adp.registered_by,
                CONCAT(u_reg.first_name, ' ', u_reg.last_name) AS registered_by_name,
                adp.applied_breakdown_items,
                adp.notes,
                adp.created_at,
                adp.updated_at
            FROM associate_debt_payments adp
            JOIN associate_profiles ap ON ap.id = adp.associate_profile_id
            JOIN users u_assoc ON u_assoc.id = ap.user_id
            JOIN payment_methods pm ON pm.id = adp.payment_method_id
            JOIN users u_reg ON u_reg.id = adp.registered_by
            WHERE adp.id = :payment_id
        """), {"payment_id": payment_id}).fetchone()
        
        if not result:
            return None
        
        # Calcular estadísticas de items aplicados
        applied_items = result[10] if result[10] else []
        total_liquidated = sum(1 for item in applied_items if item.get('liquidated', False))
        total_partial = sum(1 for item in applied_items if not item.get('liquidated', False))
        
        return {
            "id": result[0],
            "associate_profile_id": result[1],
            "associate_name": result[2],
            "payment_amount": float(result[3]),
            "payment_date": result[4],
            "payment_method_id": result[5],
            "payment_method_name": result[6],
            "payment_reference": result[7],
            "registered_by": result[8],
            "registered_by_name": result[9],
            "applied_breakdown_items": applied_items,
            "total_items_liquidated": total_liquidated,
            "total_items_partial": total_partial,
            "notes": result[11],
            "created_at": result[12]
        }
    
    def list_payments_with_details(
        self,
        associate_profile_id: Optional[int] = None,
        limit: int = 50,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """
        Lista pagos de deuda con filtros y datos completos.
        
        Args:
            associate_profile_id: Filtrar por asociado (opcional)
            limit: Límite de resultados
            offset: Offset para paginación
        
        Returns:
            Lista de dicts con todos los campos completos
        """
        where_clause = ""
        params = {"limit": limit, "offset": offset}
        
        if associate_profile_id:
            where_clause = "WHERE adp.associate_profile_id = :associate_id"
            params["associate_id"] = associate_profile_id
        
        query = f"""
            SELECT 
                adp.id,
                adp.associate_profile_id,
                CONCAT(u_assoc.first_name, ' ', u_assoc.last_name) AS associate_name,
                adp.payment_amount,
                adp.payment_date,
                adp.payment_method_id,
                pm.name AS payment_method_name,
                adp.payment_reference,
                adp.registered_by,
                CONCAT(u_reg.first_name, ' ', u_reg.last_name) AS registered_by_name,
                adp.applied_breakdown_items,
                adp.notes,
                adp.created_at
            FROM associate_debt_payments adp
            JOIN associate_profiles ap ON ap.id = adp.associate_profile_id
            JOIN users u_assoc ON u_assoc.id = ap.user_id
            JOIN payment_methods pm ON pm.id = adp.payment_method_id
            JOIN users u_reg ON u_reg.id = adp.registered_by
            {where_clause}
            ORDER BY adp.payment_date DESC, adp.id DESC
            LIMIT :limit OFFSET :offset
        """
        
        results = self.db.execute(text(query), params).fetchall()
        
        payments = []
        for r in results:
            applied_items = r[10] if r[10] else []
            payments.append({
                "id": r[0],
                "associate_profile_id": r[1],
                "associate_name": r[2],
                "payment_amount": float(r[3]),
                "payment_date": r[4],
                "payment_method_id": r[5],
                "payment_method_name": r[6],
                "payment_reference": r[7],
                "registered_by": r[8],
                "registered_by_name": r[9],
                "applied_breakdown_items": applied_items,
                "items_liquidated": sum(1 for item in applied_items if item.get('liquidated', False)),
                "notes": r[11],
                "created_at": r[12]
            })
        
        return payments
