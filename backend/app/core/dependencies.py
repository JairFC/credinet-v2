"""
Global dependency injection for FastAPI routes.
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from typing import Optional, List

from .database import get_db
from .security import decode_access_token
from .exceptions import UnauthorizedException

# HTTP Bearer token scheme
security = HTTPBearer()


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> int:
    """
    Extract and validate user ID from JWT token.
    
    Usage in routes:
        @router.get("/protected")
        def protected_route(user_id: int = Depends(get_current_user_id)):
            ...
    
    Args:
        credentials: HTTP Authorization header with Bearer token
    
    Returns:
        int: User ID from token
    
    Raises:
        HTTPException: If token is invalid or missing
    """
    token = credentials.credentials
    payload = decode_access_token(token)
    
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # user_id está en campo separado (sub contiene username)
    user_id: Optional[int] = payload.get("user_id")
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido: user_id no encontrado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return int(user_id)


def get_current_user_roles(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> List[str]:
    """
    Extract user roles from JWT token.
    
    Usage in routes:
        @router.get("/protected")
        def protected_route(roles: List[str] = Depends(get_current_user_roles)):
            ...
    
    Args:
        credentials: HTTP Authorization header with Bearer token
    
    Returns:
        List[str]: User roles from token
    
    Raises:
        HTTPException: If token is invalid or missing
    """
    token = credentials.credentials
    payload = decode_access_token(token)
    
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    roles: Optional[List[str]] = payload.get("roles")
    if roles is None:
        return []
    
    return roles


def require_admin(
    roles: List[str] = Depends(get_current_user_roles)
) -> None:
    """
    Require user to have admin role.
    
    Usage in routes:
        @router.post("/admin-only", dependencies=[Depends(require_admin)])
        def admin_only_route():
            ...
    
    Args:
        roles: User roles from token
    
    Raises:
        HTTPException: If user is not admin
    """
    if "admin" not in roles and "desarrollador" not in roles and "administrador" not in roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Requiere permisos de administrador",
        )


def require_associate_or_admin(
    roles: List[str] = Depends(get_current_user_roles)
) -> None:
    """
    Require user to have associate or admin role.
    
    Usage in routes:
        @router.post("/associate-action", dependencies=[Depends(require_associate_or_admin)])
        def associate_action():
            ...
    
    Args:
        roles: User roles from token
    
    Raises:
        HTTPException: If user is not associate or admin
    """
    allowed_roles = ["asociado", "admin", "desarrollador", "administrador"]
    if not any(role in roles for role in allowed_roles):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Requiere permisos de asociado o administrador",
        )


def require_role(required_role: str):
    """
    Factory function to create role requirement dependency.
    
    Usage in routes:
        @router.post("/treasurer-only", dependencies=[Depends(require_role("tesorero"))])
        def treasurer_only_route():
            ...
    
    Args:
        required_role: Role name required to access endpoint
    
    Returns:
        Callable dependency that validates role
    """
    def _require_role(roles: List[str] = Depends(get_current_user_roles)) -> None:
        if required_role not in roles and "admin" not in roles and "desarrollador" not in roles and "administrador" not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requiere rol: {required_role}",
            )
    return _require_role
