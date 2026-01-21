# 📦 CREDINET v2.0 - Backup Definitivo

## Contenido del Backup

| Archivo | Tamaño | Descripción |
|---------|--------|-------------|
| `00_restore_complete.sql` | ~1.2MB | **ARCHIVO MAESTRO** - Restaura TODO |
| `01_schema.sql` | ~224KB | Solo estructura (tablas, índices) |
| `02_functions.sql` | ~899KB | Todas las funciones (40) |
| `03_catalogs_data.sql` | ~94KB | Datos de catálogos |
| `full_backup.dump` | ~606KB | Backup binario pg_dump |

## 🚀 Restauración Rápida (Recomendado)

### Opción 1: Desde archivo SQL maestro
```bash
# 1. Crear base de datos vacía
docker exec -it credinet-postgres psql -U postgres -c "DROP DATABASE IF EXISTS credinet_db;"
docker exec -it credinet-postgres psql -U postgres -c "CREATE DATABASE credinet_db OWNER credinet_user;"

# 2. Restaurar TODO
docker exec -i credinet-postgres psql -U credinet_user -d credinet_db < 00_restore_complete.sql
```

### Opción 2: Desde dump binario (más rápido)
```bash
# Restaurar backup completo con datos
docker exec -i credinet-postgres pg_restore -U credinet_user -d credinet_db --clean --if-exists < full_backup.dump
```

## 📥 Descargar a tu PC

Desde tu PC local, ejecuta:
```bash
# Descargar todo el directorio de backup
scp -r credicuenta@192.168.98.98:/home/credicuenta/proyectos/credinet-v2/db/backup_definitivo ./

# O solo el archivo maestro
scp credicuenta@192.168.98.98:/home/credicuenta/proyectos/credinet-v2/db/backup_definitivo/00_restore_complete.sql ./
```

## 📋 Verificación del Backup

Este backup incluye:
- ✅ 41 tablas
- ✅ 40 funciones (incluyendo 13 que NO estaban en init.sql)
- ✅ 35 triggers
- ✅ 16 vistas
- ✅ Todos los índices y constraints
- ✅ Datos de catálogos (sin datos de prueba)

### Funciones Críticas Incluidas (NO estaban en init.sql):
1. `apply_debt_payment_v2` - Aplicación de pagos a deuda
2. `apply_excess_to_debt_fifo` - Exceso FIFO a deuda
3. `auto_generate_statements_at_midnight` - Generación automática estados
4. `calculate_loan_payment_custom` - Cálculo pagos personalizados
5. `finalize_statements_manual` - Finalizar estados manual
6. `get_cut_period_for_payment` - Período de corte para pagos
7. `get_debt_payment_detail` - Detalle de pagos de deuda
8. `simulate_loan_complete` - Simulación completa préstamos
9. `simulate_loan_custom` - Simulación personalizada
10. `update_updated_at_column` - Trigger updated_at
11. `validate_loan_calculated_fields` - Validación campos préstamo
12. `validate_loan_payment_schedule` - Validación plan pagos
13. `validate_payment_breakdown` - Validación desglose pagos

## 🔐 Credenciales por Defecto

- **Usuario DB**: `credinet_user`
- **Password DB**: `credinet_password_2024`
- **Database**: `credinet_db`
- **Usuario Admin**: `admin` / password hasheado

---
Generado: $(date)
