"""
Constantes del sistema CrediNet v2

Este archivo centraliza todos los IDs y valores que antes estaban hardcoded
en el código. Esto facilita el mantenimiento y evita errores de tipeo.

IMPORTANTE: Estos valores deben coincidir con los catálogos de la base de datos.
Si se modifican los catálogos, actualizar este archivo.
"""
from enum import IntEnum
from decimal import Decimal


# =============================================================================
# ROLES DE USUARIO
# Tabla: roles
# =============================================================================
class RoleId(IntEnum):
    """IDs de roles del sistema"""
    DESARROLLADOR = 1
    ADMINISTRADOR = 2
    AUXILIAR_ADMINISTRATIVO = 3
    ASOCIADO = 4
    CLIENTE = 5


class RoleName:
    """Nombres de roles (para búsquedas por nombre)"""
    DESARROLLADOR = "desarrollador"
    ADMINISTRADOR = "administrador"
    AUXILIAR_ADMINISTRATIVO = "auxiliar_administrativo"
    ASOCIADO = "asociado"
    CLIENTE = "cliente"


# Roles con privilegios de administración
ADMIN_ROLE_NAMES = frozenset([
    RoleName.DESARROLLADOR,
    RoleName.ADMINISTRADOR,
    "admin",  # Alias legacy
])

# Roles que pueden operar en el sistema (no clientes)
OPERATOR_ROLE_NAMES = frozenset([
    RoleName.DESARROLLADOR,
    RoleName.ADMINISTRADOR,
    RoleName.AUXILIAR_ADMINISTRATIVO,
    RoleName.ASOCIADO,
])


# =============================================================================
# ESTADOS DE PRÉSTAMO
# Tabla: loan_statuses
# =============================================================================
class LoanStatusId(IntEnum):
    """IDs de estados de préstamo"""
    PENDING = 1      # Solicitud pendiente de aprobación
    ACTIVE = 2       # Préstamo activo con pagos en curso
    COMPLETED = 4    # Préstamo completado
    PAID = 5         # Sinónimo de COMPLETED
    DEFAULTED = 6    # En mora
    REJECTED = 7     # Rechazado
    CANCELLED = 8    # Cancelado
    IN_AGREEMENT = 9 # En convenio de pago


# Estados que indican préstamo liquidado
LOAN_TERMINAL_STATUSES = frozenset([
    LoanStatusId.COMPLETED,
    LoanStatusId.PAID,
    LoanStatusId.CANCELLED,
    LoanStatusId.REJECTED,
])


# =============================================================================
# ESTADOS DE PAGO
# Tabla: payment_statuses
# =============================================================================
class PaymentStatusId(IntEnum):
    """IDs de estados de pago"""
    PENDING = 1         # Pago pendiente
    DUE_TODAY = 2       # Vence hoy
    PAID = 3            # Pagado
    OVERDUE = 4         # Vencido
    PARTIAL = 5         # Pago parcial
    IN_COLLECTION = 6   # En cobranza
    RESCHEDULED = 7     # Reprogramado
    PAID_PARTIAL = 8    # Parcial aceptado
    PAID_BY_ASSOCIATE = 9   # Pagado por asociado
    PAID_NOT_REPORTED = 10  # No reportado
    FORGIVEN = 11       # Perdonado
    CANCELLED = 12      # Cancelado
    IN_AGREEMENT = 13   # En convenio


# Estados que indican pago efectivo
PAID_STATUSES = frozenset([
    PaymentStatusId.PAID,
    PaymentStatusId.PAID_PARTIAL,
    PaymentStatusId.PAID_BY_ASSOCIATE,
])


# =============================================================================
# ESTADOS DE PERÍODO DE CORTE
# Tabla: cut_period_statuses
# =============================================================================
class CutPeriodStatusId(IntEnum):
    """IDs de estados de período de corte"""
    PENDING = 1     # Período futuro
    ACTIVE = 2      # DEPRECADO - No usar
    CUTOFF = 3      # Borrador (corte automático ejecutado)
    COLLECTING = 4  # En cobro (cierre manual ejecutado)
    CLOSED = 5      # Cerrado definitivamente
    SETTLING = 6    # En liquidación


# Flujo de transiciones válidas
CUT_PERIOD_TRANSITIONS = {
    CutPeriodStatusId.PENDING: [CutPeriodStatusId.CUTOFF],
    CutPeriodStatusId.CUTOFF: [CutPeriodStatusId.COLLECTING],
    CutPeriodStatusId.COLLECTING: [CutPeriodStatusId.SETTLING],
    CutPeriodStatusId.SETTLING: [CutPeriodStatusId.CLOSED],
    CutPeriodStatusId.CLOSED: [],  # Estado terminal
}


# =============================================================================
# ESTADOS DE STATEMENT
# Tabla: statement_statuses
# =============================================================================
class StatementStatusId(IntEnum):
    """IDs de estados de statement"""
    DRAFT = 6       # Borrador
    COLLECTING = 7  # En cobro
    SETTLING = 9    # En liquidación
    CLOSED = 10     # Cerrado
    PAID = 3        # Pagado (legacy)
    PARTIAL = 4     # Pago parcial (legacy)
    OVERDUE = 5     # Vencido (legacy)
    ABSORBED = 8    # Deuda transferida (legacy)


# =============================================================================
# ESTADOS DE DOCUMENTO
# Tabla: document_statuses
# =============================================================================
class DocumentStatusId(IntEnum):
    """IDs de estados de documento"""
    PENDING = 1     # Pendiente de revisión
    UPLOADED = 2    # Subido
    VERIFIED = 3    # Verificado/Aprobado
    REJECTED = 4    # Rechazado


# =============================================================================
# MÉTODOS DE PAGO
# Tabla: payment_methods
# =============================================================================
class PaymentMethodId(IntEnum):
    """IDs de métodos de pago"""
    CASH = 1            # Efectivo
    TRANSFER = 2        # Transferencia
    CHECK = 3           # Cheque
    PAYROLL = 4         # Descuento de nómina
    CARD = 5            # Tarjeta
    DEPOSIT = 6         # Depósito bancario
    OXXO = 7            # Pago en OXXO


# =============================================================================
# CONFIGURACIÓN DE PERÍODOS DE CORTE
# =============================================================================
class CutPeriodConfig:
    """Configuración de períodos de corte"""
    # Días del mes para corte (8 y 23)
    CUT_DAYS = (8, 23)
    
    # Hora del corte automático (00:05)
    CUT_HOUR = 0
    CUT_MINUTE = 5
    
    # Gracia para tareas programadas (segundos)
    MISFIRE_GRACE_TIME = 3600  # 1 hora


# =============================================================================
# CONFIGURACIÓN DE PRÉSTAMOS
# =============================================================================
class LoanConfig:
    """Configuración de préstamos"""
    # Rango de plazo permitido (en quincenas)
    MIN_TERM_BIWEEKS = 1
    MAX_TERM_BIWEEKS = 52  # 2 años
    
    # Tolerancia para comparaciones de saldo
    BALANCE_TOLERANCE = Decimal("0.01")


# =============================================================================
# CONFIGURACIÓN DE DEUDA
# =============================================================================
class DebtConfig:
    """Configuración de cálculos de deuda"""
    # Tolerancia para considerar deuda pendiente
    DEBT_TOLERANCE = Decimal("0.01")
    
    # Porcentaje mínimo de pago para considerar "pagado"
    MIN_PAYMENT_PERCENTAGE = Decimal("0.99")  # 99%
