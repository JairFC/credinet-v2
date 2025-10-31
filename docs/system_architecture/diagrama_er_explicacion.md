# Diagrama Entidad-Relación de Credinet

## Descripción general

Este documento presenta el diagrama entidad-relación (ER) mejorado del sistema Credinet, mostrando las tablas existentes y sus relaciones con las mejoras propuestas. El sistema está diseñado para gestionar préstamos, clientes, asociados y documentación relacionada.

## Entidades principales

### 1. Usuarios y Autenticación

- **users**: Tabla central que almacena información de todos los usuarios del sistema (administradores, asociados, clientes).
- **roles**: Define los roles disponibles en el sistema (administrador, cliente, asociado).
- **user_roles**: Tabla de relación muchos a muchos que asigna roles a los usuarios.

### 2. Información Personal

- **addresses**: Almacena las direcciones físicas de los usuarios.
- **beneficiaries**: Guarda información de los beneficiarios designados por los clientes.
- **guarantors**: Registra los avales de los clientes para los préstamos.

### 3. Asociados y Niveles

- **associate_profiles**: Perfiles específicos para usuarios con rol de asociado.
- **associate_levels**: Niveles de asociados (Plata, Oro, Platino, Diamante) con diferentes rangos de montos y beneficios/comisiones.

### 4. Préstamos, Contratos y Pagos

- **loans**: Préstamos otorgados a los clientes con referencia obligatoria al usuario cliente.
- **contracts**: Documentos legales asociados a préstamos, con información sobre fechas y archivos.
- **payments**: Pagos realizados para amortizar los préstamos.
- **cut_periods**: Periodos de corte para contabilizar pagos y calcular comisiones.
- **associate_payment_statements**: Estados de cuenta para pagar comisiones a los asociados.

### 5. Documentación

- **document_types**: Tipos de documentos requeridos (identificación, comprobante de domicilio, etc).
- **client_documents**: Documentos específicos cargados por los clientes.

### 6. Configuración

- **system_configurations**: Parámetros configurables del sistema.

## Relaciones clave

1. Un **usuario** puede tener:
   - Múltiples **roles** (a través de user_roles)
   - Una **dirección** (relación 1:1)
   - Un **beneficiario** (relación 1:1)
   - Un **aval** (relación 1:1)
   - Múltiples **préstamos** (relación 1:N)
   - Múltiples **documentos** (relación 1:N)
   - Un **perfil de asociado** (si tiene rol de asociado)

2. Un **préstamo** está relacionado con:
   - Un **cliente** (usuario con rol de cliente) que lo solicita **(OBLIGATORIO)**
   - Un **perfil de asociado** (opcional, que refirió al cliente)
   - Un **contrato** que documenta legalmente el préstamo
   - Múltiples **pagos** (relación 1:N)

3. Cada **pago** pertenece a:
   - Un **préstamo** específico
   - Un **periodo de corte** (opcional)

4. Los **perfiles de asociados** tienen:
   - Un **nivel** (Plata, Oro, Platino, Diamante) basado en rangos de montos
   - Estados de cuenta (**associate_payment_statements**) que calculan sus comisiones
   - Vinculación a préstamos que generan comisiones

5. Cada **documento** de cliente:
   - Pertenece a un **tipo de documento**
   - Está asociado a un **cliente** (usuario)
   - Puede ser revisado por un **usuario** con permisos adecuados

## Consideraciones sobre el diseño mejorado

1. **Sistema de usuarios flexible**: Un solo modelo de usuario con roles para diferenciar funcionalidades.
2. **Separación clara entre usuarios y perfiles especializados**: Los datos específicos de asociados están en tablas separadas.
3. **Estructura de préstamos**: Diseñada para soportar diferentes frecuencias de pago y términos, con asociados opcionales.
4. **Gestión de documentos**: Sistema para cargar, revisar y aprobar documentos de clientes.
5. **Sistema de comisiones basado en niveles**: Con cuatro niveles definidos (Plata, Oro, Platino y Diamante) según montos de préstamos.

## Niveles de Asociados

El sistema incluye cuatro niveles de asociados basados en rangos de montos de crédito:

1. **Plata**: 100,000 a 300,000 pesos
2. **Oro**: 301,000 a 600,000 pesos
3. **Platino**: 601,000 a 900,000 pesos
4. **Diamante**: 901,000 pesos en adelante

Estos niveles determinan beneficios y tasas de comisión para los asociados.

## Cambios propuestos al esquema original

1. **Eliminación de la tabla `associates`** y reemplazo por `associate_profiles`
2. **Relación directa** entre usuarios y perfiles de asociado
3. **Modificación en la relación de préstamos** para referenciar perfiles de asociado en lugar de asociados
4. **Adición de la tabla `contracts`** para gestionar documentos legales de préstamos
5. **Relación bidireccional entre préstamos y contratos**:
   - Un préstamo tiene un contrato asociado
   - Un contrato pertenece a un préstamo específico

## Observaciones para futuras expansiones

1. El esquema mejorado puede expandirse para incluir:
   - Histórico de modificaciones en préstamos
   - Seguimiento de cambios en niveles de asociados
   - Configuraciones más detalladas por tipo de préstamo
   - Estados adicionales para el seguimiento de préstamos
   - Sistema de notificaciones integrado