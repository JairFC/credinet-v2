#!/usr/bin/env python3
"""
CrediNet System Health Check
=============================

Script para ejecutar todos los health checks con salida visual tipo boot de Linux.

USO:
    python run_all_checks.py           # Ejecutar todos los checks
    python run_all_checks.py -v        # Verbose: mostrar detalles de fallos
    python run_all_checks.py -c infra  # Solo checks de infraestructura
    
CATEGORÍAS:
    infra     - Infraestructura (Docker, red, disco)
    database  - Base de datos (conexión, tablas, integridad)
    backend   - Backend API (endpoints, auth)
    business  - Lógica de negocio (reglas, consistencia)
    all       - Todas las categorías
"""

import subprocess
import sys
import os
from datetime import datetime
from typing import List, Tuple, Dict

# Colores ANSI
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
BOLD = "\033[1m"
RESET = "\033[0m"


def print_header():
    """Imprimir encabezado del sistema."""
    print(f"""
{BOLD}╔═══════════════════════════════════════════════════════════════╗
║           CrediNet v2.0 - System Health Check                 ║
║                    {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}                      ║
╚═══════════════════════════════════════════════════════════════╝{RESET}
""")


def print_status(name: str, status: str, details: str = ""):
    """Imprimir línea de estado tipo boot."""
    # Padding para alinear
    name_padded = name.ljust(50, '.')
    
    if status == "OK":
        status_str = f"[  {GREEN}OK{RESET}  ]"
    elif status == "FAIL":
        status_str = f"[{RED}FAILED{RESET}]"
    elif status == "SKIP":
        status_str = f"[ {YELLOW}SKIP{RESET} ]"
    elif status == "WARN":
        status_str = f"[ {YELLOW}WARN{RESET} ]"
    else:
        status_str = f"[{status:^6}]"
    
    print(f"  {name_padded} {status_str}")
    if details:
        print(f"      {YELLOW}→ {details}{RESET}")


def run_pytest_check(test_path: str) -> List[Dict]:
    """
    Ejecutar pytest y parsear resultados.
    Retorna lista de {name, status, details}.
    """
    results = []
    
    try:
        # Ejecutar pytest con formato específico
        cmd = [
            "python", "-m", "pytest",
            test_path,
            "-v",
            "--tb=line",
            "--no-header",
            "-q"
        ]
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        )
        
        # Parsear salida
        for line in result.stdout.split('\n'):
            line = line.strip()
            if '::' in line:
                # Línea de test: test_file.py::TestClass::test_name PASSED/FAILED
                parts = line.split(' ')
                if len(parts) >= 2:
                    test_full_name = parts[0]
                    test_status = parts[-1].upper() if parts[-1] else 'UNKNOWN'
                    
                    # Extraer nombre legible
                    if '::' in test_full_name:
                        test_parts = test_full_name.split('::')
                        if len(test_parts) >= 3:
                            test_name = test_parts[-1].replace('test_', '').replace('_', ' ').title()
                        else:
                            test_name = test_parts[-1]
                    else:
                        test_name = test_full_name
                    
                    # Mapear estados
                    if 'PASSED' in test_status:
                        status = 'OK'
                    elif 'FAILED' in test_status:
                        status = 'FAIL'
                    elif 'SKIPPED' in test_status:
                        status = 'SKIP'
                    elif 'ERROR' in test_status:
                        status = 'FAIL'
                    else:
                        status = test_status[:6]
                    
                    results.append({
                        'name': test_name[:47],  # Truncar si es muy largo
                        'status': status,
                        'details': ''
                    })
        
        return results
        
    except subprocess.TimeoutExpired:
        return [{'name': 'Test Suite', 'status': 'FAIL', 'details': 'Timeout'}]
    except Exception as e:
        return [{'name': 'Test Suite', 'status': 'FAIL', 'details': str(e)}]


def run_quick_checks() -> List[Tuple[str, str, str]]:
    """
    Ejecutar checks rápidos directamente (sin pytest).
    Para feedback inmediato antes de los tests completos.
    """
    checks = []
    
    # 1. Docker daemon
    try:
        result = subprocess.run(
            ["docker", "info"],
            capture_output=True,
            timeout=10
        )
        checks.append(("Docker daemon", "OK" if result.returncode == 0 else "FAIL", ""))
    except:
        checks.append(("Docker daemon", "FAIL", "Cannot connect"))
    
    # 2. Contenedores
    for container in ["credinet-backend", "credinet-frontend", "credinet-postgres"]:
        try:
            result = subprocess.run(
                ["docker", "inspect", "-f", "{{.State.Running}}", container],
                capture_output=True,
                text=True,
                timeout=5
            )
            status = "OK" if result.stdout.strip() == "true" else "FAIL"
            checks.append((f"Container {container}", status, ""))
        except:
            checks.append((f"Container {container}", "FAIL", "Not found"))
    
    # 3. PostgreSQL responde
    try:
        result = subprocess.run(
            ["docker", "exec", "credinet-postgres", 
             "psql", "-U", "credinet_user", "-d", "credinet_db", 
             "-c", "SELECT 1"],
            capture_output=True,
            timeout=10
        )
        checks.append(("PostgreSQL connection", "OK" if result.returncode == 0 else "FAIL", ""))
    except:
        checks.append(("PostgreSQL connection", "FAIL", ""))
    
    # 4. Backend API responde
    try:
        result = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
             "http://localhost:8000/"],
            capture_output=True,
            text=True,
            timeout=10
        )
        status = "OK" if result.stdout.strip() == "200" else "FAIL"
        checks.append(("Backend API", status, ""))
    except:
        checks.append(("Backend API", "FAIL", "Not responding"))
    
    # 5. Frontend responde
    try:
        result = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
             "http://localhost:5173/"],
            capture_output=True,
            text=True,
            timeout=10
        )
        status = "OK" if result.stdout.strip() == "200" else "FAIL"
        checks.append(("Frontend", status, ""))
    except:
        checks.append(("Frontend", "FAIL", "Not responding"))
    
    return checks


def print_category(name: str):
    """Imprimir separador de categoría."""
    print(f"\n{BLUE}{BOLD}▸ {name}{RESET}")
    print(f"  {'─' * 58}")


def print_summary(passed: int, failed: int, skipped: int):
    """Imprimir resumen final."""
    total = passed + failed + skipped
    
    print(f"""
{BOLD}═══════════════════════════════════════════════════════════════{RESET}
                        SUMMARY
{BOLD}═══════════════════════════════════════════════════════════════{RESET}

    Total Checks:  {total}
    Passed:        {GREEN}{passed}{RESET}
    Failed:        {RED}{failed}{RESET}
    Skipped:       {YELLOW}{skipped}{RESET}
""")
    
    if failed == 0:
        print(f"    {GREEN}{BOLD}✓ All critical checks passed!{RESET}")
    else:
        print(f"    {RED}{BOLD}✗ {failed} check(s) failed - attention required{RESET}")
    
    print()


def main():
    """Función principal."""
    verbose = '-v' in sys.argv or '--verbose' in sys.argv
    category_filter = None
    
    # Parsear argumentos
    for i, arg in enumerate(sys.argv[1:]):
        if arg == '-c' and i + 2 < len(sys.argv):
            category_filter = sys.argv[i + 2]
    
    print_header()
    
    passed = 0
    failed = 0
    skipped = 0
    
    # ========== Quick Checks ==========
    print_category("Quick System Checks")
    for name, status, details in run_quick_checks():
        print_status(name, status, details if verbose else "")
        if status == "OK":
            passed += 1
        elif status == "FAIL":
            failed += 1
        else:
            skipped += 1
    
    # ========== Pytest Checks ==========
    test_categories = [
        ("Infrastructure Checks", "tests/health/test_infrastructure.py", "infra"),
        ("Database Checks", "tests/health/test_database.py", "database"),
        ("Backend API Checks", "tests/health/test_backend.py", "backend"),
        ("Business Logic Checks", "tests/health/test_business_logic.py", "business"),
    ]
    
    for cat_name, test_file, cat_key in test_categories:
        # Filtrar por categoría si se especificó
        if category_filter and category_filter != 'all' and category_filter != cat_key:
            continue
        
        print_category(cat_name)
        
        test_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            test_file
        )
        
        if os.path.exists(test_path):
            results = run_pytest_check(test_path)
            for result in results:
                print_status(result['name'], result['status'], 
                           result['details'] if verbose else "")
                if result['status'] == "OK":
                    passed += 1
                elif result['status'] == "FAIL":
                    failed += 1
                else:
                    skipped += 1
        else:
            print_status(f"Test file not found: {test_file}", "SKIP", "")
            skipped += 1
    
    # ========== Summary ==========
    print_summary(passed, failed, skipped)
    
    # Exit code
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
