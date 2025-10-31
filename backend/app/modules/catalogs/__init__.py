"""
Módulo de catálogos.

Proporciona acceso read-only a los 12 catálogos del sistema:
1. roles
2. loan_statuses
3. payment_statuses
4. contract_statuses
5. cut_period_statuses
6. payment_methods
7. document_statuses
8. statement_statuses
9. config_types
10. level_change_types
11. associate_levels
12. document_types
"""

from app.modules.catalogs.routes import router

__all__ = ["router"]
