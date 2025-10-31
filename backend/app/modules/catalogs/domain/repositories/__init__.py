"""
Interfaces de repositorios para catálogos.

Define los contratos que deben implementar los repositorios de infraestructura.
Siguiendo el Principio de Inversión de Dependencias (DIP).
"""

from abc import ABC, abstractmethod
from typing import List, Optional

from app.modules.catalogs.domain.entities import (
    AssociateLevel,
    ConfigType,
    ContractStatus,
    CutPeriodStatus,
    DocumentStatus,
    DocumentType,
    LevelChangeType,
    LoanStatus,
    PaymentMethod,
    PaymentStatus,
    Role,
    StatementStatus,
)


class RoleRepository(ABC):
    """Repositorio para roles."""

    @abstractmethod
    async def find_all(self) -> List[Role]:
        """Obtener todos los roles."""
        pass

    @abstractmethod
    async def find_by_id(self, role_id: int) -> Optional[Role]:
        """Buscar rol por ID."""
        pass

    @abstractmethod
    async def find_by_name(self, name: str) -> Optional[Role]:
        """Buscar rol por nombre."""
        pass


class LoanStatusRepository(ABC):
    """Repositorio para estados de préstamo."""

    @abstractmethod
    async def find_all(self, active_only: bool = False) -> List[LoanStatus]:
        """Obtener todos los estados de préstamo."""
        pass

    @abstractmethod
    async def find_by_id(self, status_id: int) -> Optional[LoanStatus]:
        """Buscar estado por ID."""
        pass

    @abstractmethod
    async def find_by_name(self, name: str) -> Optional[LoanStatus]:
        """Buscar estado por nombre."""
        pass


class PaymentStatusRepository(ABC):
    """Repositorio para estados de pago."""

    @abstractmethod
    async def find_all(
        self, active_only: bool = False, real_payments_only: bool = False
    ) -> List[PaymentStatus]:
        """Obtener todos los estados de pago."""
        pass

    @abstractmethod
    async def find_by_id(self, status_id: int) -> Optional[PaymentStatus]:
        """Buscar estado por ID."""
        pass

    @abstractmethod
    async def find_by_name(self, name: str) -> Optional[PaymentStatus]:
        """Buscar estado por nombre."""
        pass


class ContractStatusRepository(ABC):
    """Repositorio para estados de contrato."""

    @abstractmethod
    async def find_all(self, active_only: bool = False) -> List[ContractStatus]:
        """Obtener todos los estados de contrato."""
        pass

    @abstractmethod
    async def find_by_id(self, status_id: int) -> Optional[ContractStatus]:
        """Buscar estado por ID."""
        pass


class CutPeriodStatusRepository(ABC):
    """Repositorio para estados de período de corte."""

    @abstractmethod
    async def find_all(self) -> List[CutPeriodStatus]:
        """Obtener todos los estados de período de corte."""
        pass

    @abstractmethod
    async def find_by_id(self, status_id: int) -> Optional[CutPeriodStatus]:
        """Buscar estado por ID."""
        pass


class PaymentMethodRepository(ABC):
    """Repositorio para métodos de pago."""

    @abstractmethod
    async def find_all(self, active_only: bool = False) -> List[PaymentMethod]:
        """Obtener todos los métodos de pago."""
        pass

    @abstractmethod
    async def find_by_id(self, method_id: int) -> Optional[PaymentMethod]:
        """Buscar método por ID."""
        pass


class DocumentStatusRepository(ABC):
    """Repositorio para estados de documento."""

    @abstractmethod
    async def find_all(self) -> List[DocumentStatus]:
        """Obtener todos los estados de documento."""
        pass

    @abstractmethod
    async def find_by_id(self, status_id: int) -> Optional[DocumentStatus]:
        """Buscar estado por ID."""
        pass


class StatementStatusRepository(ABC):
    """Repositorio para estados de cuenta de asociado."""

    @abstractmethod
    async def find_all(self) -> List[StatementStatus]:
        """Obtener todos los estados de cuenta."""
        pass

    @abstractmethod
    async def find_by_id(self, status_id: int) -> Optional[StatementStatus]:
        """Buscar estado por ID."""
        pass


class ConfigTypeRepository(ABC):
    """Repositorio para tipos de configuración."""

    @abstractmethod
    async def find_all(self) -> List[ConfigType]:
        """Obtener todos los tipos de configuración."""
        pass

    @abstractmethod
    async def find_by_id(self, type_id: int) -> Optional[ConfigType]:
        """Buscar tipo por ID."""
        pass


class LevelChangeTypeRepository(ABC):
    """Repositorio para tipos de cambio de nivel."""

    @abstractmethod
    async def find_all(self) -> List[LevelChangeType]:
        """Obtener todos los tipos de cambio de nivel."""
        pass

    @abstractmethod
    async def find_by_id(self, type_id: int) -> Optional[LevelChangeType]:
        """Buscar tipo por ID."""
        pass


class AssociateLevelRepository(ABC):
    """Repositorio para niveles de asociado."""

    @abstractmethod
    async def find_all(self) -> List[AssociateLevel]:
        """Obtener todos los niveles de asociado."""
        pass

    @abstractmethod
    async def find_by_id(self, level_id: int) -> Optional[AssociateLevel]:
        """Buscar nivel por ID."""
        pass

    @abstractmethod
    async def find_by_name(self, name: str) -> Optional[AssociateLevel]:
        """Buscar nivel por nombre."""
        pass


class DocumentTypeRepository(ABC):
    """Repositorio para tipos de documento."""

    @abstractmethod
    async def find_all(self, required_only: bool = False) -> List[DocumentType]:
        """Obtener todos los tipos de documento."""
        pass

    @abstractmethod
    async def find_by_id(self, type_id: int) -> Optional[DocumentType]:
        """Buscar tipo por ID."""
        pass
