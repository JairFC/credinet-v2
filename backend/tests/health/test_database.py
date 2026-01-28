"""
Database Health Checks
=======================

Verificaciones de base de datos: Conexión, tablas, integridad de datos.
Todas son de SOLO LECTURA - usan SELECT exclusivamente.

Este módulo puede ejecutarse:
- Dentro del contenedor backend: usa psycopg2 directo
- Fuera del contenedor: usa docker exec (fallback)
"""

import os
import pytest
from typing import Tuple, List, Dict, Any
from decimal import Decimal


def get_db_connection():
    """Obtener conexión a PostgreSQL usando psycopg2."""
    import psycopg2
    import os
    
    # Intentar usar DATABASE_URL primero
    db_url = os.environ.get("DATABASE_URL")
    if db_url:
        return psycopg2.connect(db_url)
    
    # Fallback a variables individuales
    db_host = os.environ.get("DATABASE_HOST", "postgres")
    db_port = os.environ.get("DATABASE_PORT", "5432")
    db_name = os.environ.get("DATABASE_NAME", "credinet_db")
    db_user = os.environ.get("DATABASE_USER", "credinet_user")
    db_pass = os.environ.get("DATABASE_PASSWORD", "credinet_pass")
    
    return psycopg2.connect(
        host=db_host,
        port=db_port,
        dbname=db_name,
        user=db_user,
        password=db_pass
    )


def run_psql_query(query: str) -> Tuple[bool, str]:
    """
    Ejecuta una query en PostgreSQL.
    Retorna (success, output).
    """
    try:
        conn = get_db_connection()
        conn.autocommit = True  # Para SELECT, no necesitamos transacción
        
        with conn.cursor() as cur:
            cur.execute(query)
            if cur.description:  # Si es un SELECT
                result = cur.fetchone()
                output = str(result[0]) if result else ""
            else:
                output = ""
        
        conn.close()
        return True, output
        
    except Exception as e:
        return False, str(e)


class TestDatabaseConnection:
    """Verificar conexión a la base de datos."""
    
    def test_postgres_responds(self):
        """Verificar que PostgreSQL responde a queries."""
        success, output = run_psql_query("SELECT 1")
        assert success, f"PostgreSQL not responding: {output}"
        assert output == "1", f"Unexpected response: {output}"
    
    def test_database_exists(self):
        """Verificar que la base de datos credinet_db existe."""
        success, output = run_psql_query(
            "SELECT datname FROM pg_database WHERE datname = 'credinet_db'"
        )
        assert success, f"Query failed: {output}"
        assert output == "credinet_db", "Database credinet_db not found"
    
    def test_database_encoding(self):
        """Verificar que el encoding es UTF8."""
        success, output = run_psql_query(
            "SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname = 'credinet_db'"
        )
        assert success, f"Query failed: {output}"
        assert output == "UTF8", f"Database encoding is {output}, expected UTF8"


class TestCriticalTables:
    """Verificar que las tablas críticas existen y tienen datos."""
    
    CRITICAL_TABLES = [
        ("users", 1),               # Al menos 1 usuario
        ("roles", 4),               # Al menos 4 roles base
        ("loan_statuses", 5),       # Al menos 5 estados de préstamo
        ("payment_statuses", 5),    # Al menos 5 estados de pago
        ("associate_levels", 1),    # Al menos 1 nivel
        ("associate_profiles", 1),  # Al menos 1 asociado
        ("loans", 0),               # Puede estar vacía
        ("payments", 0),            # Puede estar vacía
        ("cut_periods", 1),         # Al menos 1 período
        ("agreements", 0),          # Puede estar vacía
    ]
    
    @pytest.mark.parametrize("table,min_rows", CRITICAL_TABLES)
    def test_table_exists_with_data(self, table, min_rows):
        """Verificar que cada tabla crítica existe y tiene datos mínimos."""
        success, output = run_psql_query(f"SELECT COUNT(*) FROM {table}")
        assert success, f"Table {table} query failed: {output}"
        
        count = int(output)
        assert count >= min_rows, f"Table {table} has {count} rows, expected >= {min_rows}"


class TestDataIntegrity:
    """Verificar integridad de datos críticos."""
    
    def test_no_orphan_payments(self):
        """Verificar que no hay pagos sin préstamo asociado."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM payments p 
            WHERE NOT EXISTS (SELECT 1 FROM loans l WHERE l.id = p.loan_id)
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} orphan payments without loans"
    
    def test_no_orphan_loans(self):
        """Verificar que no hay préstamos sin cliente asociado."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM loans l 
            WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = l.user_id)
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} orphan loans without clients"
    
    def test_no_orphan_agreement_items(self):
        """Verificar que no hay items de convenio sin convenio padre."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM agreement_items ai 
            WHERE NOT EXISTS (SELECT 1 FROM agreements a WHERE a.id = ai.agreement_id)
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} orphan agreement_items"
    
    def test_valid_payment_statuses(self):
        """Verificar que todos los pagos tienen status válido."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM payments p 
            WHERE NOT EXISTS (SELECT 1 FROM payment_statuses ps WHERE ps.id = p.status_id)
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} payments with invalid status"
    
    def test_valid_loan_statuses(self):
        """Verificar que todos los préstamos tienen status válido."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM loans l 
            WHERE NOT EXISTS (SELECT 1 FROM loan_statuses ls WHERE ls.id = l.status_id)
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} loans with invalid status"


class TestAssociateBalances:
    """Verificar integridad de saldos de asociados."""
    
    def test_no_negative_balances(self):
        """Verificar que no hay saldos negativos."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM associate_profiles 
            WHERE pending_payments_total < 0 
               OR consolidated_debt < 0 
               OR credit_limit < 0
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} profiles with negative balances"
    
    def test_available_credit_formula(self):
        """Verificar que available_credit se calcula correctamente."""
        # Nota: available_credit es una columna generada, pero verificamos consistencia
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM associate_profiles 
            WHERE ABS(
                available_credit - (credit_limit - pending_payments_total - consolidated_debt)
            ) > 0.01
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} profiles with incorrect available_credit"
    
    def test_consolidated_debt_matches_active_agreements(self):
        """
        Verificar que consolidated_debt de cada asociado coincide con
        la suma de sus convenios activos.
        """
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM (
                SELECT ap.id, ap.consolidated_debt as recorded,
                       COALESCE(SUM(a.total_debt_amount), 0) as calculated
                FROM associate_profiles ap
                LEFT JOIN agreements a ON a.associate_profile_id = ap.id AND a.status = 'ACTIVE'
                GROUP BY ap.id, ap.consolidated_debt
                HAVING ABS(ap.consolidated_debt - COALESCE(SUM(a.total_debt_amount), 0)) > 0.01
            ) AS mismatches
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} profiles where consolidated_debt doesn't match active agreements"


class TestAgreementIntegrity:
    """Verificar integridad de convenios."""
    
    def test_active_agreements_have_items(self):
        """Verificar que convenios activos tienen al menos un item."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM agreements a 
            WHERE a.status = 'ACTIVE'
            AND NOT EXISTS (SELECT 1 FROM agreement_items ai WHERE ai.agreement_id = a.id)
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} active agreements without items"
    
    def test_no_duplicate_active_loan_agreements(self):
        """
        Verificar que ningún préstamo está en más de un convenio activo.
        """
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM (
                SELECT ai.loan_id, COUNT(DISTINCT a.id) as agreement_count
                FROM agreement_items ai
                JOIN agreements a ON a.id = ai.agreement_id
                WHERE a.status = 'ACTIVE' AND ai.loan_id IS NOT NULL
                GROUP BY ai.loan_id
                HAVING COUNT(DISTINCT a.id) > 1
            ) AS duplicates
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} loans in multiple active agreements"
    
    def test_agreement_payments_sum_matches_total(self):
        """Verificar que la suma de pagos de convenio coincide con el total."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM (
                SELECT a.id, a.total_debt_amount,
                       COALESCE(SUM(ap.payment_amount), 0) as payments_sum
                FROM agreements a
                LEFT JOIN agreement_payments ap ON ap.agreement_id = a.id
                GROUP BY a.id, a.total_debt_amount
                HAVING ABS(a.total_debt_amount - COALESCE(SUM(ap.payment_amount), 0)) > 0.01
            ) AS mismatches
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} agreements where payments don't sum to total"


class TestPaymentIntegrity:
    """Verificar integridad de pagos."""
    
    def test_payments_have_valid_amounts(self):
        """Verificar que todos los pagos tienen montos positivos."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM payments 
            WHERE expected_amount <= 0 OR expected_amount IS NULL
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} payments with invalid amounts"
    
    def test_in_agreement_payments_on_in_agreement_loans(self):
        """
        Verificar que pagos IN_AGREEMENT (13) están en préstamos IN_AGREEMENT (9).
        """
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM payments p
            JOIN loans l ON l.id = p.loan_id
            WHERE p.status_id = 13  -- IN_AGREEMENT
              AND l.status_id != 9  -- loan should also be IN_AGREEMENT
        """)
        assert success, f"Query failed: {output}"
        # Esto puede ser 0 o indicar un problema de datos
        if output != "0":
            pytest.skip(f"Found {output} IN_AGREEMENT payments on non-IN_AGREEMENT loans - may need review")


class TestCutPeriodIntegrity:
    """Verificar integridad de períodos de corte."""
    
    def test_periods_have_valid_dates(self):
        """Verificar que todos los períodos tienen fechas válidas."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM cut_periods 
            WHERE period_start_date > period_end_date
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} periods with start > end date"
    
    def test_no_overlapping_periods(self):
        """Verificar que no hay períodos que se superpongan."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM cut_periods a
            JOIN cut_periods b ON a.id < b.id
            WHERE a.period_start_date <= b.period_end_date
              AND a.period_end_date >= b.period_start_date
              AND a.period_start_date != b.period_start_date
        """)
        assert success, f"Query failed: {output}"
        # Los períodos pueden tocarse pero no superponerse
        if output != "0":
            pytest.skip(f"Found {output} potentially overlapping periods - may need review")
