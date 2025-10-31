"""
Script para generar períodos automáticos quincenales
Los períodos siempre son: 8 y 23 de cada mes
"""
from datetime import date, datetime
import calendar

def generate_biweekly_periods(start_year: int = 2024, num_years: int = 2):
    """
    Genera períodos quincenales automáticos para el sistema
    Cada mes tiene exactamente 2 períodos: 8 y 23
    """
    periods = []
    cut_number = 1
    
    for year in range(start_year, start_year + num_years):
        for month in range(1, 13):
            # Primer corte del mes: del día 24 del mes anterior al día 8
            if month == 1:
                if year == start_year:
                    period_1_start = date(year, month, 1)  # Inicio del año
                else:
                    period_1_start = date(year - 1, 12, 24)
            else:
                period_1_start = date(year, month - 1, 24) if month > 1 else date(year - 1, 12, 24)
            
            period_1_end = date(year, month, 8)
            
            # Segundo corte del mes: del día 9 al día 23
            period_2_start = date(year, month, 9)
            period_2_end = date(year, month, 23)
            
            periods.append({
                'cut_number': cut_number,
                'period_start_date': period_1_start,
                'period_end_date': period_1_end,
                'status': 'CLOSED' if period_1_end < date.today() else 'ACTIVE'
            })
            cut_number += 1
            
            periods.append({
                'cut_number': cut_number,
                'period_start_date': period_2_start,
                'period_end_date': period_2_end,
                'status': 'CLOSED' if period_2_end < date.today() else 'ACTIVE'
            })
            cut_number += 1
    
    return periods

def generate_insert_sql():
    """Genera el SQL para insertar los períodos automáticos"""
    periods = generate_biweekly_periods(2024, 2)
    
    sql_lines = [
        "-- Limpiar períodos existentes",
        "DELETE FROM cut_periods;",
        "ALTER SEQUENCE cut_periods_id_seq RESTART WITH 1;",
        "",
        "-- Insertar períodos automáticos quincenales",
    ]
    
    for period in periods:
        sql_lines.append(
            f"INSERT INTO cut_periods (cut_number, period_start_date, period_end_date, status, created_by) "
            f"VALUES ({period['cut_number']}, '{period['period_start_date']}', '{period['period_end_date']}', "
            f"'{period['status']}', 1);"
        )
    
    return "\n".join(sql_lines)

if __name__ == "__main__":
    print(generate_insert_sql())