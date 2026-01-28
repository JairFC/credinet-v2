"""
CrediNet Health Check Suite
============================

Suite de pruebas NO DESTRUCTIVAS para verificar el estado del sistema.
Inspirado en el boot check de Linux, muestra [  OK  ] o [FAILED] para cada verificación.

USO:
    pytest tests/health/ -v --tb=short
    
    O para ver salida tipo boot:
    ./scripts/check-health.sh

CATEGORÍAS:
    - infrastructure: Host, Docker, red, DNS
    - database: Conexión, tablas, integridad
    - backend: API, endpoints, autenticación
    - business: Lógica de negocio, consistencia de datos
    
IMPORTANTE:
    - Todas las pruebas son de SOLO LECTURA
    - No modifican datos de producción
    - Usan SELECT, no INSERT/UPDATE/DELETE
    - Para tests que escriben, usar tests/integration/ con rollback
"""

import pytest

# No importamos módulos aquí para evitar dependencias circulares
# Cada test file importa lo que necesita
