# 🧹 PLAN DE LIMPIEZA CREDINET v2.0 - OPERACIÓN CERO LEGACY

**Fecha**: 30 de Octubre, 2025  
**Objetivo**: Eliminar TODO el código legacy y dejar solo v2.0 limpio  
**Status**: 🔴 EN PROGRESO  
**Responsable**: Equipo de Desarrollo

---

## 📊 ANÁLISIS DE SITUACIÓN ACTUAL

### ✅ CÓDIGO LIMPIO (PRESERVAR)

#### Base de Datos ✅
```
/db/v2.0/
├── init.sql                          # Orquestador modular ⭐
├── init_monolithic_fixed.sql         # Versión producción ⭐
├── 02_patch_email_nullable.sql       # Patch crítico ⭐
├── modules/                          # 9 módulos SQL limpios ⭐
│   ├── 01_catalog_tables.sql
│   ├── 02_core_tables.sql
│   ├── 03_business_tables.sql
│   ├── 04_audit_tables.sql
│   ├── 05_functions_base.sql
│   ├── 06_functions_business.sql
│   ├── 07_triggers.sql
│   ├── 08_views.sql
│   └── 09_seeds.sql
├── README.md                         # Documentación v2.0 ⭐
├── RESUMEN_COMPLETO_v2.0.md          # Resumen ejecutivo ⭐
├── PROGRESO_FINAL.md                 # Estado actual ⭐
├── generate_monolithic.sh            # Script generador ⭐
└── validate_syntax.sh                # Validador SQL ⭐
```

#### Backend Clean Architecture ✅
```
/backend/app/
├── main.py                           # Entry point FastAPI ⭐
├── core/                             # Configuración y seguridad ⭐
│   ├── config.py
│   ├── database.py
│   ├── dependencies.py
│   ├── exceptions.py
│   ├── middleware.py
│   └── security.py
├── modules/                          # Módulos de negocio ⭐
│   └── auth/
└── shared/                           # Código compartido ⭐
    └── domain/

/backend/
├── cli.py                            # CLI de gestión ⭐
├── Dockerfile                        # Containerización ⭐
├── requirements.txt                  # Dependencias actuales ⭐
├── pyproject.toml                    # Config proyecto ⭐
├── pytest.ini                        # Config testing ⭐
├── smoke_test.py                     # Test de humo ⭐
├── tests/                            # Suite de tests ⭐
├── templates/                        # Templates emails ⭐
└── uploads/                          # Archivos subidos ⭐
```

#### Frontend ✅
```
/frontend/
├── src/                              # Todo el código React ⭐
├── public/                           # Assets públicos ⭐
├── Dockerfile                        # Containerización ⭐
├── package.json                      # Dependencias ⭐
├── vite.config.js                    # Config Vite ⭐
└── index.html                        # Entry HTML ⭐
```

#### Documentación Activa ✅
```
/docs/
├── LOGICA_DE_NEGOCIO_DEFINITIVA.md   # Doc maestro lógica ⭐
├── PLAN_MAESTRO_V2.0.md              # Plan maestro ⭐
├── GUIA_BACKEND_V2.0.md              # Guía desarrollo ⭐
├── ARQUITECTURA_BACKEND_V2_DEFINITIVA.md ⭐
├── BACKEND.md                        # Doc backend ⭐
├── FRONTEND.md                       # Doc frontend ⭐
├── DEPLOYMENT.md                     # Guía deploy ⭐
├── DEVELOPMENT.md                    # Guía desarrollo ⭐
├── business_logic/                   # Lógica de negocio ⭐
├── guides/                           # Guías técnicas ⭐
├── onboarding/                       # Onboarding devs ⭐
├── system_architecture/              # Arquitectura ⭐
└── adr/                              # Decisiones arquitectura ⭐
```

#### Scripts Útiles ✅
```
/scripts/
├── create_admin_user.sh              # Admin user ⭐
├── start_backend.sh                  # Start backend ⭐
├── database/setup_db.sh              # Setup DB ⭐
├── testing/                          # Scripts testing ⭐
└── validation/                       # Scripts validación ⭐
```

#### Configuración Raíz ✅
```
/
├── docker-compose.yml                # Orquestación ⭐
├── README.md                         # Readme principal ⭐
└── .gitignore                        # Git ignore ⭐
```

---

### 🗑️ CÓDIGO LEGACY (ELIMINAR)

#### Base de Datos Legacy ❌
```
/db/
├── init_clean.sql                    # Versión antigua ❌
├── migrations/                       # Migraciones antiguas ❌
│   ├── 06_business_logic_*.sql
│   ├── 07_associate_credit_tracking.sql
│   ├── 08_fix_period_closure_logic.sql
│   ├── 09_defaulted_clients_tracking.sql
│   ├── 10_late_fee_system.sql
│   ├── 11_payment_statuses_consolidated.sql
│   └── 12_payment_status_history.sql
├── deprecated/                       # Carpeta deprecated ❌
│   ├── backups/
│   ├── docs_old/
│   ├── migrations_legacy/
│   ├── migrations_old/
│   └── v1.0/
└── docs/                             # Docs duplicados ❌
    ├── 00_RESUMEN_AUDITORIA.md
    ├── 01_DIAGRAMA_ER.md
    ├── 02_AUDITORIA_EXHAUSTIVA.md
    └── ... (todos duplicados en v2.0/README.md)
```

**DECISIÓN**: 
- ✅ PRESERVAR: `/db/v2.0/` completo
- ❌ ELIMINAR: Todo lo demás en `/db/`
- ℹ️ OPCIONAL: Mover `/db/deprecated/` a `/archive_legacy/` por si acaso

#### Backend Legacy ❌
```
/backend/
├── app_deprecated/                   # TODO EL MÓDULO ❌
│   ├── addresses/
│   ├── api/
│   ├── application/
│   ├── associates/
│   ├── auth/
│   ├── beneficiaries/
│   ├── clients/
│   ├── common/
│   ├── core/
│   ├── cutoffs/
│   ├── documents/
│   ├── domain/
│   ├── guarantors/
│   ├── loans/
│   ├── main.py
│   ├── notifications/
│   ├── payments/
│   ├── periods/
│   ├── requirements.txt
│   ├── templates/
│   ├── tests/
│   └── utils/
└── requirements_old.txt              # Dependencias antiguas ❌
```

**DECISIÓN**:
- ❌ ELIMINAR: `/backend/app_deprecated/` completo (17.5 MB)
- ❌ ELIMINAR: `/backend/requirements_old.txt`

#### Documentación Legacy ❌
```
/docs/
├── archive/                          # Archivos de 2025-09 y 2025-10 ❌
│   ├── 2025-09/                      # 25+ archivos de Sept ❌
│   ├── 2025-10/                      # 30+ archivos de Oct ❌
│   ├── completed_tasks/              # Tareas completadas ❌
│   ├── deprecated/                   # Deprecated ❌
│   └── personas/                     # Personas (no usado) ❌
├── deprecated/                       # Más deprecated ❌
│   ├── old_docs/
│   └── session_summaries/
├── phase3/                           # Fase 3 no iniciada ❌
└── resumen_comprensivo/              # Info duplicada en v2.0 ❌
```

**DECISIÓN**:
- ❌ ELIMINAR: `/docs/archive/` completo
- ❌ ELIMINAR: `/docs/deprecated/`
- ❌ ELIMINAR: `/docs/phase3/` (no iniciado)
- ❌ ELIMINAR: `/docs/resumen_comprensivo/` (info en v2.0)

#### Documentos Raíz Legacy ❌
```
/
├── ANALISIS_PROFUNDO_PROYECTO.md     # Análisis antiguo ❌
├── FASE2_COMPLETADA.md               # Fase antigua ❌
├── SPRINT_1_COMPLETADO.md            # Sprint antiguo ❌
└── GIT_CHECKPOINT_v2.0.md            # Checkpoint superado ❌
```

**DECISIÓN**:
- ℹ️ MOVER a `/archive_legacy/docs_historicos/`

---

## 🎯 PLAN DE EJECUCIÓN POR FASES

### FASE 1: Preparación y Backup 📦
**Duración**: 5 minutos  
**Risk**: 🟢 Bajo

1. ✅ Crear carpeta de archivo histórico
2. ✅ Mover documentos raíz a archivo
3. ✅ Commit de seguridad en Git

```bash
# Crear carpeta de archivo
mkdir -p /home/credicuenta/proyectos/credinet/archive_legacy

# Mover docs históricos
mv ANALISIS_PROFUNDO_PROYECTO.md archive_legacy/
mv FASE2_COMPLETADA.md archive_legacy/
mv SPRINT_1_COMPLETADO.md archive_legacy/
mv GIT_CHECKPOINT_v2.0.md archive_legacy/

# Git checkpoint
git add -A
git commit -m "CHECKPOINT: Pre-limpieza v2.0 - Archivo histórico creado"
```

---

### FASE 2: Limpieza Base de Datos 🗄️
**Duración**: 10 minutos  
**Risk**: 🟡 Medio

#### 2.1 Mover deprecated a archivo
```bash
mv /home/credicuenta/proyectos/credinet/db/deprecated \
   /home/credicuenta/proyectos/credinet/archive_legacy/db_deprecated
```

#### 2.2 Eliminar migraciones legacy
```bash
rm -rf /home/credicuenta/proyectos/credinet/db/migrations
```

#### 2.3 Eliminar docs duplicados
```bash
rm -rf /home/credicuenta/proyectos/credinet/db/docs
```

#### 2.4 Eliminar init_clean.sql antiguo
```bash
rm /home/credicuenta/proyectos/credinet/db/init_clean.sql
rm /home/credicuenta/proyectos/credinet/db/AUDITORIA_*.md
rm /home/credicuenta/proyectos/credinet/db/CONSOLIDACION_COMPLETA.md
rm /home/credicuenta/proyectos/credinet/db/ESTRUCTURA_INIT_CLEAN.md
rm /home/credicuenta/proyectos/credinet/db/OPERACION_CIMIENTOS_SOLIDOS_COMPLETADA.md
rm /home/credicuenta/proyectos/credinet/db/RESUMEN_MIGRACIONES_CONSOLIDACION.md
```

#### 2.5 Actualizar README de /db/
```bash
# Solo dejar v2.0/ y un README simple apuntando ahí
```

#### Resultado Esperado
```
/db/
├── v2.0/              # TODO el código de DB ⭐
│   └── ... (sin cambios)
└── README.md          # README simple redirigiendo a v2.0/
```

---

### FASE 3: Limpieza Backend 🔧
**Duración**: 5 minutos  
**Risk**: 🟢 Bajo

#### 3.1 Eliminar app_deprecated
```bash
rm -rf /home/credicuenta/proyectos/credinet/backend/app_deprecated
```

#### 3.2 Eliminar requirements_old
```bash
rm /home/credicuenta/proyectos/credinet/backend/requirements_old.txt
```

#### 3.3 Limpiar __pycache__
```bash
find /home/credicuenta/proyectos/credinet/backend -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
find /home/credicuenta/proyectos/credinet/backend -type f -name "*.pyc" -delete
```

#### Resultado Esperado
```
/backend/
├── app/               # Clean Architecture ⭐
├── tests/             # Test suite ⭐
├── templates/         # Templates ⭐
├── uploads/           # User uploads ⭐
├── cli.py
├── Dockerfile
├── requirements.txt
├── pyproject.toml
├── pytest.ini
├── smoke_test.py
└── README.md
```

---

### FASE 4: Limpieza Documentación 📚
**Duración**: 5 minutos  
**Risk**: 🟢 Bajo

#### 4.1 Mover archive a archivo histórico
```bash
mv /home/credicuenta/proyectos/credinet/docs/archive \
   /home/credicuenta/proyectos/credinet/archive_legacy/docs_archive
```

#### 4.2 Mover deprecated
```bash
mv /home/credicuenta/proyectos/credinet/docs/deprecated \
   /home/credicuenta/proyectos/credinet/archive_legacy/docs_deprecated
```

#### 4.3 Eliminar phase3 (no iniciada)
```bash
rm -rf /home/credicuenta/proyectos/credinet/docs/phase3
```

#### 4.4 Eliminar resumen_comprensivo (duplicado)
```bash
rm -rf /home/credicuenta/proyectos/credinet/docs/resumen_comprensivo
```

#### Resultado Esperado
```
/docs/
├── LOGICA_DE_NEGOCIO_DEFINITIVA.md   ⭐
├── PLAN_MAESTRO_V2.0.md              ⭐
├── GUIA_BACKEND_V2.0.md              ⭐
├── ARQUITECTURA_*.md                 ⭐
├── business_logic/                   ⭐
├── guides/                           ⭐
├── onboarding/                       ⭐
├── system_architecture/              ⭐
├── adr/                              ⭐
├── context.json
├── CONTEXT.md
└── README.md
```

---

### FASE 5: Limpieza Docker 🐳
**Duración**: 10 minutos  
**Risk**: 🔴 Alto (Destruye datos)

#### ⚠️ ADVERTENCIA: Esta fase eliminará TODOS los datos de la DB actual

#### 5.1 Detener servicios
```bash
cd /home/credicuenta/proyectos/credinet
docker-compose down
```

#### 5.2 Eliminar volúmenes (⚠️ DESTRUCTIVO)
```bash
docker volume rm credinet-postgres-data
docker volume rm credinet-backend-uploads
docker volume rm credinet-backend-logs
```

#### 5.3 Eliminar imágenes no usadas
```bash
docker image prune -af
```

#### 5.4 Recrear ambiente limpio
```bash
# Levantar servicios con v2.0
docker-compose up -d postgres

# Esperar a que postgres esté listo
sleep 30

# Verificar que v2.0 se cargó correctamente
docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "\dt"
```

#### 5.5 Levantar backend y frontend
```bash
docker-compose up -d backend
docker-compose up -d frontend
```

---

### FASE 6: Validación y Testing ✅
**Duración**: 15 minutos  
**Risk**: 🟢 Bajo

#### 6.1 Verificar servicios
```bash
docker-compose ps
docker-compose logs -f --tail=50
```

#### 6.2 Health checks
```bash
# Postgres
docker exec credinet-postgres pg_isready

# Backend
curl http://localhost:8000/health

# Verificar tablas v2.0
docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;
"
```

#### 6.3 Smoke tests
```bash
cd /home/credicuenta/proyectos/credinet/backend
python smoke_test.py
```

#### 6.4 Test suite (opcional)
```bash
pytest tests/ -v --tb=short
```

---

### FASE 7: Documentación Final 📝
**Duración**: 10 minutos  
**Risk**: 🟢 Bajo

#### 7.1 Actualizar README principal
- Remover referencias a código legacy
- Actualizar estructura del proyecto
- Confirmar que apunta a v2.0

#### 7.2 Crear documento de migración completada
```bash
# Crear MIGRACION_v2.0_COMPLETADA.md
```

#### 7.3 Actualizar .gitignore
```bash
# Agregar archive_legacy/ si es necesario
echo "archive_legacy/" >> .gitignore
```

#### 7.4 Commit final
```bash
git add -A
git commit -m "✨ LIMPIEZA COMPLETA v2.0: Eliminado todo código legacy

- ❌ Eliminado /db/migrations, /db/docs, /db/deprecated
- ❌ Eliminado /backend/app_deprecated (17.5 MB)
- ❌ Eliminado /docs/archive, /docs/deprecated, /docs/phase3
- ✅ Preservado /db/v2.0/ completo
- ✅ Preservado /backend/app/ Clean Architecture
- ✅ Docker recreado con v2.0
- ✅ Tests pasando
"
```

---

## 📏 MÉTRICAS DE LIMPIEZA

### Antes de Limpieza
```
Tamaño total: ~150 MB
Archivos: ~470+
Carpetas: ~120+
```

### Después de Limpieza (Estimado)
```
Tamaño total: ~80 MB (-47%)
Archivos: ~250 (-47%)
Carpetas: ~60 (-50%)
```

### Archivos Eliminados (Estimado)
- **Backend Legacy**: ~220 archivos, ~17.5 MB
- **Docs Archive**: ~80 archivos, ~8 MB
- **DB Legacy**: ~30 archivos, ~2 MB
- **Total eliminado**: ~330 archivos, ~27.5 MB

---

## ⚠️ RIESGOS Y MITIGACIONES

### Riesgo Alto 🔴
**Docker Volumes**: Eliminar volúmenes destruye datos
- **Mitigación**: Hacer backup de DB antes, tener archivo histórico

### Riesgo Medio 🟡
**Referencias rotas**: Código que apunte a archivos eliminados
- **Mitigación**: Buscar referencias antes de eliminar, tests después

### Riesgo Bajo 🟢
**Rollback**: Si algo falla, recuperar de Git
- **Mitigación**: Commits frecuentes, checkpoint antes de empezar

---

## ✅ CHECKLIST DE VALIDACIÓN FINAL

Después de completar todas las fases, verificar:

- [ ] Servicios Docker corriendo (postgres, backend, frontend)
- [ ] Health checks pasando
- [ ] Base de datos con v2.0 (34 tablas, 16 funciones, 28 triggers)
- [ ] Backend Clean Architecture sin app_deprecated
- [ ] Frontend funcionando
- [ ] Smoke tests pasando
- [ ] README actualizado
- [ ] Documentación coherente
- [ ] Git limpio (no referencias rotas)
- [ ] .gitignore actualizado
- [ ] Estructura de proyecto clara

---

## 🎯 RESULTADO ESPERADO

```
credinet/
├── backend/
│   ├── app/              # ⭐ Clean Architecture
│   ├── tests/            # ⭐ Test suite
│   └── ...
├── db/
│   └── v2.0/             # ⭐ ÚNICA fuente de verdad DB
├── docs/
│   ├── LOGICA_DE_NEGOCIO_DEFINITIVA.md  # ⭐ Doc maestro
│   ├── PLAN_MAESTRO_V2.0.md             # ⭐ Plan v2.0
│   └── ...
├── frontend/
│   └── src/              # ⭐ React + Vite
├── scripts/              # ⭐ Scripts útiles
├── archive_legacy/       # 📦 Archivo histórico (opcional)
├── docker-compose.yml    # ⭐ v2.0
└── README.md             # ⭐ Actualizado

TOTAL: Proyecto limpio, mantenible, sin legacy
```

---

## 🚀 SIGUIENTE PASO

**Ejecutar FASE 1** y continuar secuencialmente.

¿Proceder con la limpieza? 
