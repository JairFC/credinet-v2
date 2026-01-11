-- =============================================================================
-- MIGRACIÓN 023: Alias para check_associate_available_credit
-- =============================================================================
-- Descripción:
--   El código Python llama a check_associate_available_credit() pero la función
--   en la DB se llama check_associate_credit_available() (palabras invertidas).
--   
--   Esta migración crea un ALIAS que simplemente redirige la llamada.
--
-- CAUSA DEL BUG:
--   Inconsistencia de nomenclatura entre:
--   - DB: check_associate_credit_available (creada en migración 07)
--   - Python: check_associate_available_credit (en repositories/__init__.py)
--
-- Fecha: 2025-01-09
-- Autor: Sistema
-- =============================================================================

-- Crear alias de la función con el nombre que espera Python
CREATE OR REPLACE FUNCTION check_associate_available_credit(
    p_associate_profile_id INTEGER,
    p_requested_amount NUMERIC
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    -- Simplemente llamar a la función correcta
    RETURN check_associate_credit_available(p_associate_profile_id, p_requested_amount);
END;
$$;

COMMENT ON FUNCTION check_associate_available_credit(INTEGER, NUMERIC) IS 
'Alias de check_associate_credit_available para compatibilidad con código Python.
La función original fue creada en migración 07 con nombre diferente.';
