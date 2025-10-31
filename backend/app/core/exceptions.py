"""
Custom application exceptions.
"""
from typing import Optional, Any


class AppException(Exception):
    """Base exception for all application errors."""
    
    def __init__(self, message: str, details: Optional[Any] = None):
        self.message = message
        self.details = details
        super().__init__(self.message)


class BusinessException(AppException):
    """Exception for business logic violations."""
    pass


class NotFoundException(AppException):
    """Exception when a resource is not found."""
    
    def __init__(self, resource: str, identifier: Any):
        message = f"{resource} with id {identifier} not found"
        super().__init__(message, details={"resource": resource, "id": identifier})


class UnauthorizedException(AppException):
    """Exception for authentication failures."""
    
    def __init__(self, message: str = "Credenciales inválidas"):
        super().__init__(message)


class ForbiddenException(AppException):
    """Exception for authorization failures."""
    
    def __init__(self, message: str = "No autorizado para esta acción"):
        super().__init__(message)


class DefaulterException(BusinessException):
    """Exception when user is a defaulter."""
    
    def __init__(self, user_id: int):
        message = f"Cliente #{user_id} está en morosidad y no puede solicitar préstamos"
        super().__init__(message, details={"user_id": user_id, "is_defaulter": True})


class InsufficientCreditException(BusinessException):
    """Exception when associate has insufficient credit."""
    
    def __init__(self, available: float, required: float):
        message = f"Crédito insuficiente. Disponible: ${available}, Requerido: ${required}"
        super().__init__(
            message, 
            details={"available": available, "required": required}
        )


# Aliases for auth module
class AuthenticationError(UnauthorizedException):
    """Exception for authentication failures (login, token validation)."""
    pass


class ValidationError(AppException):
    """Exception for validation errors (duplicate username, etc.)."""
    pass


class NotFoundError(NotFoundException):
    """Exception when entity not found."""
    
    def __init__(self, message: str):
        self.message = message
        Exception.__init__(self, message)
