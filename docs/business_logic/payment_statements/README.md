# 📄 Sistema de Relaciones de Pago (Estados de Cuenta)

**Versión**: 1.0  
**Fecha**: 2025-11-05  
**Fuente**: Análisis de PDFs reales (MELY.pdf, CLAUDIA.pdf, PILAR.pdf)

---

## 📚 Índice de Documentación

1. **[01_CONCEPTO_Y_ESTRUCTURA.md](./01_CONCEPTO_Y_ESTRUCTURA.md)**
   - Qué es una relación de pago
   - Estructura del documento
   - Análisis de los 3 PDFs reales

2. **[02_MODELO_BASE_DATOS.md](./02_MODELO_BASE_DATOS.md)**
   - Tabla `associate_payment_statements`
   - Tabla `statement_loan_details`
   - Tabla `renewed_commission_details`
   - Índices y constraints

3. **[03_LOGICA_GENERACION.md](./03_LOGICA_GENERACION.md)**
   - Algoritmo de generación
   - Cálculo de totales
   - Fórmulas matemáticas
   - Casos especiales

4. **[04_APIS_REST.md](./04_APIS_REST.md)**
   - Endpoints necesarios
   - Request/Response schemas
   - Ejemplos de uso

5. **[05_FRONTEND_DESIGN.md](./05_FRONTEND_DESIGN.md)**
   - Componentes React
   - Páginas y rutas
   - Mock data
   - Estilos CSS

6. **[06_CASOS_USO.md](./06_CASOS_USO.md)**
   - Flujos de trabajo
   - Reglas de negocio
   - Edge cases
   - Validaciones

---

## 🎯 Resumen Ejecutivo

### ¿Qué son las Relaciones de Pago?

**Documentos quincenales** que Credicuenta genera para cada asociado, detallando:
- ✅ Todos los préstamos activos que gestiona
- ✅ Pagos que debe cobrar en la quincena
- ✅ Comisiones que debe pagar a Credicuenta
- ✅ Estado de su línea de crédito
- ✅ Adeudos acumulados

### Hallazgos Clave de los PDFs

| Métrica | MELY | CLAUDIA | PILAR |
|---------|------|---------|-------|
| Crédito otorgado | $700,000 | $250,000 | $700,000 |
| Préstamos activos | 51 | 8 | 45 |
| Pagos del corte | 97 | 8 | 45 |
| Total a pagar | $91,397 | $14,198 | $98,549 |
| Adeudo acumulado | $0 | $0 | **$57,476** |

### Confirmaciones

✅ **Doble calendario**: Fechas alternas 15/30 confirmadas  
✅ **Doble tasa**: `pago_cliente - pago_asociado = comisión`  
✅ **Crédito global**: `credit_available = limit - used - debt`  
✅ **Múltiples préstamos**: Clientes con "PARTE UNO, DOS"  
✅ **Préstamos propios**: Asociados pueden prestarse a sí mismos  

### Nuevos Requerimientos

⭐ Tabla `associate_payment_statements`  
⭐ Job automático días 8 y 23  
⭐ Motor de generación de PDFs  
⭐ Gestión de comisiones renovadas  
⭐ Tracking de entregas y pagos  

---

## 🚀 Quick Start

### Para Desarrolladores

1. Leer documentos en orden (01 → 06)
2. Implementar modelo de BD (doc 02)
3. Crear APIs (doc 04)
4. Implementar frontend (doc 05)

### Para Product Owners

- Revisar **01_CONCEPTO** para entender el proceso
- Revisar **06_CASOS_USO** para reglas de negocio

---

## 📊 Prioridad de Implementación

### Sprint 1: Base de Datos
- [ ] Crear tablas (doc 02)
- [ ] Migración SQL
- [ ] Modelos SQLAlchemy

### Sprint 2: Backend
- [ ] Motor de generación (doc 03)
- [ ] APIs REST (doc 04)
- [ ] Job automático

### Sprint 3: Frontend
- [ ] Páginas principales (doc 05)
- [ ] Componentes reutilizables
- [ ] Integración con APIs

### Sprint 4: PDFs y Entregas
- [ ] Generación de PDF
- [ ] Sistema de firmas
- [ ] Registro de pagos

---

**Navegación**: 👉 Empieza con [01_CONCEPTO_Y_ESTRUCTURA.md](./01_CONCEPTO_Y_ESTRUCTURA.md)
