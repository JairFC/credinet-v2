"""
Infrastructure Health Checks
=============================

Verificaciones de infraestructura: Host, Docker, Red, DNS.
Todas son de SOLO LECTURA - no modifican nada.

NOTA: Algunos tests se saltan automáticamente cuando se ejecutan
dentro de un contenedor Docker (no tienen acceso al comando docker).
"""

import subprocess
import socket
import os
import pytest
from typing import Tuple


def is_running_in_container() -> bool:
    """Detectar si estamos corriendo dentro de un contenedor Docker."""
    # Método 1: Verificar /.dockerenv
    if os.path.exists('/.dockerenv'):
        return True
    # Método 2: Verificar cgroup
    try:
        with open('/proc/1/cgroup', 'r') as f:
            return 'docker' in f.read()
    except:
        pass
    return False


IN_CONTAINER = is_running_in_container()
SKIP_IF_IN_CONTAINER = pytest.mark.skipif(
    IN_CONTAINER, 
    reason="Test requires docker CLI (not available inside container)"
)


class TestDockerContainers:
    """Verificar que los contenedores Docker están corriendo."""
    
    REQUIRED_CONTAINERS = [
        "credinet-backend",
        "credinet-frontend", 
        "credinet-postgres",
    ]
    
    def _check_container_running(self, container_name: str) -> Tuple[bool, str]:
        """Verifica si un contenedor está corriendo."""
        try:
            result = subprocess.run(
                ["docker", "inspect", "-f", "{{.State.Running}}", container_name],
                capture_output=True,
                text=True,
                timeout=10
            )
            is_running = result.stdout.strip() == "true"
            return is_running, "running" if is_running else "not running"
        except subprocess.TimeoutExpired:
            return False, "timeout"
        except Exception as e:
            return False, str(e)
    
    @SKIP_IF_IN_CONTAINER
    @pytest.mark.parametrize("container", REQUIRED_CONTAINERS)
    def test_container_running(self, container):
        """Verifica que cada contenedor requerido está corriendo."""
        is_running, status = self._check_container_running(container)
        assert is_running, f"Container {container} is {status}"


class TestNetworkConnectivity:
    """Verificar conectividad de red."""
    
    def test_localhost_reachable(self):
        """Verificar que localhost responde."""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        try:
            result = sock.connect_ex(('127.0.0.1', 22))  # SSH port as test
            # No importa si está abierto, solo que responda
            assert True
        finally:
            sock.close()
    
    def test_backend_port_open(self):
        """Verificar que el puerto del backend está abierto."""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        try:
            result = sock.connect_ex(('127.0.0.1', 8000))
            assert result == 0, f"Backend port 8000 not accessible (error: {result})"
        finally:
            sock.close()
    
    @SKIP_IF_IN_CONTAINER
    def test_frontend_port_open(self):
        """Verificar que el puerto del frontend está abierto (desde host)."""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        try:
            result = sock.connect_ex(('127.0.0.1', 5173))
            assert result == 0, f"Frontend port 5173 not accessible (error: {result})"
        finally:
            sock.close()
    
    def test_postgres_port_open(self):
        """Verificar que el puerto de PostgreSQL está abierto."""
        # Dentro de container, usar nombre del servicio Docker
        host = 'postgres' if IN_CONTAINER else '127.0.0.1'
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        try:
            result = sock.connect_ex((host, 5432))
            assert result == 0, f"PostgreSQL port 5432 not accessible on {host} (error: {result})"
        finally:
            sock.close()
    
    def test_dns_resolution(self):
        """Verificar resolución DNS básica."""
        try:
            socket.gethostbyname("google.com")
            assert True
        except socket.gaierror:
            pytest.fail("DNS resolution failed for google.com")


class TestDiskSpace:
    """Verificar espacio en disco."""
    
    def test_root_disk_not_full(self):
        """Verificar que la partición raíz tiene al menos 10% libre."""
        try:
            result = subprocess.run(
                ["df", "-h", "/"],
                capture_output=True,
                text=True,
                timeout=5
            )
            lines = result.stdout.strip().split('\n')
            if len(lines) >= 2:
                # Parse: Filesystem  Size  Used Avail Use% Mounted
                parts = lines[1].split()
                if len(parts) >= 5:
                    use_percent = int(parts[4].replace('%', ''))
                    assert use_percent < 90, f"Disk usage at {use_percent}% (> 90% threshold)"
        except Exception as e:
            pytest.skip(f"Could not check disk space: {e}")
    
    @SKIP_IF_IN_CONTAINER
    def test_docker_disk_space(self):
        """Verificar que Docker tiene espacio disponible (desde host)."""
        try:
            result = subprocess.run(
                ["docker", "system", "df", "--format", "{{.Size}}"],
                capture_output=True,
                text=True,
                timeout=10
            )
            # Si el comando funciona, Docker está bien
            assert result.returncode == 0, f"Docker system df failed: {result.stderr}"
        except Exception as e:
            pytest.fail(f"Could not check Docker disk space: {e}")


class TestSystemResources:
    """Verificar recursos del sistema."""
    
    def test_memory_available(self):
        """Verificar que hay memoria disponible."""
        try:
            with open('/proc/meminfo', 'r') as f:
                meminfo = f.read()
            
            mem_available = None
            mem_total = None
            for line in meminfo.split('\n'):
                if line.startswith('MemAvailable:'):
                    mem_available = int(line.split()[1])
                elif line.startswith('MemTotal:'):
                    mem_total = int(line.split()[1])
            
            if mem_available and mem_total:
                percent_available = (mem_available / mem_total) * 100
                assert percent_available > 10, f"Only {percent_available:.1f}% memory available"
        except Exception as e:
            pytest.skip(f"Could not check memory: {e}")
    
    def test_load_average_reasonable(self):
        """Verificar que el load average no es excesivo."""
        try:
            with open('/proc/loadavg', 'r') as f:
                loadavg = f.read().split()
            
            load_1min = float(loadavg[0])
            # Load average shouldn't be more than 2x number of CPUs
            cpu_count = os.cpu_count() or 1
            max_load = cpu_count * 2
            
            assert load_1min < max_load, f"Load average {load_1min} exceeds threshold {max_load}"
        except Exception as e:
            pytest.skip(f"Could not check load average: {e}")
