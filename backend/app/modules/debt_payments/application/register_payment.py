"""
Use Case: Register Debt Payment

Registra un pago de deuda que se aplica automáticamente usando lógica FIFO.
"""
from ..domain.entities import DebtPayment
from ..infrastructure.pg_repository import PgDebtPaymentRepository
from .dtos import RegisterDebtPaymentDTO


class RegisterDebtPaymentUseCase:
    """
    Caso de uso para registrar un pago de deuda.
    
    La lógica FIFO se ejecuta automáticamente mediante el trigger de BD:
    - Liquida primero los items de deuda más antiguos
    - Actualiza debt_balance del asociado
    - Registra el detalle en applied_breakdown_items
    """
    
    def __init__(self, repository: PgDebtPaymentRepository):
        self.repository = repository
    
    def execute(self, dto: RegisterDebtPaymentDTO, registered_by: int) -> DebtPayment:
        """
        Registra un nuevo pago de deuda.
        
        Args:
            dto: Datos del pago a registrar
            registered_by: ID del usuario que registra el pago
        
        Returns:
            DebtPayment: Entidad con el pago registrado y detalle de items liquidados
        
        Raises:
            ValueError: Si el asociado no existe o no tiene deuda pendiente
        """
        # Verificar que el asociado tenga deuda pendiente
        debt_summary = self.repository.get_associate_debt_summary(dto.associate_profile_id)
        
        if not debt_summary:
            raise ValueError(f"Associate profile {dto.associate_profile_id} not found")
        
        if debt_summary["current_debt_balance"] <= 0:
            raise ValueError(
                f"Associate {debt_summary['associate_name']} has no pending debt. "
                f"Current debt balance: {debt_summary['current_debt_balance']}"
            )
        
        # Advertencia si el pago excede la deuda
        if dto.payment_amount > debt_summary["current_debt_balance"]:
            # Permitir el pago pero loggear advertencia
            # El trigger solo aplicará hasta la deuda total
            pass
        
        # Crear el pago (el trigger FIFO se ejecuta automáticamente)
        payment = self.repository.create(
            associate_profile_id=dto.associate_profile_id,
            payment_amount=float(dto.payment_amount),
            payment_date=dto.payment_date,
            payment_method_id=dto.payment_method_id,
            payment_reference=dto.payment_reference,
            registered_by=registered_by,
            notes=dto.notes
        )
        
        return payment
