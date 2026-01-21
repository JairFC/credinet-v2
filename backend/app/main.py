"""
CrediNet Backend v2.0 - Main Application
Clean Architecture implementation with FastAPI
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.responses import JSONResponse
import logging

from app.core.config import settings
from app.core.middleware import setup_middleware

# Configure logging
logging.basicConfig(
    level=logging.INFO if not settings.debug else logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


# Lifespan context manager para manejar startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Maneja eventos de startup y shutdown de la aplicación.
    """
    # === STARTUP ===
    logger.info("🚀 Iniciando CrediNet Backend v2.0...")
    
    # Iniciar el scheduler de tareas programadas
    from app.scheduler import start_scheduler
    start_scheduler()
    
    logger.info("✅ Backend iniciado correctamente")
    
    yield  # La aplicación corre aquí
    
    # === SHUTDOWN ===
    logger.info("🛑 Deteniendo CrediNet Backend...")
    
    # Detener el scheduler
    from app.scheduler import shutdown_scheduler
    shutdown_scheduler()
    
    logger.info("👋 Backend detenido correctamente")


# Create FastAPI app
app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan
)

# Setup middleware
setup_middleware(app)


@app.get("/", tags=["Health"])
def root():
    """
    Root endpoint - Health check.
    
    Returns:
        dict: API information
    """
    return {
        "name": settings.app_name,
        "version": settings.version,
        "status": "running",
        "docs": "/docs"
    }


@app.get("/health", tags=["Health"])
def health_check():
    """
    Health check endpoint for monitoring.
    
    Returns:
        dict: Health status
    """
    return {
        "status": "healthy",
        "version": settings.version
    }


# Register module routers
from app.modules.auth.routes import router as auth_router
from app.modules.catalogs import router as catalogs_router
from app.modules.loans.routes import router as loans_router
from app.modules.rate_profiles.routes import router as rate_profiles_router
from app.modules.payments.routes import router as payments_router
from app.modules.clients.routes import router as clients_router
from app.modules.associates.routes import router as associates_router
from app.modules.cut_periods.routes import router as cut_periods_router
from app.modules.guarantors.routes import router as guarantors_router
from app.modules.beneficiaries.routes import router as beneficiaries_router
from app.modules.addresses.routes import router as addresses_router
from app.modules.audit.routes import router as audit_router
from app.modules.contracts.routes import router as contracts_router
from app.modules.agreements.routes import router as agreements_router
from app.modules.agreements.routes import debt_breakdown_router
from app.modules.agreements.defaulted_reports_routes import router as defaulted_reports_router
from app.modules.documents.routes import router as documents_router
from app.modules.dashboard.routes import router as dashboard_router
from app.modules.statements import router as statements_router
from app.modules.debt_payments.presentation import router as debt_payments_router
from app.modules.shared.routes import router as shared_router
from app.modules.loans.routes_simulator import router as simulator_router
from app.scheduler.routes import router as scheduler_router

app.include_router(auth_router, prefix=settings.api_v1_prefix)
app.include_router(catalogs_router, prefix=settings.api_v1_prefix)
app.include_router(loans_router, prefix=settings.api_v1_prefix)
app.include_router(simulator_router, prefix=settings.api_v1_prefix, tags=["Simulator"])
app.include_router(rate_profiles_router, prefix=f"{settings.api_v1_prefix}/rate-profiles", tags=["Rate Profiles"])
app.include_router(payments_router, prefix=settings.api_v1_prefix)
app.include_router(clients_router, prefix=settings.api_v1_prefix)
app.include_router(associates_router, prefix=settings.api_v1_prefix)
app.include_router(cut_periods_router, prefix=settings.api_v1_prefix)
app.include_router(guarantors_router, prefix=settings.api_v1_prefix)
app.include_router(beneficiaries_router, prefix=settings.api_v1_prefix)
app.include_router(addresses_router, prefix=settings.api_v1_prefix)
app.include_router(audit_router, prefix=settings.api_v1_prefix)
app.include_router(contracts_router, prefix=settings.api_v1_prefix)
app.include_router(agreements_router, prefix=settings.api_v1_prefix)
app.include_router(debt_breakdown_router, prefix=settings.api_v1_prefix)
app.include_router(defaulted_reports_router, prefix=settings.api_v1_prefix)
app.include_router(documents_router, prefix=settings.api_v1_prefix)
app.include_router(dashboard_router, prefix=settings.api_v1_prefix)
app.include_router(scheduler_router, prefix=settings.api_v1_prefix)
app.include_router(statements_router, prefix=settings.api_v1_prefix)
app.include_router(debt_payments_router, prefix=settings.api_v1_prefix)
app.include_router(shared_router, prefix=settings.api_v1_prefix)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug
    )
