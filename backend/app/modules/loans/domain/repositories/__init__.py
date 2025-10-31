"""
Interfaces de repositorios del dominio de préstamos.

Define los contratos que deben cumplir las implementaciones de infraestructura.
"""
from abc import ABC, abstractmethod
from datetime import date
from decimal import Decimal
from typing import List, Optional

from app.modules.loans.domain.entities import Loan, LoanBalance


class LoanRepository(ABC):
    """
    Interface: Repositorio de préstamos.
    
    Define las operaciones de persistencia para la entidad Loan.
    Las implementaciones concretas están en infrastructure/repositories.
    """
    
    # =============================================================================
    # QUERIES (Lectura)
    # =============================================================================
    
    @abstractmethod
    async def find_by_id(self, loan_id: int) -> Optional[Loan]:
        """
        Busca un préstamo por su ID.
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            Loan si existe, None si no
        """
        pass
    
    @abstractmethod
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
        pass
    
    @abstractmethod
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
        pass
    
    @abstractmethod
    async def get_balance(self, loan_id: int) -> Optional[LoanBalance]:
        """
        Obtiene el balance actual de un préstamo.
        
        Usa la función DB: calculate_loan_remaining_balance()
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            LoanBalance si el préstamo existe, None si no
        """
        pass
    
    # =============================================================================
    # COMMANDS (Escritura) - SPRINT 2
    # =============================================================================
    
    @abstractmethod
    async def create(self, loan: Loan) -> Loan:
        """
        Crea un nuevo préstamo.
        
        Args:
            loan: Entidad Loan (sin ID)
            
        Returns:
            Loan con ID asignado por la BD
        """
        pass
    
    @abstractmethod
    async def update(self, loan: Loan) -> Loan:
        """
        Actualiza un préstamo existente.
        
        Args:
            loan: Entidad Loan con ID
            
        Returns:
            Loan actualizado
        """
        pass
    
    @abstractmethod
    async def delete(self, loan_id: int) -> bool:
        """
        Elimina un préstamo (solo si está en PENDING o REJECTED).
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            True si se eliminó, False si no existía
        """
        pass
    
    # =============================================================================
    # VALIDACIONES Y HELPERS
    # =============================================================================
    
    @abstractmethod
    async def check_associate_credit_available(
        self,
        associate_user_id: int,
        amount: Decimal
    ) -> bool:
        """
        Verifica si el asociado tiene crédito disponible suficiente.
        
        Usa la función DB: check_associate_credit_available()
        
        Args:
            associate_user_id: ID del asociado
            amount: Monto del préstamo solicitado
            
        Returns:
            True si tiene crédito suficiente, False si no
        """
        pass
    
    @abstractmethod
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
            ValueError: Si approval_date es inválido
        """
        pass
    
    @abstractmethod
    async def has_pending_loans(self, user_id: int) -> bool:
        """
        Verifica si el cliente tiene préstamos pendientes de aprobación.
        
        Args:
            user_id: ID del cliente
            
        Returns:
            True si tiene préstamos PENDING, False si no
        """
        pass
    
    @abstractmethod
    async def is_client_defaulter(self, user_id: int) -> bool:
        """
        Verifica si el cliente está marcado como moroso.
        
        Args:
            user_id: ID del cliente
            
        Returns:
            True si es moroso, False si no
        """
        pass


__all__ = ['LoanRepository']
