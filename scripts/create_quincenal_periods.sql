-- Script para crear 48 períodos quincenales (2 años)
-- Quincenas: 8-22 y 23-7 del siguiente mes

DO $$
DECLARE
    year_start INTEGER := 2025;
    month_num INTEGER;
    period_num INTEGER := 1;
    start_date DATE;
    end_date DATE;
    admin_user_id INTEGER;
BEGIN
    -- Obtener ID del usuario admin
    SELECT id INTO admin_user_id FROM users WHERE username = 'admin' LIMIT 1;
    
    IF admin_user_id IS NULL THEN
        RAISE EXCEPTION 'Usuario admin no encontrado';
    END IF;

    -- Crear 48 períodos quincenales (2 años completos)
    FOR year_offset IN 0..1 LOOP
        FOR month_num IN 1..12 LOOP
            -- Primera quincena: 8 al 22
            start_date := MAKE_DATE(year_start + year_offset, month_num, 8);
            end_date := MAKE_DATE(year_start + year_offset, month_num, 22);
            
            INSERT INTO cut_periods (
                cut_number, 
                period_start_date, 
                period_end_date, 
                status, 
                created_by
            ) VALUES (
                period_num,
                start_date,
                end_date,
                CASE 
                    WHEN start_date < CURRENT_DATE THEN 'CLOSED'
                    ELSE 'ACTIVE'
                END,
                admin_user_id
            );
            
            period_num := period_num + 1;
            
            -- Segunda quincena: 23 al 7 del siguiente mes
            start_date := MAKE_DATE(year_start + year_offset, month_num, 23);
            
            -- Calcular fin de la segunda quincena (7 del siguiente mes)
            IF month_num = 12 THEN
                end_date := MAKE_DATE(year_start + year_offset + 1, 1, 7);
            ELSE
                end_date := MAKE_DATE(year_start + year_offset, month_num + 1, 7);
            END IF;
            
            INSERT INTO cut_periods (
                cut_number, 
                period_start_date, 
                period_end_date, 
                status, 
                created_by
            ) VALUES (
                period_num,
                start_date,
                end_date,
                CASE 
                    WHEN start_date < CURRENT_DATE THEN 'CLOSED'
                    ELSE 'ACTIVE'
                END,
                admin_user_id
            );
            
            period_num := period_num + 1;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE 'Creados % períodos quincenales', period_num - 1;
END $$; 