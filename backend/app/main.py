"""
CrediNet Backend v2.0 - Main Application
Clean Architecture implementation with FastAPI
"""
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

# Create FastAPI app
app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json"
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

app.include_router(auth_router, prefix=settings.api_v1_prefix)
app.include_router(catalogs_router, prefix=settings.api_v1_prefix)
app.include_router(loans_router, prefix=settings.api_v1_prefix)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug
    )
