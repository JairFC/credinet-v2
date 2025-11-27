-- =========================================================================
-- HOTFIX: Agregar columna 'active' a tabla users
-- =========================================================================
-- Fecha: 2025-11-05
-- Razón: El modelo del backend (UserModel) espera la columna 'active'
--        pero la tabla users en v2.0 no la tiene definida.
--        Esto causa error en /api/v1/auth/login
-- 
-- Error original:
-- asyncpg.exceptions.UndefinedColumnError: column users.active does not exist
-- =========================================================================

-- Agregar columna 'active' con valor por defecto TRUE
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT TRUE;

-- Comentario
COMMENT ON COLUMN users.active IS 'Indica si el usuario está activo en el sistema. Los usuarios inactivos no pueden iniciar sesión.';

-- Crear índice para búsquedas frecuentes de usuarios activos
CREATE INDEX IF NOT EXISTS idx_users_active ON users(active);

-- Verificación
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'active';

-- Resultado esperado:
-- column_name | data_type | column_default | is_nullable
-- ------------+-----------+----------------+-------------
-- active      | boolean   | true           | NO
