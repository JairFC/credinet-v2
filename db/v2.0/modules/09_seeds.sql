-- =============================================================================
-- CREDINET DB v2.0 - MÓDULO 09: SEEDS (DATOS INICIALES)
-- =============================================================================
-- Descripción:
--   Datos iniciales del sistema para arranque completo.
--   Incluye catálogos, usuarios de prueba, préstamos de ejemplo.
--
-- Contenido:
--   - Catálogos (12 tablas): roles, statuses, levels, types
--   - Usuarios de prueba (8 usuarios + 1 aval)
--   - Préstamos de ejemplo (4 préstamos con casos reales)
--   - Períodos de corte (8 períodos: 2024-2025)
--   - Configuraciones del sistema
--
-- Versión: 2.0.0
-- Fecha: 2025-10-30
-- =============================================================================

-- =============================================================================
-- CATÁLOGO 1: ROLES (5 registros)
-- =============================================================================
INSERT INTO roles (id, name) VALUES
(1, 'desarrollador'),
(2, 'administrador'),
(3, 'auxiliar_administrativo'),
(4, 'asociado'),
(5, 'cliente')
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 2: ASSOCIATE_LEVELS (5 niveles)
-- =============================================================================
INSERT INTO associate_levels (id, name, max_loan_amount, credit_limit) VALUES
(1, 'Bronce', 50000.00, 25000.00),
(2, 'Plata', 100000.00, 50000.00),
(3, 'Oro', 250000.00, 125000.00),
(4, 'Platino', 600000.00, 300000.00),
(5, 'Diamante', 1000000.00, 500000.00)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 3: LOAN_STATUSES (8 estados)
-- =============================================================================
INSERT INTO loan_statuses (name, description, is_active, display_order, color_code, icon_name) VALUES
    ('PENDING', 'Préstamo solicitado pero aún no aprobado ni desembolsado.', TRUE, 1, '#FFA500', 'clock'),
    ('APPROVED', 'Préstamo aprobado, listo para desembolso y generación de cronograma.', TRUE, 2, '#4CAF50', 'check-circle'),
    ('ACTIVE', 'Préstamo desembolsado y activo, con pagos en curso.', TRUE, 3, '#2196F3', 'activity'),
    ('COMPLETED', 'Préstamo completamente liquidado.', TRUE, 4, '#00C853', 'check-all'),
    ('PAID', 'Préstamo totalmente pagado (sinónimo de COMPLETED).', TRUE, 5, '#00C853', 'check-all'),
    ('DEFAULTED', 'Préstamo en mora o incumplimiento.', TRUE, 6, '#F44336', 'alert-triangle'),
    ('REJECTED', 'Solicitud rechazada por administrador.', TRUE, 7, '#9E9E9E', 'x-circle'),
    ('CANCELLED', 'Préstamo cancelado antes de completarse.', TRUE, 8, '#757575', 'slash')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 4: PAYMENT_STATUSES (12 estados ⭐ v2.0)
-- =============================================================================
INSERT INTO payment_statuses (id, name, description, is_real_payment, display_order, color_code, icon_name) VALUES
    -- Estados pendientes (6)
    (1, 'PENDING', 'Pago programado, aún no vence.', TRUE, 1, '#9E9E9E', 'clock'),
    (2, 'DUE_TODAY', 'Pago vence hoy.', TRUE, 2, '#FF9800', 'calendar'),
    (4, 'OVERDUE', 'Pago vencido, no pagado.', TRUE, 4, '#F44336', 'alert-circle'),
    (5, 'PARTIAL', 'Pago parcial realizado.', TRUE, 5, '#2196F3', 'pie-chart'),
    (6, 'IN_COLLECTION', 'En proceso de cobranza.', TRUE, 6, '#9C27B0', 'phone'),
    (7, 'RESCHEDULED', 'Pago reprogramado.', TRUE, 7, '#03A9F4', 'refresh-cw'),
    
    -- Estados pagados reales (2) 💵
    (3, 'PAID', 'Pago completado por cliente.', TRUE, 3, '#4CAF50', 'check'),
    (8, 'PAID_PARTIAL', 'Pago parcial aceptado.', TRUE, 8, '#8BC34A', 'check-circle'),
    
    -- Estados ficticios (4) ⚠️
    (9, 'PAID_BY_ASSOCIATE', 'Pagado por asociado (cliente moroso).', FALSE, 9, '#FF5722', 'user-x'),
    (10, 'PAID_NOT_REPORTED', 'Pago no reportado al cierre.', FALSE, 10, '#FFC107', 'alert-triangle'),
    (11, 'FORGIVEN', 'Pago perdonado por administración.', FALSE, 11, '#00BCD4', 'heart'),
    (12, 'CANCELLED', 'Pago cancelado.', FALSE, 12, '#607D8B', 'x')
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 5: CONTRACT_STATUSES (6 estados)
-- =============================================================================
INSERT INTO contract_statuses (name, description, is_active, requires_signature, display_order) VALUES
    ('draft', 'Contrato en borrador.', TRUE, FALSE, 1),
    ('pending', 'Pendiente de firma del cliente.', TRUE, TRUE, 2),
    ('signed', 'Firmado por el cliente.', TRUE, FALSE, 3),
    ('active', 'Contrato activo y vigente.', TRUE, FALSE, 4),
    ('completed', 'Contrato completado, préstamo liquidado.', TRUE, FALSE, 5),
    ('cancelled', 'Contrato cancelado.', TRUE, FALSE, 6)
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 6: CUT_PERIOD_STATUSES (5 estados)
-- =============================================================================
INSERT INTO cut_period_statuses (name, description, is_terminal, allows_payments, display_order) VALUES
    ('PRELIMINARY', 'Período creado, en configuración.', FALSE, FALSE, 1),
    ('ACTIVE', 'Período activo, permite operaciones.', FALSE, TRUE, 2),
    ('REVIEW', 'En revisión contable.', FALSE, FALSE, 3),
    ('LOCKED', 'Bloqueado para cierre.', FALSE, FALSE, 4),
    ('CLOSED', 'Cerrado definitivamente.', TRUE, FALSE, 5)
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 7: PAYMENT_METHODS (7 métodos)
-- =============================================================================
INSERT INTO payment_methods (name, description, is_active, requires_reference, display_order, icon_name) VALUES
    ('CASH', 'Pago en efectivo.', TRUE, FALSE, 1, 'dollar-sign'),
    ('TRANSFER', 'Transferencia bancaria.', TRUE, TRUE, 2, 'arrow-right-circle'),
    ('CHECK', 'Cheque bancario.', TRUE, TRUE, 3, 'file-text'),
    ('PAYROLL_DEDUCTION', 'Descuento de nómina.', TRUE, FALSE, 4, 'briefcase'),
    ('CARD', 'Tarjeta débito/crédito.', TRUE, TRUE, 5, 'credit-card'),
    ('DEPOSIT', 'Depósito bancario.', TRUE, TRUE, 6, 'inbox'),
    ('OXXO', 'Pago en OXXO.', TRUE, TRUE, 7, 'shopping-bag')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 8: DOCUMENT_STATUSES (4 estados)
-- =============================================================================
INSERT INTO document_statuses (name, description, display_order, color_code) VALUES
    ('PENDING', 'Documento cargado, pendiente de revisión.', 1, '#FFA500'),
    ('UNDER_REVIEW', 'En proceso de revisión.', 2, '#2196F3'),
    ('APPROVED', 'Documento aprobado.', 3, '#4CAF50'),
    ('REJECTED', 'Documento rechazado.', 4, '#F44336')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 9: STATEMENT_STATUSES (5 estados)
-- =============================================================================
INSERT INTO statement_statuses (name, description, is_paid, display_order, color_code) VALUES
    ('GENERATED', 'Estado de cuenta generado.', FALSE, 1, '#9E9E9E'),
    ('SENT', 'Enviado al asociado.', FALSE, 2, '#2196F3'),
    ('PAID', 'Pagado completamente.', TRUE, 3, '#4CAF50'),
    ('PARTIAL_PAID', 'Pago parcial recibido.', FALSE, 4, '#FF9800'),
    ('OVERDUE', 'Vencido sin pagar.', FALSE, 5, '#F44336')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 10: CONFIG_TYPES (8 tipos)
-- =============================================================================
INSERT INTO config_types (name, description, validation_regex, example_value) VALUES
    ('STRING', 'Cadena de texto.', NULL, 'Hola Mundo'),
    ('NUMBER', 'Número entero o decimal.', '^-?\d+(\.\d+)?$', '123.45'),
    ('BOOLEAN', 'Valor booleano.', '^(true|false)$', 'true'),
    ('JSON', 'Objeto JSON válido.', NULL, '{"key": "value"}'),
    ('URL', 'URL válida.', '^https?://[^\s]+$', 'https://ejemplo.com'),
    ('EMAIL', 'Correo electrónico.', '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', 'user@example.com'),
    ('DATE', 'Fecha ISO 8601.', '^\d{4}-\d{2}-\d{2}$', '2025-10-30'),
    ('PERCENTAGE', 'Porcentaje 0-100.', '^(100(\.0+)?|\d{1,2}(\.\d+)?)$', '15.5')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 11: LEVEL_CHANGE_TYPES (6 tipos)
-- =============================================================================
INSERT INTO level_change_types (name, description, is_automatic, display_order) VALUES
    ('PROMOTION', 'Promoción automática a nivel superior.', TRUE, 1),
    ('DEMOTION', 'Descenso por incumplimiento.', TRUE, 2),
    ('MANUAL', 'Cambio manual por admin.', FALSE, 3),
    ('INITIAL', 'Nivel inicial al registrarse.', FALSE, 4),
    ('REWARD', 'Promoción especial por logro.', FALSE, 5),
    ('PENALTY', 'Descenso por sanción.', FALSE, 6)
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 12: DOCUMENT_TYPES (5 tipos)
-- =============================================================================
INSERT INTO document_types (id, name, description, is_required) VALUES
(1, 'Identificación Oficial', 'INE, Pasaporte o Cédula Profesional', true),
(2, 'Comprobante de Domicilio', 'Recibo de luz, agua o predial', true),
(3, 'Comprobante de Ingresos', 'Estado de cuenta o constancia laboral', true),
(4, 'CURP', 'Clave Única de Registro de Población', false),
(5, 'Referencia Personal', 'Datos de contacto de referencia', false)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- USUARIOS DE PRUEBA (9 usuarios)
-- Contraseña para todos: Sparrow20
-- Hash bcrypt: $2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6
-- =============================================================================
INSERT INTO users (id, username, password_hash, first_name, last_name, email, phone_number, birth_date, curp) VALUES
(1, 'jair', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Jair', 'FC', 'jair@dev.com', '5511223344', '1990-01-15', 'FERJ900115HDFXXX01'),
(2, 'admin', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Admin', 'Total', 'admin@credinet.com', '5522334455', NULL, NULL),
(3, 'asociado_test', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Asociado', 'Prueba', 'asociado@test.com', '5533445566', NULL, NULL),
(4, 'sofia.vargas', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Sofía', 'Vargas', 'sofia.vargas@email.com', '5544556677', '1985-05-20', 'VARS850520MDFXXX02'),
(5, 'juan.perez', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Juan', 'Pérez', 'juan.perez@email.com', '5555667788', '1992-11-30', 'PERJ921130HDFXXX03'),
(6, 'laura.mtz', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Laura', 'Martínez', 'laura.martinez@email.com', '5566778899', NULL, NULL),
(7, 'aux.admin', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Pedro', 'Ramírez', 'pedro.ramirez@credinet.com', '5577889900', NULL, NULL),
(8, 'asociado_norte', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'User', 'Norte', 'user@norte.com', '5588990011', NULL, NULL),
(1000, 'aval_test', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'María', 'Aval', 'maria.aval@demo.com', '6143618296', '1995-05-25', 'FACJ950525HCHRRR04')
ON CONFLICT (id) DO NOTHING;

-- Asignar roles
INSERT INTO user_roles (user_id, role_id) VALUES
(1, 1), -- jair: desarrollador
(2, 2), -- admin: administrador  
(3, 4), -- asociado_test: asociado
(4, 5), -- sofia.vargas: cliente
(5, 5), -- juan.perez: cliente
(6, 5), -- laura.mtz: cliente
(7, 3), -- aux.admin: auxiliar_administrativo
(8, 4), -- asociado_norte: asociado
(1000, 5) -- aval_test: cliente
ON CONFLICT DO NOTHING;

-- Perfiles de asociados
INSERT INTO associate_profiles (user_id, level_id, contact_person, contact_email, default_commission_rate, credit_limit) VALUES
(3, 2, 'Contacto Central', 'central@distribuidora.com', 4.5, 50000.00),
(8, 1, 'Contacto Norte', 'norte@creditos.com', 5.0, 25000.00)
ON CONFLICT (user_id) DO NOTHING;

-- =============================================================================
-- PRÉSTAMOS DE EJEMPLO (5 préstamos con diferentes plazos)
-- =============================================================================
-- ⭐ V2.0: Ejemplos con plazos flexibles: 6, 12, 18 y 24 quincenas
INSERT INTO loans (id, user_id, associate_user_id, amount, interest_rate, commission_rate, term_biweeks, status_id, created_at, updated_at) VALUES
-- Préstamo 1: Plazo 12 quincenas (6 meses) - Caso más común
(1, 4, 3, 100000.00, 2.5, 2.5, 12, 1, '2025-01-07 00:00:00+00', '2025-01-07 00:00:00+00'),
-- Préstamo 2: Plazo 6 quincenas (3 meses) - Plazo corto
(2, 5, 8, 50000.00, 3.0, 3.0, 6, 1, '2025-02-08 00:00:00+00', '2025-02-08 00:00:00+00'),
-- Préstamo 3: Plazo 18 quincenas (9 meses) - Plazo medio
(3, 6, 3, 150000.00, 2.0, 2.0, 18, 1, '2025-02-23 00:00:00+00', '2025-02-23 00:00:00+00'),
-- Préstamo 4: Plazo 24 quincenas (12 meses) - Plazo largo
(4, 1000, 3, 200000.00, 2.5, 2.5, 24, 1, '2025-03-10 00:00:00+00', '2025-03-10 00:00:00+00'),
-- Préstamo 5: Completado (ejemplo histórico)
(5, 1000, NULL, 25000.00, 1.5, 0.0, 12, 4, '2024-12-07 00:00:00+00', '2024-12-07 00:00:00+00')
ON CONFLICT (id) DO NOTHING;

-- Aprobar préstamos (esto dispara generate_payment_schedule)
UPDATE loans SET status_id = 2, approved_at = '2025-01-07 00:00:00+00', approved_by = 2 WHERE id = 1;
UPDATE loans SET status_id = 2, approved_at = '2025-02-08 00:00:00+00', approved_by = 2 WHERE id = 2;
UPDATE loans SET status_id = 2, approved_at = '2025-02-23 00:00:00+00', approved_by = 2 WHERE id = 3;
UPDATE loans SET status_id = 2, approved_at = '2025-03-10 00:00:00+00', approved_by = 2 WHERE id = 4;

-- Contratos
INSERT INTO contracts (id, loan_id, start_date, document_number, status_id) VALUES
(1, 1, '2025-01-07', 'CONT-2025-001', 3),
(2, 2, '2025-02-08', 'CONT-2025-002', 3),
(3, 3, '2025-02-23', 'CONT-2025-003', 3),
(4, 4, '2025-03-10', 'CONT-2025-004', 3)
(3, 3, '2025-02-23', 'CONT-2025-003', 3),
(4, 4, '2024-12-07', 'CONT-2024-012', 5)
ON CONFLICT (id) DO NOTHING;

-- Actualizar contract_id en loans
UPDATE loans SET contract_id = 1 WHERE id = 1;
UPDATE loans SET contract_id = 2 WHERE id = 2;
UPDATE loans SET contract_id = 3 WHERE id = 3;
UPDATE loans SET contract_id = 4 WHERE id = 4;

-- =============================================================================
-- DATOS RELACIONADOS (Addresses, Guarantors, Beneficiaries)
-- =============================================================================
INSERT INTO addresses (user_id, street, external_number, internal_number, colony, municipality, state, zip_code) VALUES
(4, 'Av. Insurgentes Sur', '1234', 'Depto 501', 'Del Valle', 'Benito Juárez', 'Ciudad de México', '03100'),
(5, 'Calle Reforma', '567', NULL, 'Polanco', 'Miguel Hidalgo', 'Ciudad de México', '11560'),
(6, 'Av. Chapultepec', '890', 'Local 3', 'Roma Norte', 'Cuauhtémoc', 'Ciudad de México', '06700'),
(3, 'Calle Madero', '123', 'Piso 2', 'Centro Histórico', 'Cuauhtémoc', 'Ciudad de México', '06000')
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO guarantors (user_id, full_name, first_name, paternal_last_name, maternal_last_name, relationship, phone_number, curp) VALUES
(4, 'Carlos Alberto Vargas Hernández', 'Carlos Alberto', 'Vargas', 'Hernández', 'Padre', '5544556600', 'VAHC600101HDFVRR05'),
(5, 'Ana María Pérez Gómez', 'Ana María', 'Pérez', 'Gómez', 'Madre', '5555667700', 'PEGA650202MDFRMN06'),
(6, 'Jorge Luis Martínez Sánchez', 'Jorge Luis', 'Martínez', 'Sánchez', 'Hermano', '5566778800', 'MASJ880315HDFRRL07')
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO beneficiaries (user_id, full_name, relationship, phone_number) VALUES
(4, 'María Fernanda Vargas Torres', 'Hija', '5544556611'),
(5, 'Luis Alberto Pérez Cruz', 'Hijo', '5555667711'),
(6, 'Ana Laura Martínez López', 'Hija', '5566778811')
ON CONFLICT (user_id) DO NOTHING;

-- =============================================================================
-- PERÍODOS DE CORTE (8 períodos: 2024-2025)
-- =============================================================================
INSERT INTO cut_periods (id, cut_number, period_start_date, period_end_date, status_id, created_by) VALUES
-- 2024
(1, 23, '2024-12-08', '2024-12-22', 5, 2),
(2, 24, '2024-12-23', '2025-01-07', 5, 2),
-- 2025 
(3, 1, '2025-01-08', '2025-01-22', 5, 2),
(4, 2, '2025-01-23', '2025-02-07', 5, 2),
(5, 3, '2025-02-08', '2025-02-22', 5, 2),
(6, 4, '2025-02-23', '2025-03-07', 2, 2),
(7, 5, '2025-03-08', '2025-03-22', 2, 2),
(8, 6, '2025-03-23', '2025-04-07', 2, 2)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- CONFIGURACIONES DEL SISTEMA
-- =============================================================================
INSERT INTO system_configurations (config_key, config_value, description, config_type_id, updated_by) VALUES
('max_loan_amount', '1000000', 'Monto máximo de préstamo permitido', 2, 2),
('default_interest_rate', '2.5', 'Tasa de interés por defecto', 2, 2),
('default_commission_rate', '2.5', 'Tasa de comisión por defecto', 2, 2),
('system_name', 'Credinet', 'Nombre del sistema', 1, 2),
('maintenance_mode', 'false', 'Modo de mantenimiento', 3, 2),
('payment_system', 'BIWEEKLY_v2.0', 'Sistema de pagos quincenal v2.0', 1, 2),
('perfect_dates_enabled', 'true', 'Fechas perfectas (día 15 y último)', 3, 2),
('cut_days', '8,23', 'Días de corte exactos', 1, 2),
('payment_days', '15,LAST', 'Días de pago permitidos', 1, 2),
('db_version', '2.0.0', 'Versión de base de datos', 1, 2)
ON CONFLICT (config_key) DO NOTHING;

-- =============================================================================
-- AJUSTAR SECUENCIAS (Optimización FIX-008)
-- =============================================================================
SELECT setval('users_id_seq', COALESCE((SELECT MAX(id) FROM users), 0) + 1, false);
SELECT setval('roles_id_seq', COALESCE((SELECT MAX(id) FROM roles), 0) + 1, false);
SELECT setval('loans_id_seq', COALESCE((SELECT MAX(id) FROM loans), 0) + 1, false);
SELECT setval('contracts_id_seq', COALESCE((SELECT MAX(id) FROM contracts), 0) + 1, false);
SELECT setval('payments_id_seq', COALESCE((SELECT MAX(id) FROM payments), 0) + 1, false);
SELECT setval('cut_periods_id_seq', COALESCE((SELECT MAX(id) FROM cut_periods), 0) + 1, false);
SELECT setval('associate_profiles_id_seq', COALESCE((SELECT MAX(id) FROM associate_profiles), 0) + 1, false);
SELECT setval('client_documents_id_seq', COALESCE((SELECT MAX(id) FROM client_documents), 0) + 1, false);
SELECT setval('addresses_id_seq', COALESCE((SELECT MAX(id) FROM addresses), 0) + 1, false);
SELECT setval('guarantors_id_seq', COALESCE((SELECT MAX(id) FROM guarantors), 0) + 1, false);
SELECT setval('beneficiaries_id_seq', COALESCE((SELECT MAX(id) FROM beneficiaries), 0) + 1, false);

-- =============================================================================
-- FIN MÓDULO 09
-- =============================================================================
