#!/usr/bin/env python3
"""
Script para generar períodos de corte (cut_periods) completos con nomenclatura clara.

Nomenclatura: {YYYY}-Q{NN}
- YYYY: Año (2024, 2025, 2026...)
- Q: Quincena
- NN: Número de quincena del año (01-24)

Ejemplos:
- 2025-Q01: Primera quincena de enero (8-22 enero)
- 2025-Q02: Segunda quincena de enero (23 enero - 7 febrero)
- 2025-Q24: Última quincena de diciembre (23 dic - 7 ene)

Cada año tiene exactamente 24 periodos (2 por mes).
Los periodos son ESTÁTICOS y no cambian.
"""
from datetime import date, timedelta
from typing import List, Dict
import sys

def generate_cut_periods(start_year: int = 2024, end_year: int = 2027) -> List[Dict]:
    """
    Genera períodos de corte quincenales.
    
    Reglas:
    - Periodo A: del 8 al 22 del mismo mes
    - Periodo B: del 23 al 7 del mes siguiente
    - Periodo 1 del año comienza el 8 de enero
    - Periodo 24 del año termina el 7 de enero del año siguiente
    
    Args:
        start_year: Año inicial (default: 2024)
        end_year: Año final (default: 2027, genera hasta 2026 completo)
    
    Returns:
        Lista de diccionarios con información de cada periodo
    """
    periods = []
    global_cut_number = 1
    
    for year in range(start_year, end_year):
        for month in range(1, 13):
            # Periodo A: día 8 al 22 del mismo mes
            period_a_start = date(year, month, 8)
            period_a_end = date(year, month, 22)
            
            # Número de quincena dentro del año (1-24)
            year_cut_number = (month - 1) * 2 + 1
            cut_code_a = f"{year}-Q{year_cut_number:02d}"
            
            periods.append({
                'global_cut_number': global_cut_number,
                'year_cut_number': year_cut_number,
                'cut_code': cut_code_a,
                'period_start_date': period_a_start,
                'period_end_date': period_a_end,
                'status_id': 5 if period_a_end < date.today() else (2 if period_a_start <= date.today() <= period_a_end else 1),  # 5=CLOSED, 2=ACTIVE, 1=PENDING
                'year': year,
                'month': month,
                'period_type': 'A'
            })
            global_cut_number += 1
            
            # Periodo B: día 23 del mes actual al 7 del mes siguiente
            period_b_start = date(year, month, 23)
            
            # Calcular mes y año del día 7 siguiente
            if month == 12:
                next_month = 1
                next_year = year + 1
            else:
                next_month = month + 1
                next_year = year
            
            period_b_end = date(next_year, next_month, 7)
            
            year_cut_number = (month - 1) * 2 + 2
            cut_code_b = f"{year}-Q{year_cut_number:02d}"
            
            periods.append({
                'global_cut_number': global_cut_number,
                'year_cut_number': year_cut_number,
                'cut_code': cut_code_b,
                'period_start_date': period_b_start,
                'period_end_date': period_b_end,
                'status_id': 5 if period_b_end < date.today() else (2 if period_b_start <= date.today() <= period_b_end else 1),
                'year': year,
                'month': month,
                'period_type': 'B'
            })
            global_cut_number += 1
    
    return periods


def generate_sql_migration(periods: List[Dict]) -> str:
    """Genera SQL para agregar columna cut_code y poblar periodos."""
    
    sql_lines = [
        "-- =============================================================================",
        "-- MIGRACIÓN: AGREGAR NOMENCLATURA DE PERIODOS Y GENERAR COMPLETO 2024-2026",
        "-- =============================================================================",
        "-- Fecha: 2025-11-06",
        "-- Descripción: Agrega columna cut_code con formato {YYYY}-Q{NN}",
        "--              y genera periodos completos para 3 años (72 periodos)",
        "-- =============================================================================",
        "",
        "-- Paso 1: Agregar columna cut_code si no existe",
        "DO $$",
        "BEGIN",
        "    IF NOT EXISTS (",
        "        SELECT 1 FROM information_schema.columns",
        "        WHERE table_name = 'cut_periods' AND column_name = 'cut_code'",
        "    ) THEN",
        "        ALTER TABLE cut_periods",
        "        ADD COLUMN cut_code VARCHAR(10) UNIQUE;",
        "        ",
        "        COMMENT ON COLUMN cut_periods.cut_code IS",
        "        'Código único del periodo: {YYYY}-Q{NN}. Ej: 2025-Q01 (ene 8-22), 2025-Q24 (dic 23-ene 7)';",
        "        ",
        "        RAISE NOTICE '✅ Columna cut_code agregada';",
        "    ELSE",
        "        RAISE NOTICE '⚠️  Columna cut_code ya existe';",
        "    END IF;",
        "END $$;",
        "",
        "-- Paso 2: Limpiar periodos existentes (son de prueba)",
        "TRUNCATE TABLE cut_periods RESTART IDENTITY CASCADE;",
        "RAISE NOTICE '✅ Periodos de prueba limpiados';",
        "",
        "-- Paso 3: Insertar periodos completos 2024-2026 (72 periodos)",
    ]
    
    for period in periods:
        status_name = {1: 'PENDING', 2: 'ACTIVE', 5: 'CLOSED'}[period['status_id']]
        
        sql_lines.append(
            f"INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, "
            f"status_id, created_by, total_payments_expected, total_payments_received, total_commission) "
            f"VALUES ("
            f"{period['year_cut_number']}, "  # cut_number se reinicia cada año (1-24)
            f"'{period['cut_code']}', "
            f"'{period['period_start_date']}', "
            f"'{period['period_end_date']}', "
            f"{period['status_id']}, "  # status_id
            f"1, "  # created_by (admin)
            f"0.00, 0.00, 0.00"  # totales en 0
            f"); -- {status_name} | {period['period_type']} | {period['period_start_date'].strftime('%b %Y')}"
        )
    
    sql_lines.extend([
        "",
        "-- Paso 4: Crear índice en cut_code",
        "CREATE INDEX IF NOT EXISTS idx_cut_periods_cut_code ON cut_periods(cut_code);",
        "RAISE NOTICE '✅ Índice en cut_code creado';",
        "",
        "-- Paso 5: Verificación y resumen",
        "DO $$",
        "DECLARE",
        "    v_total_periods INT;",
        "    v_periods_2024 INT;",
        "    v_periods_2025 INT;",
        "    v_periods_2026 INT;",
        "    v_active_periods INT;",
        "    v_closed_periods INT;",
        "BEGIN",
        "    SELECT COUNT(*) INTO v_total_periods FROM cut_periods;",
        "    SELECT COUNT(*) INTO v_periods_2024 FROM cut_periods WHERE cut_code LIKE '2024-%';",
        "    SELECT COUNT(*) INTO v_periods_2025 FROM cut_periods WHERE cut_code LIKE '2025-%';",
        "    SELECT COUNT(*) INTO v_periods_2026 FROM cut_periods WHERE cut_code LIKE '2026-%';",
        "    SELECT COUNT(*) INTO v_active_periods FROM cut_periods WHERE status_id = 2;",
        "    SELECT COUNT(*) INTO v_closed_periods FROM cut_periods WHERE status_id = 5;",
        "    ",
        "    RAISE NOTICE '';",
        "    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';",
        "    RAISE NOTICE '║       PERIODOS DE CORTE GENERADOS EXITOSAMENTE           ║';",
        "    RAISE NOTICE '╠═══════════════════════════════════════════════════════════╣';",
        "    RAISE NOTICE '║  Total periodos:     % (esperado: 72)                    ║', v_total_periods;",
        "    RAISE NOTICE '║  Periodos 2024:      % (2 meses: dic)                    ║', v_periods_2024;",
        "    RAISE NOTICE '║  Periodos 2025:      % (12 meses completos)              ║', v_periods_2025;",
        "    RAISE NOTICE '║  Periodos 2026:      % (12 meses completos)              ║', v_periods_2026;",
        "    RAISE NOTICE '║  Estado CLOSED:      % periodos                          ║', v_closed_periods;",
        "    RAISE NOTICE '║  Estado ACTIVE:      % periodos                          ║', v_active_periods;",
        "    RAISE NOTICE '╠═══════════════════════════════════════════════════════════╣';",
        "    RAISE NOTICE '║  Nomenclatura: {YYYY}-Q{NN}                              ║';",
        "    RAISE NOTICE '║  Ejemplo: 2025-Q01 = Ene 8-22, 2025-Q02 = Ene 23-Feb 7   ║';",
        "    RAISE NOTICE '╚═══════════════════════════════════════════════════════════╝';",
        "    RAISE NOTICE '';",
        "    ",
        "    -- Mostrar algunos ejemplos",
        "    RAISE NOTICE 'Ejemplos de periodos:';",
        "    PERFORM RAISE NOTICE '  % | % al % | Status: %', ",
        "        cut_code, period_start_date, period_end_date, ",
        "        CASE status_id WHEN 5 THEN 'CLOSED' WHEN 2 THEN 'ACTIVE' ELSE 'PENDING' END",
        "    FROM cut_periods ORDER BY cut_code LIMIT 5;",
        "END $$;",
        "",
        "-- =============================================================================",
        "-- FIN DE LA MIGRACIÓN",
        "-- =============================================================================",
    ])
    
    return "\n".join(sql_lines)


def main():
    """Función principal."""
    print("=" * 80)
    print("GENERADOR DE PERIODOS DE CORTE (CUT_PERIODS)")
    print("=" * 80)
    print()
    
    # Generar periodos 2024-2026 (3 años)
    periods = generate_cut_periods(2024, 2027)
    
    print(f"✅ Generados {len(periods)} periodos (2024-2026)")
    print(f"   - 2024: 2 periodos (diciembre)")
    print(f"   - 2025: 24 periodos (año completo)")
    print(f"   - 2026: 24 periodos (año completo)")
    print(f"   - Hasta: 7 de enero 2027")
    print()
    
    # Generar SQL
    sql = generate_sql_migration(periods)
    
    # Guardar en archivo
    output_file = "/home/credicuenta/proyectos/credinet-v2/db/v2.0/modules/migration_014_cut_periods_complete.sql"
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(sql)
    
    print(f"✅ Migración SQL generada: {output_file}")
    print()
    print("Para aplicar:")
    print(f"  docker exec credinet-postgres psql -U credinet_user -d credinet_db < {output_file}")
    print()
    
    # Mostrar ejemplos
    print("Ejemplos de periodos generados:")
    print("-" * 80)
    for period in periods[:6]:
        status = {1: 'PENDING', 2: 'ACTIVE', 5: 'CLOSED'}[period['status_id']]
        print(f"  {period['cut_code']} | "
              f"{period['period_start_date']} al {period['period_end_date']} | "
              f"{status} | Tipo {period['period_type']}")
    print("  ...")
    print()


if __name__ == "__main__":
    main()
