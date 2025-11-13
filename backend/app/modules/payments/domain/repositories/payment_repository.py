"""
Repository Interface: PaymentRepository
Define el contrato para operaciones de persistencia de Payment.
"""
from abc import ABC, abstractmethod
from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional

from ..entities.payment import Payment


class PaymentRepository(ABC):
    """
    Interface del repositorio de pagos.
    
    Define las operaciones que cualquier implementación concreta debe proveer.
    Sigue el principio de Inversión de Dependencias (Clean Architecture).
    """
    
    @abstractmethod
    async def find_by_id(self, payment_id: int) -> Optional[Payment]:
        """
        Busca un pago por su ID.
        
        Args:
            payment_id: ID del pago
            
        Returns:
            Payment si existe, None si no se encuentra
        """
        pass
    
    @abstractmethod
    async def find_by_loan_id(self, loan_id: int) -> List[Payment]:
        """
        Obtiene todos los pagos de un préstamo.
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            Lista de pagos ordenados por payment_number
        """
        pass
    
    @abstractmethod
    async def find_pending_by_loan_id(self, loan_id: int) -> List[Payment]:
        """
        Obtiene pagos pendientes de un préstamo.
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            Lista de pagos pendientes ordenados por payment_due_date
        """
        pass
    
    @abstractmethod
    async def find_overdue_payments(self, as_of_date: date = None) -> List[Payment]:
        """
        Obtiene todos los pagos vencidos del sistema.
        
        Args:
            as_of_date: Fecha de corte (default: hoy)
            
        Returns:
            Lista de pagos vencidos
        """
        pass
    
    @abstractmethod
    async def register_payment(
        self,
        payment_id: int,
        amount_paid: Decimal,
        payment_date: date,
        marked_by: int,
        notes: Optional[str] = None
    ) -> Payment:
        """
        Registra un pago realizado.
        
        Esta operación:
        1. Actualiza amount_paid, payment_date, status_id
        2. Marca el pago con marked_by y marked_at
        3. Dispara triggers automáticos de crédito
        
        Args:
            payment_id: ID del pago
            amount_paid: Monto pagado
            payment_date: Fecha del pago
            marked_by: Usuario que registra el pago
            notes: Notas opcionales
            
        Returns:
            Payment actualizado
            
        Raises:
            ValueError: Si el pago no existe o no está pendiente
        """
        pass
    
    @abstractmethod
    async def update_status(
        self,
        payment_id: int,
        status_id: int,
        changed_by: int,
        reason: Optional[str] = None
    ) -> Payment:
        """
        Actualiza el estado de un pago manualmente.
        
        Args:
            payment_id: ID del pago
            status_id: Nuevo estado
            changed_by: Usuario que hace el cambio
            reason: Razón del cambio
            
        Returns:
            Payment actualizado
        """
        pass
    
    @abstractmethod
    async def find_by_cut_period(self, cut_period_id: int) -> List[Payment]:
        """
        Obtiene todos los pagos de un periodo de corte.
        
        Args:
            cut_period_id: ID del periodo de corte
            
        Returns:
            Lista de pagos del periodo
        """
        pass
    
    @abstractmethod
    async def get_payment_summary(self, loan_id: int) -> dict:
        """
        Obtiene resumen de pagos de un préstamo.
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            Dict con: total_expected, total_paid, total_pending, payments_count, etc.
        """
        pass
    
    @abstractmethod
    async def mark_payment(
        self,
        payment_id: int,
        amount_paid: Decimal,
        marked_by: int,
        marked_at: datetime,
        notes: Optional[str] = None
    ) -> Payment:
        """
        Marca un pago como cobrado (total o parcial).
        
        Args:
            payment_id: ID del pago
            amount_paid: Monto total pagado (acumulado)
            marked_by: Usuario que registra el pago
            marked_at: Fecha/hora del registro
            notes: Notas adicionales
            
        Returns:
            Payment actualizado
            
        Raises:
            ValueError: Si el pago no existe
        """
        pass
