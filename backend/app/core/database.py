"""
Database connection and session management using SQLAlchemy.
"""
from sqlalchemy import create_engine, text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator, AsyncGenerator, Optional
from contextvars import ContextVar

from .config import settings

# ============================================================================= 
# CONTEXT VAR para almacenar el usuario actual (thread-safe)
# =============================================================================
current_user_id_var: ContextVar[Optional[int]] = ContextVar('current_user_id', default=None)


def set_current_user(user_id: int) -> None:
    """Establecer el usuario actual para auditoría."""
    current_user_id_var.set(user_id)


def get_current_user() -> Optional[int]:
    """Obtener el usuario actual."""
    return current_user_id_var.get()


# ============================================================================= # SYNC DATABASE (Para operaciones síncronas legacy)
# =============================================================================
engine = create_engine(
    settings.database_url,
    echo=settings.db_echo,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# =============================================================================
# ASYNC DATABASE (Para módulos nuevos con Clean Architecture)
# =============================================================================
# Convertir DATABASE_URL a formato async (postgresql:// → postgresql+asyncpg://)
async_database_url = settings.database_url.replace(
    "postgresql://",
    "postgresql+asyncpg://"
)

async_engine = create_async_engine(
    async_database_url,
    echo=settings.db_echo,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10
)

AsyncSessionLocal = async_sessionmaker(
    async_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

# Base class for SQLAlchemy models
Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """
    Dependency injection for SYNC database session.
    
    Usage in FastAPI routes:
        @router.get("/")
        def get_items(db: Session = Depends(get_db)):
            ...
    
    Yields:
        Session: SQLAlchemy database session
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


async def get_async_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency injection for ASYNC database session.
    
    Usage in FastAPI routes:
        @router.get("/")
        async def get_items(db: AsyncSession = Depends(get_async_db)):
            ...
    
    Yields:
        AsyncSession: SQLAlchemy async database session
    """
    async with AsyncSessionLocal() as session:
        try:
            # Setear el usuario actual en la variable de sesión de PostgreSQL
            user_id = current_user_id_var.get()
            if user_id:
                await session.execute(
                    text(f"SET LOCAL app.current_user_id = '{user_id}'")
                )
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
