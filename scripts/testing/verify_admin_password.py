"""
Script para verificar/actualizar contraseña del usuario admin
"""
import sys
sys.path.append('/home/credicuenta/proyectos/credinet-v2/backend')

from app.core.security import hash_password, verify_password

# Hash actual en la BD
current_hash = "$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6"

# Contraseñas a probar
passwords_to_test = [
    "admin123",
    "Admin123!",
    "admin",
]

print("🔐 Verificando contraseñas contra el hash actual...")
print(f"Hash: {current_hash}\n")

for pwd in passwords_to_test:
    result = verify_password(pwd, current_hash)
    status = "✅ VÁLIDA" if result else "❌ INVÁLIDA"
    print(f"{status} - '{pwd}'")

print("\n" + "="*60)
print("💡 Generando nuevos hashes para referencia:\n")

for pwd in passwords_to_test:
    new_hash = hash_password(pwd)
    print(f"Contraseña: '{pwd}'")
    print(f"Hash:       {new_hash}\n")
