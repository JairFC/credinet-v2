-- =============================================================================
-- MIGRACIÓN 013: PLAZO FLEXIBLE (6, 12, 18, 24 QUINCENAS)
-- =============================================================================
-- Fecha: 2025-11-05
-- Descripción: Actualiza el sistema para soportar plazos flexibles en lugar
--              de solo 12 quincenas. Modifica el constraint de la tabla loans
--              para permitir únicamente 6, 12, 18 o 24 quincenas.
--
-- IMPORTANTE: Esta migración NO afecta préstamos existentes. Si hay préstamos
--             con plazos diferentes a 6, 12, 18 o 24, esta migración fallará.
--             Revisar y corregir datos antes de aplicar.
-- =============================================================================

-- Verificar que NO hay préstamos con plazos inválidos
DO $$
DECLARE
    v_invalid_count INT;
    v_invalid_terms TEXT;
BEGIN
    -- Contar préstamos con term_biweeks fuera de los valores permitidos
    SELECT COUNT(*), STRING_AGG(DISTINCT term_biweeks::TEXT, ', ')
    INTO v_invalid_count, v_invalid_terms
    FROM loans
    WHERE term_biweeks NOT IN (6, 12, 18, 24);
    
    IF v_invalid_count > 0 THEN
        RAISE EXCEPTION 
            'MIGRACIÓN 013 ABORTADA: Hay % préstamos con plazos inválidos: % quincenas. ' ||
            'Los plazos permitidos son: 6, 12, 18, 24. ' ||
            'Por favor corregir estos préstamos antes de continuar.',
            v_invalid_count, v_invalid_terms;
    ELSE
        RAISE NOTICE '✅ Verificación OK: Todos los préstamos tienen plazos válidos (6, 12, 18 o 24 quincenas)';
    END IF;
END $$;

-- =============================================================================
-- PASO 1: Eliminar constraint antiguo
-- =============================================================================
ALTER TABLE loans
DROP CONSTRAINT IF EXISTS check_loans_term_biweeks_valid;

RAISE NOTICE '✅ Constraint antiguo eliminado';

-- =============================================================================
-- PASO 2: Agregar nuevo constraint con valores específicos
-- =============================================================================
ALTER TABLE loans
ADD CONSTRAINT check_loans_term_biweeks_valid 
CHECK (term_biweeks IN (6, 12, 18, 24));

RAISE NOTICE '✅ Nuevo constraint aplicado: term_biweeks IN (6, 12, 18, 24)';

-- =============================================================================
-- PASO 3: Actualizar comentario de la columna
-- =============================================================================
COMMENT ON COLUMN loans.term_biweeks IS 
'⭐ V2.0: Plazo del préstamo en quincenas. Valores permitidos: 6, 12, 18 o 24 quincenas (3, 6, 9 o 12 meses). Validado por check_loans_term_biweeks_valid.';

RAISE NOTICE '✅ Comentario actualizado';

-- =============================================================================
-- PASO 4: Verificar constraint aplicado correctamente
-- =============================================================================
DO $$
DECLARE
    v_constraint_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'check_loans_term_biweeks_valid'
          AND conrelid = 'loans'::regclass
    ) INTO v_constraint_exists;
    
    IF v_constraint_exists THEN
        RAISE NOTICE '✅ Constraint verificado correctamente';
    ELSE
        RAISE EXCEPTION 'ERROR: Constraint check_loans_term_biweeks_valid no se aplicó correctamente';
    END IF;
END $$;

-- =============================================================================
-- PASO 5: Probar el constraint
-- =============================================================================
DO $$
BEGIN
    -- Intentar insertar un préstamo con plazo inválido (debe fallar)
    BEGIN
        INSERT INTO loans (
            user_id, 
            amount, 
            interest_rate, 
            commission_rate, 
            term_biweeks, 
            status_id
        ) VALUES (
            1, 
            10000, 
            2.5, 
            2.5, 
            15,  -- ❌ Plazo inválido
            1
        );
        
        -- Si llegamos aquí, el constraint NO funciona
        RAISE EXCEPTION 'ERROR: El constraint NO está funcionando. Se pudo insertar un plazo inválido (15).';
        
    EXCEPTION WHEN check_violation THEN
        -- Esto es lo esperado
        RAISE NOTICE '✅ Test OK: Constraint rechazó préstamo con plazo inválido (15 quincenas)';
        ROLLBACK;
    END;
END $$;

-- =============================================================================
-- RESUMEN DE LA MIGRACIÓN
-- =============================================================================
DO $$
DECLARE
    v_total_loans INT;
    v_loans_6 INT;
    v_loans_12 INT;
    v_loans_18 INT;
    v_loans_24 INT;
BEGIN
    SELECT COUNT(*) INTO v_total_loans FROM loans;
    SELECT COUNT(*) INTO v_loans_6 FROM loans WHERE term_biweeks = 6;
    SELECT COUNT(*) INTO v_loans_12 FROM loans WHERE term_biweeks = 12;
    SELECT COUNT(*) INTO v_loans_18 FROM loans WHERE term_biweeks = 18;
    SELECT COUNT(*) INTO v_loans_24 FROM loans WHERE term_biweeks = 24;
    
    RAISE NOTICE '';
    RAISE NOTICE '╔═════════════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║         MIGRACIÓN 013 COMPLETADA EXITOSAMENTE                   ║';
    RAISE NOTICE '╠═════════════════════════════════════════════════════════════════╣';
    RAISE NOTICE '║  Sistema actualizado para soportar plazos flexibles            ║';
    RAISE NOTICE '║  Valores permitidos: 6, 12, 18 o 24 quincenas                  ║';
    RAISE NOTICE '╠═════════════════════════════════════════════════════════════════╣';
    RAISE NOTICE '║  Préstamos existentes:                                         ║';
    RAISE NOTICE '║    - Total: %                                                   ║', v_total_loans;
    RAISE NOTICE '║    - Plazo 6:  % préstamos                                      ║', v_loans_6;
    RAISE NOTICE '║    - Plazo 12: % préstamos                                      ║', v_loans_12;
    RAISE NOTICE '║    - Plazo 18: % préstamos                                      ║', v_loans_18;
    RAISE NOTICE '║    - Plazo 24: % préstamos                                      ║', v_loans_24;
    RAISE NOTICE '╚═════════════════════════════════════════════════════════════════╝';
    RAISE NOTICE '';
END $$;
