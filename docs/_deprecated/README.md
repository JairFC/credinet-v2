# 📁 Documentación Deprecated

**Fecha de movimiento:** 2026-01-09  
**Razón:** Estos archivos contienen información desactualizada o han sido reemplazados por documentación más reciente.

## Archivos en este directorio

| Archivo | Razón de Deprecación | Reemplazado por |
|---------|---------------------|-----------------|
| `LOGICA_DE_NEGOCIO_DEFINITIVA.md` | Oct 2025 - Usa nomenclatura antigua (credit_used, debt_balance) | `MODELO_DEUDA_CREDITO_DEFINITIVO.md` |
| `LOGICA_CIERRE_PERIODO_Y_DEUDA.md` | Nov 2025 - Información desactualizada sobre cierre de períodos | `MODELO_DEUDA_CREDITO_DEFINITIVO.md` |
| `CORRECCIONES_APLICADAS.md` | Nov 2025 - Correcciones ya integradas | N/A (histórico) |
| `SESION_2025-11-06_COMPLETADA.md` | Nov 2025 - Sesión de trabajo completada | N/A (histórico) |
| `LIMPIEZA_COMPLETADA.md` | Nov 2025 - Limpieza ya aplicada | N/A (histórico) |

## Documentación Actual Recomendada

Para entender la lógica de saldos y créditos, consultar:

1. **`MODELO_DEUDA_CREDITO_DEFINITIVO.md`** - Lógica completa del sistema de crédito ⭐
2. **`ANALISIS_DEBT_TRACKING_2026-01-08.md`** - Análisis de seguimiento de deuda
3. **`ANALISIS_EXHAUSTIVO_FLUJO_DINERO.md`** - Flujo de dinero detallado
4. **`DATABASE_SCHEMA_COMPLETE.md`** - Esquema de base de datos

## Nomenclatura Correcta

| ❌ Deprecated | ✅ Actual |
|--------------|----------|
| `credit_used` | `pending_payments_total` |
| `debt_balance` | `consolidated_debt` |
| `credit_available` | `available_credit` |
| `APPROVED` (status) | `ACTIVE` (status unificado) |

> ⚠️ **NO usar estos archivos como referencia.** Contienen información que puede causar confusión.
