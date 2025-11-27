"""
Módulo de perfiles de tasa.

Este módulo gestiona los perfiles de tasa para préstamos, permitiendo:
- Definir tasas de interés (para clientes) y comisión (para asociados)
- Calcular préstamos con diferentes perfiles
- Comparar múltiples perfiles para ayudar en la decisión

Architecture:
- domain: Entidades del dominio (RateProfile, LoanCalculation)
- application: DTOs y servicios
- infrastructure: (pendiente) Repositorios para acceso a datos
- routes: Endpoints REST API

API Endpoints:
- GET /api/v1/rate-profiles → Listar perfiles
- GET /api/v1/rate-profiles/{code} → Detalle perfil
- POST /api/v1/rate-profiles/calculate → Calcular préstamo
- POST /api/v1/rate-profiles/compare → Comparar perfiles
"""

# Import model to register with SQLAlchemy
from app.modules.rate_profiles.infrastructure.models import RateProfileModel  # noqa: F401

__all__ = ['routes', 'RateProfileModel']
