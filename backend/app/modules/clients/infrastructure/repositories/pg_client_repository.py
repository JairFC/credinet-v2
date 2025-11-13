"""
Repositorio PostgreSQL de Clients.

Reutiliza UserModel del módulo auth ya que los clientes son users.
Filtra por role_id = 5 (cliente)
"""
from typing import List, Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.modules.auth.infrastructure.models import UserModel, user_roles
from app.modules.addresses.infrastructure.models.address_model import AddressModel
from app.modules.guarantors.infrastructure.models.guarantor_model import GuarantorModel
from app.modules.beneficiaries.infrastructure.models.beneficiary_model import BeneficiaryModel
from app.modules.clients.domain.entities.client import Client
from app.modules.clients.domain.repositories.client_repository import ClientRepository


def _map_user_model_to_client(model: UserModel) -> Client:
    """Convierte UserModel a Client entity"""
    return Client(
        id=model.id,
        username=model.username,
        first_name=model.first_name,
        last_name=model.last_name,
        email=model.email,
        phone_number=model.phone_number,
        birth_date=model.birth_date,
        curp=model.curp,
        profile_picture_url=None,  # No existe en UserModel
        active=model.active,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


class PgClientRepository(ClientRepository):
    """Implementación PostgreSQL de ClientRepository"""
    
    CLIENT_ROLE_ID = 5  # ID del rol 'cliente' en tabla roles
    
    def __init__(self, db: AsyncSession):
        self._db = db
    
    async def find_by_id(self, client_id: int) -> Optional[Client]:
        """Busca un cliente por ID (solo si tiene rol cliente)"""
        stmt = (
            select(UserModel)
            .join(user_roles, UserModel.id == user_roles.c.user_id)
            .outerjoin(AddressModel, UserModel.id == AddressModel.user_id)
            .outerjoin(GuarantorModel, UserModel.id == GuarantorModel.user_id)
            .outerjoin(BeneficiaryModel, UserModel.id == BeneficiaryModel.user_id)
            .where(UserModel.id == client_id)
            .where(user_roles.c.role_id == self.CLIENT_ROLE_ID)
        )
        result = await self._db.execute(stmt)
        model = result.unique().scalar_one_or_none()
        
        if not model:
            return None
        
        # Cargar las relaciones manualmente
        address = await self._db.execute(
            select(AddressModel).where(AddressModel.user_id == client_id)
        )
        address_model = address.scalar_one_or_none()
        
        guarantor = await self._db.execute(
            select(GuarantorModel).where(GuarantorModel.user_id == client_id)
        )
        guarantor_model = guarantor.scalar_one_or_none()
        
        beneficiary = await self._db.execute(
            select(BeneficiaryModel).where(BeneficiaryModel.user_id == client_id)
        )
        beneficiary_model = beneficiary.scalar_one_or_none()
        
        # Agregar las relaciones al modelo temporalmente
        model.address = address_model
        model.guarantor = guarantor_model
        model.beneficiary = beneficiary_model
        
        return _map_user_model_to_client(model)
    
    async def find_all(
        self,
        limit: int = 50,
        offset: int = 0,
        active_only: bool = True
    ) -> List[Client]:
        """Lista todos los clientes con paginación (solo users con rol cliente)"""
        stmt = (
            select(UserModel)
            .join(user_roles, UserModel.id == user_roles.c.user_id)
            .where(user_roles.c.role_id == self.CLIENT_ROLE_ID)
        )
        
        if active_only:
            stmt = stmt.where(UserModel.active == True)
        
        stmt = stmt.order_by(UserModel.id).limit(limit).offset(offset)
        
        result = await self._db.execute(stmt)
        models = result.unique().scalars().all()
        
        return [_map_user_model_to_client(m) for m in models]
    
    async def count(self, active_only: bool = True) -> int:
        """Cuenta el total de clientes (solo users con rol cliente)"""
        stmt = (
            select(func.count(UserModel.id))
            .join(user_roles, UserModel.id == user_roles.c.user_id)
            .where(user_roles.c.role_id == self.CLIENT_ROLE_ID)
        )
        
        if active_only:
            stmt = stmt.where(UserModel.active == True)
        
        result = await self._db.execute(stmt)
        return result.scalar() or 0
    
    async def find_by_email(self, email: str) -> Optional[Client]:
        """Busca un cliente por email (solo si tiene rol cliente)"""
        stmt = (
            select(UserModel)
            .join(user_roles, UserModel.id == user_roles.c.user_id)
            .where(UserModel.email == email)
            .where(user_roles.c.role_id == self.CLIENT_ROLE_ID)
        )
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_user_model_to_client(model) if model else None
    
    async def create(self, client: Client, password_hash: str) -> Client:
        """Crea un nuevo cliente"""
        model = UserModel(
            username=client.username,
            password_hash=password_hash,
            first_name=client.first_name,
            last_name=client.last_name,
            email=client.email,
            phone_number=client.phone_number,
            birth_date=client.birth_date,
            curp=client.curp,
            profile_picture_url=client.profile_picture_url,
            active=True,
        )
        
        self._db.add(model)
        await self._db.flush()
        await self._db.refresh(model)
        
        return _map_user_model_to_client(model)
