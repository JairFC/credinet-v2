#!/bin/bash
# Script para crear usuario admin de prueba en CrediNet v2.0

echo "🔧 Creando usuario administrador en base de datos..."
echo ""
echo "Credenciales:"
echo "  Username: admin"
echo "  Password: admin123"
echo "  Email: admin@credinet.com (opcional)"
echo ""

# Conectar a PostgreSQL y crear usuario
docker exec -it credinet-postgres psql -U credinet_user -d credinet_db <<-EOSQL
-- Verificar si ya existe
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin') THEN
    INSERT INTO users (username, email, password_hash, full_name, role, is_active, is_defaulter, created_at)
    VALUES (
      'admin',
      'admin@credinet.com',
      '\$2b\$12\$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYfYGbRvCNe',
      'Admin CrediNet',
      'administrador',
      true,
      false,
      NOW()
    );
    RAISE NOTICE '✅ Usuario admin creado exitosamente';
  ELSE
    RAISE NOTICE '⚠️  Usuario admin ya existe';
  END IF;
END
\$\$;

-- Verificar
SELECT id, username, email, full_name, role, is_active 
FROM users 
WHERE username = 'admin';
EOSQL

echo ""
echo "✅ Listo! Ahora puedes hacer login en http://localhost:8000/docs"
echo ""
echo "Usa estas credenciales:"
echo "  Username: admin"
echo "  Password: admin123"
