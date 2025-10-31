"""
Configuración del logger para el módulo de préstamos.

Sistema de logging estructurado con niveles INFO, WARNING, ERROR.
Reemplaza los print() por logs profesionales para monitoreo y debugging.
"""
import logging
import sys
from typing import Optional


def setup_loan_logger(
    name: str = "loans",
    level: int = logging.INFO,
    log_file: Optional[str] = None
) -> logging.Logger:
    """
    Configura y retorna un logger para el módulo de préstamos.
    
    Args:
        name: Nombre del logger
        level: Nivel de logging (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_file: Ruta al archivo de log (opcional)
        
    Returns:
        Logger configurado
    """
    logger = logging.getLogger(name)
    logger.setLevel(level)
    
    # Evitar duplicar handlers
    if logger.handlers:
        return logger
    
    # Formato estructurado
    formatter = logging.Formatter(
        fmt='%(asctime)s | %(name)s | %(levelname)s | %(funcName)s:%(lineno)d | %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Handler para consola
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # Handler para archivo (opcional)
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(level)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    
    return logger


# Logger global para el módulo loans
loan_logger = setup_loan_logger()


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def log_loan_created(loan_id: int, user_id: int, amount: float):
    """Log para préstamo creado."""
    loan_logger.info(
        f"Préstamo creado | ID={loan_id} | Cliente={user_id} | Monto=${amount}"
    )


def log_loan_approved(
    loan_id: int, 
    user_id: int, 
    associate_user_id: int,
    amount: float,
    first_payment_date: str
):
    """Log para préstamo aprobado."""
    loan_logger.info(
        f"Préstamo aprobado | ID={loan_id} | Cliente={user_id} | "
        f"Asociado={associate_user_id} | Monto=${amount} | "
        f"Primera cuota={first_payment_date}"
    )


def log_loan_rejected(
    loan_id: int,
    user_id: int,
    rejected_by: int,
    reason: str
):
    """Log para préstamo rechazado."""
    loan_logger.warning(
        f"Préstamo rechazado | ID={loan_id} | Cliente={user_id} | "
        f"Rechazado por={rejected_by} | Razón={reason[:50]}..."
    )


def log_loan_updated(loan_id: int, user_id: int):
    """Log para préstamo actualizado."""
    loan_logger.info(
        f"Préstamo actualizado | ID={loan_id} | Cliente={user_id}"
    )


def log_loan_cancelled(
    loan_id: int,
    user_id: int,
    associate_user_id: int,
    amount: float,
    reason: str
):
    """Log para préstamo cancelado."""
    loan_logger.warning(
        f"Préstamo cancelado | ID={loan_id} | Cliente={user_id} | "
        f"Asociado={associate_user_id} | Monto=${amount} | "
        f"Razón={reason[:50]}..."
    )


def log_loan_deleted(loan_id: int, user_id: int, status_id: int):
    """Log para préstamo eliminado."""
    loan_logger.info(
        f"Préstamo eliminado | ID={loan_id} | Cliente={user_id} | Estado={status_id}"
    )


def log_validation_error(loan_id: int, error_message: str):
    """Log para errores de validación."""
    loan_logger.error(
        f"Error de validación | ID={loan_id} | Error={error_message}"
    )


def log_database_error(operation: str, error: Exception):
    """Log para errores de base de datos."""
    loan_logger.error(
        f"Error de base de datos | Operación={operation} | Error={str(error)}"
    )


__all__ = [
    'setup_loan_logger',
    'loan_logger',
    'log_loan_created',
    'log_loan_approved',
    'log_loan_rejected',
    'log_loan_updated',
    'log_loan_cancelled',
    'log_loan_deleted',
    'log_validation_error',
    'log_database_error',
]
