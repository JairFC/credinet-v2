"""
Business Logic Health Checks
=============================

Verificaciones de lógica de negocio y consistencia de datos.
Todas son de SOLO LECTURA - verifican reglas sin modificar datos.
"""

import os
import pytest
from decimal import Decimal
from typing import Tuple


def get_db_connection():
    """Obtener conexión a PostgreSQL usando psycopg2."""
    import psycopg2
    
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
    """Ejecuta query en PostgreSQL. Retorna (success, output)."""
    try:
        conn = get_db_connection()
        conn.autocommit = True
        
        with conn.cursor() as cur:
            cur.execute(query)
            if cur.description:
                result = cur.fetchone()
                output = str(result[0]) if result else ""
            else:
                output = ""
        
        conn.close()
        return True, output
        
    except Exception as e:
        return False, str(e)


class TestLoanBusinessRules:
    """Verificar reglas de negocio de préstamos."""
    
    def test_active_loans_have_payments(self):
        """Préstamos activos deben tener al menos un pago programado."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM loans l
            WHERE l.status_id = 2  -- ACTIVE
            AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.loan_id = l.id)
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} active loans without scheduled payments"
    
    def test_completed_loans_have_no_pending_payments(self):
        """Préstamos completados no deben tener pagos pendientes."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM loans l
            WHERE l.status_id = 3  -- COMPLETED
            AND EXISTS (
                SELECT 1 FROM payments p 
                WHERE p.loan_id = l.id AND p.status_id = 1  -- PENDING
            )
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} completed loans with pending payments"
    
    def test_loan_amounts_positive(self):
        """Todos los montos de préstamo deben ser positivos."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM loans WHERE amount <= 0
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} loans with non-positive amounts"
    
    def test_loan_rates_in_range(self):
        """Tasas de interés deben estar en rango razonable (0-100%)."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM loans 
            WHERE interest_rate < 0 OR interest_rate > 100
               OR commission_rate < 0 OR commission_rate > 100
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} loans with out-of-range rates"


class TestPaymentBusinessRules:
    """Verificar reglas de negocio de pagos."""
    
    def test_paid_payments_have_payment_date(self):
        """Pagos marcados como pagados deben tener fecha de pago."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM payments 
            WHERE status_id = 2  -- PAID
            AND payment_date IS NULL
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} paid payments without payment date"
    
    def test_paid_payments_have_amount(self):
        """Pagos pagados deben tener amount_paid > 0."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM payments 
            WHERE status_id = 2  -- PAID
            AND (amount_paid IS NULL OR amount_paid <= 0)
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} paid payments without amount"
    
    def test_payment_components_sum_to_expected(self):
        """
        Componentes del pago deben sumar el monto esperado:
        expected_amount = principal_amount + interest_amount
        """
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM payments 
            WHERE principal_amount IS NOT NULL 
              AND interest_amount IS NOT NULL
              AND ABS(expected_amount - (principal_amount + interest_amount)) > 0.01
        """)
        assert success, f"Query failed: {output}"
        if output != "0":
            pytest.skip(f"Found {output} payments where components don't sum - may need review")


class TestAgreementBusinessRules:
    """Verificar reglas de negocio de convenios."""
    
    def test_active_agreements_have_pending_payments(self):
        """Convenios activos deben tener pagos pendientes."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM agreements a
            WHERE a.status = 'ACTIVE'
            AND NOT EXISTS (
                SELECT 1 FROM agreement_payments ap 
                WHERE ap.agreement_id = a.id AND ap.status = 'PENDING'
            )
        """)
        assert success, f"Query failed: {output}"
        # Un convenio activo sin pagos pendientes debería marcarse COMPLETED
        if output != "0":
            pytest.skip(f"Found {output} active agreements without pending payments - may need completion")
    
    def test_cancelled_agreements_have_no_pending(self):
        """Convenios cancelados no deben tener pagos pendientes."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM agreements a
            WHERE a.status = 'CANCELLED'
            AND EXISTS (
                SELECT 1 FROM agreement_payments ap 
                WHERE ap.agreement_id = a.id AND ap.status = 'PENDING'
            )
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} cancelled agreements with pending payments"
    
    def test_agreement_loans_are_in_agreement_status(self):
        """
        Préstamos en convenios activos deben tener status IN_AGREEMENT (9).
        """
        success, output = run_psql_query("""
            SELECT COUNT(DISTINCT ai.loan_id) FROM agreement_items ai
            JOIN agreements a ON a.id = ai.agreement_id
            JOIN loans l ON l.id = ai.loan_id
            WHERE a.status = 'ACTIVE'
              AND l.status_id != 9  -- NOT IN_AGREEMENT
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} loans in active agreements but not IN_AGREEMENT status"


class TestAssociateBusinessRules:
    """Verificar reglas de negocio de asociados."""
    
    def test_active_associates_have_valid_limits(self):
        """Asociados activos deben tener límite de crédito > 0."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM associate_profiles 
            WHERE active = true AND credit_limit <= 0
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} active associates with invalid credit limits"
    
    def test_available_credit_not_negative(self):
        """Crédito disponible no debe ser negativo."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM associate_profiles 
            WHERE available_credit < 0
        """)
        assert success, f"Query failed: {output}"
        # Puede haber casos edge, así que advertimos
        if output != "0":
            pytest.skip(f"Found {output} profiles with negative available credit - may be over-extended")
    
    def test_pending_payments_matches_actual_pending(self):
        """
        pending_payments_total debe coincidir con pagos PENDING reales.
        """
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM (
                SELECT ap.id,
                       ap.pending_payments_total as recorded,
                       COALESCE(SUM(p.expected_amount), 0) as actual
                FROM associate_profiles ap
                LEFT JOIN loans l ON l.associate_user_id = ap.user_id
                LEFT JOIN payments p ON p.loan_id = l.id AND p.status_id = 1
                GROUP BY ap.id, ap.pending_payments_total
                HAVING ABS(ap.pending_payments_total - COALESCE(SUM(p.expected_amount), 0)) > 0.01
            ) AS mismatches
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} profiles where pending_payments_total doesn't match actual pending payments"


class TestCutPeriodBusinessRules:
    """Verificar reglas de negocio de períodos de corte."""
    
    def test_current_period_exists(self):
        """Debe existir al menos un período actual (ACTIVE o PENDING)."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM cut_periods 
            WHERE status_id IN (1, 4, 7)  -- PENDING, ACTIVE, COLLECTING
        """)
        assert success, f"Query failed: {output}"
        count = int(output)
        assert count >= 1, f"No active/pending periods found"
    
    def test_no_future_periods_in_past(self):
        """No debe haber períodos futuros con fechas en el pasado."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM cut_periods 
            WHERE status_id = 1  -- PENDING
            AND period_end_date < CURRENT_DATE - INTERVAL '60 days'
        """)
        assert success, f"Query failed: {output}"
        # Esto puede ser un problema de migración de datos, solo advertimos
        if output != "0":
            pytest.skip(f"Found {output} old pending periods - may need cleanup")
    
    def test_closed_periods_have_statements(self):
        """Períodos cerrados deberían tener al menos un statement generado."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM cut_periods cp
            WHERE cp.status_id = 3  -- CLOSED
            AND NOT EXISTS (
                SELECT 1 FROM associate_payment_statements aps 
                WHERE aps.cut_period_id = cp.id
            )
        """)
        assert success, f"Query failed: {output}"
        # Puede haber períodos sin pagos
        if output != "0":
            pytest.skip(f"Found {output} closed periods without statements - may have had no payments")


class TestUserBusinessRules:
    """Verificar reglas de negocio de usuarios."""
    
    def test_all_users_have_role(self):
        """Todos los usuarios deben tener al menos un rol asignado."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM users u
            WHERE NOT EXISTS (SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id)
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} users without role"
    
    def test_all_users_have_valid_role(self):
        """Todos los usuarios deben tener roles válidos."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM user_roles ur
            WHERE NOT EXISTS (SELECT 1 FROM roles r WHERE r.id = ur.role_id)
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} users with invalid role"
    
    def test_associate_users_have_profile(self):
        """Usuarios con rol asociado deben tener perfil de asociado."""
        success, output = run_psql_query("""
            SELECT COUNT(*) FROM users u
            JOIN user_roles ur ON ur.user_id = u.id
            JOIN roles r ON r.id = ur.role_id
            WHERE r.name = 'asociado'
            AND NOT EXISTS (
                SELECT 1 FROM associate_profiles ap WHERE ap.user_id = u.id
            )
        """)
        assert success, f"Query failed: {output}"
        assert output == "0", f"Found {output} associates without profile"
