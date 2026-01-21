# 🤖 Prompt para Agente de Producción - Merge 2026-01-21

## Instrucciones para el Agente

Lee este prompt completo antes de ejecutar cualquier acción.

---

## Tu Tarea

Eres el agente de producción. Debes realizar un merge seguro y controlado desde `develop` a `main`.

**IMPORTANTE:** Antes de ejecutar cualquier comando, LEE el archivo `MERGE_GUIDE_2026-01-21.md` en la raíz del proyecto.

---

## Secuencia de Pasos

### Paso 1: Leer la guía
```bash
cat MERGE_GUIDE_2026-01-21.md
```

Analiza el contenido y asegúrate de entender:
- Qué archivos fueron modificados
- Qué cambios funcionales hay
- Posibles problemas y soluciones

### Paso 2: Validar estructura de BD
```bash
docker compose exec db psql -U credinet_user -d credinet_db -c "SELECT id, name FROM roles ORDER BY id;"
```

Verifica que los IDs de roles sean:
- 4 = asociado
- 5 = cliente

### Paso 3: Fetch y comparar
```bash
git fetch origin
git log --oneline main -5
git log --oneline origin/develop -5
git diff --name-only main..origin/develop
```

### Paso 4: Verificar conflictos
```bash
git checkout main
git merge --no-commit --no-ff origin/develop
```

- Si hay conflictos: Resuelve manualmente, asegurándote de conservar los cambios de develop
- Si no hay conflictos: Continúa con `git merge --abort` y luego el merge real

### Paso 5: Merge real
```bash
git merge origin/develop -m "Merge develop: Sistema multi-rol y auditoría mejorada v2026-01-21"
```

### Paso 6: Push
```bash
git push origin main
```

### Paso 7: Reiniciar servicios
```bash
docker compose restart backend
# Esperar 10 segundos
sleep 10
docker compose logs backend --tail 20
```

### Paso 8: Validar
```bash
# Health check
curl -s http://localhost:8000/health

# Verificar que no hay errores en logs
docker compose logs backend --tail 50 | grep -i error
```

---

## Criterios de Éxito

✅ Merge completado sin conflictos  
✅ Backend reiniciado sin errores  
✅ Endpoint /health responde OK  
✅ Logs sin errores críticos  

---

## Si algo falla

```bash
# Rollback inmediato
git checkout main
git reset --hard HEAD~1
git push origin main --force
docker compose restart backend
```

---

## Notas Finales

- **NO migres datos** - Solo código
- **NO modifiques** el archivo `MERGE_GUIDE_2026-01-21.md`
- **Reporta** cualquier problema encontrado
- Los cambios son de sistema multi-rol y auditoría - no tocan flujo de pagos ni préstamos

---

**Generado:** 2026-01-21  
**Para:** Agente de Producción  
**Desde:** Agente de Desarrollo
