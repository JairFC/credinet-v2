--
-- PostgreSQL database dump
--

\restrict 3uv63XtWOjwyhK8u9ekZlu7MbruoDONIbZk75ZGh3dVGKalx73dd3stG7mBN8b7

-- Dumped from database version 15.14
-- Dumped by pg_dump version 15.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: associate_levels; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.associate_levels VALUES (1, 'Bronce', 25000.00, 25000.00, NULL, 0, 0.00, '2025-10-31 01:12:22.074569+00', '2025-10-31 01:12:22.074569+00');
INSERT INTO public.associate_levels VALUES (2, 'Plata', 300000.00, 300000.00, NULL, 0, 0.00, '2025-10-31 01:12:22.074569+00', '2025-10-31 01:12:22.074569+00');
INSERT INTO public.associate_levels VALUES (3, 'Oro', 600000.00, 600000.00, NULL, 0, 0.00, '2025-10-31 01:12:22.074569+00', '2025-10-31 01:12:22.074569+00');
INSERT INTO public.associate_levels VALUES (4, 'Platino', 900000.00, 900000.00, NULL, 0, 0.00, '2025-10-31 01:12:22.074569+00', '2025-10-31 01:12:22.074569+00');
INSERT INTO public.associate_levels VALUES (5, 'Diamante', 5000000.00, 5000000.00, NULL, 0, 0.00, '2025-10-31 01:12:22.074569+00', '2025-10-31 01:12:22.074569+00');


--
-- Data for Name: config_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.config_types VALUES (1, 'STRING', 'Cadena de texto.', NULL, 'Hola Mundo', '2025-10-31 01:12:22.085589+00', '2025-10-31 01:12:22.085589+00');
INSERT INTO public.config_types VALUES (2, 'NUMBER', 'Número entero o decimal.', '^-?\d+(\.\d+)?$', '123.45', '2025-10-31 01:12:22.085589+00', '2025-10-31 01:12:22.085589+00');
INSERT INTO public.config_types VALUES (3, 'BOOLEAN', 'Valor booleano.', '^(true|false)$', 'true', '2025-10-31 01:12:22.085589+00', '2025-10-31 01:12:22.085589+00');
INSERT INTO public.config_types VALUES (4, 'JSON', 'Objeto JSON válido.', NULL, '{"key": "value"}', '2025-10-31 01:12:22.085589+00', '2025-10-31 01:12:22.085589+00');
INSERT INTO public.config_types VALUES (5, 'URL', 'URL válida.', '^https?://[^\s]+$', 'https://ejemplo.com', '2025-10-31 01:12:22.085589+00', '2025-10-31 01:12:22.085589+00');
INSERT INTO public.config_types VALUES (6, 'EMAIL', 'Correo electrónico.', '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', 'user@example.com', '2025-10-31 01:12:22.085589+00', '2025-10-31 01:12:22.085589+00');
INSERT INTO public.config_types VALUES (7, 'DATE', 'Fecha ISO 8601.', '^\d{4}-\d{2}-\d{2}$', '2025-10-30', '2025-10-31 01:12:22.085589+00', '2025-10-31 01:12:22.085589+00');
INSERT INTO public.config_types VALUES (8, 'PERCENTAGE', 'Porcentaje 0-100.', '^(100(\.0+)?|\d{1,2}(\.\d+)?)$', '15.5', '2025-10-31 01:12:22.085589+00', '2025-10-31 01:12:22.085589+00');


--
-- Data for Name: contract_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.contract_statuses VALUES (1, 'draft', 'Contrato en borrador.', true, false, 1, '2025-10-31 01:12:22.078957+00', '2025-10-31 01:12:22.078957+00');
INSERT INTO public.contract_statuses VALUES (2, 'pending', 'Pendiente de firma del cliente.', true, true, 2, '2025-10-31 01:12:22.078957+00', '2025-10-31 01:12:22.078957+00');
INSERT INTO public.contract_statuses VALUES (3, 'signed', 'Firmado por el cliente.', true, false, 3, '2025-10-31 01:12:22.078957+00', '2025-10-31 01:12:22.078957+00');
INSERT INTO public.contract_statuses VALUES (4, 'active', 'Contrato activo y vigente.', true, false, 4, '2025-10-31 01:12:22.078957+00', '2025-10-31 01:12:22.078957+00');
INSERT INTO public.contract_statuses VALUES (5, 'completed', 'Contrato completado, préstamo liquidado.', true, false, 5, '2025-10-31 01:12:22.078957+00', '2025-10-31 01:12:22.078957+00');
INSERT INTO public.contract_statuses VALUES (6, 'cancelled', 'Contrato cancelado.', true, false, 6, '2025-10-31 01:12:22.078957+00', '2025-10-31 01:12:22.078957+00');


--
-- Data for Name: cut_period_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.cut_period_statuses VALUES (1, 'PENDING', 'Período futuro con pagos pre-asignados de préstamos aprobados.', false, false, 1, '2025-10-31 01:12:22.080292+00', '2025-12-04 08:29:41.841541+00');
INSERT INTO public.cut_period_statuses VALUES (2, 'ACTIVE', 'DEPRECADO - No usar. Período actual del calendario.', false, false, 99, '2025-10-31 01:12:22.080292+00', '2025-12-04 08:29:41.841541+00');
INSERT INTO public.cut_period_statuses VALUES (3, 'CUTOFF', 'BORRADOR - Corte automático ejecutado. Statements en borrador para revisión del admin.', false, false, 2, '2025-10-31 01:12:22.080292+00', '2025-12-04 08:29:41.841541+00');
INSERT INTO public.cut_period_statuses VALUES (4, 'COLLECTING', 'EN COBRO - Cierre manual ejecutado. Statements finalizados, fase de cobro a asociados.', false, false, 3, '2025-10-31 01:12:22.080292+00', '2025-12-04 08:29:41.841541+00');
INSERT INTO public.cut_period_statuses VALUES (5, 'CLOSED', 'Período cerrado y archivado definitivamente. Solo lectura.', true, false, 5, '2025-10-31 01:12:22.080292+00', '2025-12-04 08:29:41.841541+00');
INSERT INTO public.cut_period_statuses VALUES (6, 'SETTLING', 'LIQUIDACIÓN - Período terminado, revisión de deuda pendiente antes del cierre definitivo.', false, false, 4, '2025-12-04 08:29:41.841541+00', '2025-12-04 08:29:41.841541+00');


--
-- Data for Name: document_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.document_statuses VALUES (1, 'PENDING', 'Documento cargado, pendiente de revisión.', 1, '#FFA500', '2025-10-31 01:12:22.083043+00', '2025-10-31 01:12:22.083043+00');
INSERT INTO public.document_statuses VALUES (2, 'UNDER_REVIEW', 'En proceso de revisión.', 2, '#2196F3', '2025-10-31 01:12:22.083043+00', '2025-10-31 01:12:22.083043+00');
INSERT INTO public.document_statuses VALUES (3, 'APPROVED', 'Documento aprobado.', 3, '#4CAF50', '2025-10-31 01:12:22.083043+00', '2025-10-31 01:12:22.083043+00');
INSERT INTO public.document_statuses VALUES (4, 'REJECTED', 'Documento rechazado.', 4, '#F44336', '2025-10-31 01:12:22.083043+00', '2025-10-31 01:12:22.083043+00');


--
-- Data for Name: document_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.document_types VALUES (1, 'Identificación Oficial', 'INE, Pasaporte o Cédula Profesional', true, '2025-10-31 01:12:22.088252+00', '2025-10-31 01:12:22.088252+00');
INSERT INTO public.document_types VALUES (2, 'Comprobante de Domicilio', 'Recibo de luz, agua o predial', true, '2025-10-31 01:12:22.088252+00', '2025-10-31 01:12:22.088252+00');
INSERT INTO public.document_types VALUES (3, 'Comprobante de Ingresos', 'Estado de cuenta o constancia laboral', true, '2025-10-31 01:12:22.088252+00', '2025-10-31 01:12:22.088252+00');
INSERT INTO public.document_types VALUES (4, 'CURP', 'Clave Única de Registro de Población', false, '2025-10-31 01:12:22.088252+00', '2025-10-31 01:12:22.088252+00');
INSERT INTO public.document_types VALUES (5, 'Referencia Personal', 'Datos de contacto de referencia', false, '2025-10-31 01:12:22.088252+00', '2025-10-31 01:12:22.088252+00');


--
-- Data for Name: level_change_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.level_change_types VALUES (1, 'PROMOTION', 'Promoción automática a nivel superior.', true, 1, '2025-10-31 01:12:22.086922+00', '2025-10-31 01:12:22.086922+00');
INSERT INTO public.level_change_types VALUES (2, 'DEMOTION', 'Descenso por incumplimiento.', true, 2, '2025-10-31 01:12:22.086922+00', '2025-10-31 01:12:22.086922+00');
INSERT INTO public.level_change_types VALUES (3, 'MANUAL', 'Cambio manual por admin.', false, 3, '2025-10-31 01:12:22.086922+00', '2025-10-31 01:12:22.086922+00');
INSERT INTO public.level_change_types VALUES (4, 'INITIAL', 'Nivel inicial al registrarse.', false, 4, '2025-10-31 01:12:22.086922+00', '2025-10-31 01:12:22.086922+00');
INSERT INTO public.level_change_types VALUES (5, 'REWARD', 'Promoción especial por logro.', false, 5, '2025-10-31 01:12:22.086922+00', '2025-10-31 01:12:22.086922+00');
INSERT INTO public.level_change_types VALUES (6, 'PENALTY', 'Descenso por sanción.', false, 6, '2025-10-31 01:12:22.086922+00', '2025-10-31 01:12:22.086922+00');


--
-- Data for Name: loan_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.loan_statuses VALUES (1, 'PENDING', 'Préstamo solicitado pero aún no aprobado ni desembolsado.', true, 1, '#FFA500', 'clock', '2025-10-31 01:12:22.075733+00', '2025-10-31 01:12:22.075733+00');
INSERT INTO public.loan_statuses VALUES (2, 'APPROVED', 'Préstamo aprobado, listo para desembolso y generación de cronograma.', true, 2, '#4CAF50', 'check-circle', '2025-10-31 01:12:22.075733+00', '2025-10-31 01:12:22.075733+00');
INSERT INTO public.loan_statuses VALUES (3, 'ACTIVE', 'Préstamo desembolsado y activo, con pagos en curso.', true, 3, '#2196F3', 'activity', '2025-10-31 01:12:22.075733+00', '2025-10-31 01:12:22.075733+00');
INSERT INTO public.loan_statuses VALUES (4, 'COMPLETED', 'Préstamo completamente liquidado.', true, 4, '#00C853', 'check-all', '2025-10-31 01:12:22.075733+00', '2025-10-31 01:12:22.075733+00');
INSERT INTO public.loan_statuses VALUES (5, 'PAID', 'Préstamo totalmente pagado (sinónimo de COMPLETED).', true, 5, '#00C853', 'check-all', '2025-10-31 01:12:22.075733+00', '2025-10-31 01:12:22.075733+00');
INSERT INTO public.loan_statuses VALUES (6, 'DEFAULTED', 'Préstamo en mora o incumplimiento.', true, 6, '#F44336', 'alert-triangle', '2025-10-31 01:12:22.075733+00', '2025-10-31 01:12:22.075733+00');
INSERT INTO public.loan_statuses VALUES (7, 'REJECTED', 'Solicitud rechazada por administrador.', true, 7, '#9E9E9E', 'x-circle', '2025-10-31 01:12:22.075733+00', '2025-10-31 01:12:22.075733+00');
INSERT INTO public.loan_statuses VALUES (8, 'CANCELLED', 'Préstamo cancelado antes de completarse.', true, 8, '#757575', 'slash', '2025-10-31 01:12:22.075733+00', '2025-10-31 01:12:22.075733+00');


--
-- Data for Name: payment_methods; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.payment_methods VALUES (1, 'CASH', 'Pago en efectivo.', true, false, 1, 'dollar-sign', '2025-10-31 01:12:22.081669+00', '2025-10-31 01:12:22.081669+00');
INSERT INTO public.payment_methods VALUES (2, 'TRANSFER', 'Transferencia bancaria.', true, true, 2, 'arrow-right-circle', '2025-10-31 01:12:22.081669+00', '2025-10-31 01:12:22.081669+00');
INSERT INTO public.payment_methods VALUES (3, 'CHECK', 'Cheque bancario.', true, true, 3, 'file-text', '2025-10-31 01:12:22.081669+00', '2025-10-31 01:12:22.081669+00');
INSERT INTO public.payment_methods VALUES (4, 'PAYROLL_DEDUCTION', 'Descuento de nómina.', true, false, 4, 'briefcase', '2025-10-31 01:12:22.081669+00', '2025-10-31 01:12:22.081669+00');
INSERT INTO public.payment_methods VALUES (5, 'CARD', 'Tarjeta débito/crédito.', true, true, 5, 'credit-card', '2025-10-31 01:12:22.081669+00', '2025-10-31 01:12:22.081669+00');
INSERT INTO public.payment_methods VALUES (6, 'DEPOSIT', 'Depósito bancario.', true, true, 6, 'inbox', '2025-10-31 01:12:22.081669+00', '2025-10-31 01:12:22.081669+00');
INSERT INTO public.payment_methods VALUES (7, 'OXXO', 'Pago en OXXO.', true, true, 7, 'shopping-bag', '2025-10-31 01:12:22.081669+00', '2025-10-31 01:12:22.081669+00');


--
-- Data for Name: payment_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.payment_statuses VALUES (1, 'PENDING', 'Pago programado, aún no vence.', true, 1, '#9E9E9E', 'clock', true, '2025-10-31 01:12:22.077324+00', '2025-10-31 01:12:22.077324+00');
INSERT INTO public.payment_statuses VALUES (2, 'DUE_TODAY', 'Pago vence hoy.', true, 2, '#FF9800', 'calendar', true, '2025-10-31 01:12:22.077324+00', '2025-10-31 01:12:22.077324+00');
INSERT INTO public.payment_statuses VALUES (4, 'OVERDUE', 'Pago vencido, no pagado.', true, 4, '#F44336', 'alert-circle', true, '2025-10-31 01:12:22.077324+00', '2025-10-31 01:12:22.077324+00');
INSERT INTO public.payment_statuses VALUES (5, 'PARTIAL', 'Pago parcial realizado.', true, 5, '#2196F3', 'pie-chart', true, '2025-10-31 01:12:22.077324+00', '2025-10-31 01:12:22.077324+00');
INSERT INTO public.payment_statuses VALUES (6, 'IN_COLLECTION', 'En proceso de cobranza.', true, 6, '#9C27B0', 'phone', true, '2025-10-31 01:12:22.077324+00', '2025-10-31 01:12:22.077324+00');
INSERT INTO public.payment_statuses VALUES (7, 'RESCHEDULED', 'Pago reprogramado.', true, 7, '#03A9F4', 'refresh-cw', true, '2025-10-31 01:12:22.077324+00', '2025-10-31 01:12:22.077324+00');
INSERT INTO public.payment_statuses VALUES (3, 'PAID', 'Pago completado por cliente.', true, 3, '#4CAF50', 'check', true, '2025-10-31 01:12:22.077324+00', '2025-10-31 01:12:22.077324+00');
INSERT INTO public.payment_statuses VALUES (8, 'PAID_PARTIAL', 'Pago parcial aceptado.', true, 8, '#8BC34A', 'check-circle', true, '2025-10-31 01:12:22.077324+00', '2025-10-31 01:12:22.077324+00');
INSERT INTO public.payment_statuses VALUES (9, 'PAID_BY_ASSOCIATE', 'Pagado por asociado (cliente moroso).', true, 9, '#FF5722', 'user-x', false, '2025-10-31 01:12:22.077324+00', '2025-10-31 01:12:22.077324+00');
INSERT INTO public.payment_statuses VALUES (10, 'PAID_NOT_REPORTED', 'Pago no reportado al cierre.', true, 10, '#FFC107', 'alert-triangle', false, '2025-10-31 01:12:22.077324+00', '2025-10-31 01:12:22.077324+00');
INSERT INTO public.payment_statuses VALUES (11, 'FORGIVEN', 'Pago perdonado por administración.', true, 11, '#00BCD4', 'heart', false, '2025-10-31 01:12:22.077324+00', '2025-10-31 01:12:22.077324+00');
INSERT INTO public.payment_statuses VALUES (12, 'CANCELLED', 'Pago cancelado.', true, 12, '#607D8B', 'x', false, '2025-10-31 01:12:22.077324+00', '2025-10-31 01:12:22.077324+00');


--
-- Data for Name: rate_profile_reference_table; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.rate_profile_reference_table VALUES (1, 'transition', 3000.00, 6, 612.50, 3675.00, 73.50, 441.00, 539.00, 3234.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (2, 'transition', 4000.00, 6, 816.67, 4900.00, 98.00, 588.00, 718.67, 4312.02, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (3, 'transition', 5000.00, 6, 1020.83, 6125.00, 122.50, 735.00, 898.33, 5389.98, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (4, 'transition', 6000.00, 6, 1225.00, 7350.00, 147.00, 882.00, 1078.00, 6468.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (5, 'transition', 7000.00, 6, 1429.17, 8575.00, 171.50, 1029.00, 1257.67, 7546.02, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (6, 'transition', 8000.00, 6, 1633.33, 9800.00, 196.00, 1176.00, 1437.33, 8623.98, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (7, 'transition', 9000.00, 6, 1837.50, 11025.00, 220.50, 1323.00, 1617.00, 9702.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (8, 'transition', 10000.00, 6, 2041.67, 12250.00, 245.00, 1470.00, 1796.67, 10780.02, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (9, 'transition', 12000.00, 6, 2450.00, 14700.00, 294.00, 1764.00, 2156.00, 12936.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (10, 'transition', 15000.00, 6, 3062.50, 18375.00, 367.50, 2205.00, 2695.00, 16170.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (11, 'transition', 18000.00, 6, 3675.00, 22050.00, 441.00, 2646.00, 3234.00, 19404.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (12, 'transition', 20000.00, 6, 4083.33, 24500.00, 490.00, 2940.00, 3593.33, 21559.98, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (13, 'transition', 25000.00, 6, 5104.17, 30625.00, 612.50, 3675.00, 4491.67, 26950.02, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (14, 'transition', 30000.00, 6, 6125.00, 36750.00, 735.00, 4410.00, 5390.00, 32340.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (15, 'transition', 3000.00, 12, 362.50, 4350.00, 43.50, 522.00, 319.00, 3828.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (16, 'transition', 4000.00, 12, 483.33, 5800.00, 58.00, 696.00, 425.33, 5103.96, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (17, 'transition', 5000.00, 12, 604.17, 7250.00, 72.50, 870.00, 531.67, 6380.04, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (18, 'transition', 6000.00, 12, 725.00, 8700.00, 87.00, 1044.00, 638.00, 7656.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (19, 'transition', 7000.00, 12, 845.83, 10150.00, 101.50, 1218.00, 744.33, 8931.96, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (20, 'transition', 8000.00, 12, 966.67, 11600.00, 116.00, 1392.00, 850.67, 10208.04, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (21, 'transition', 9000.00, 12, 1087.50, 13050.00, 130.50, 1566.00, 957.00, 11484.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (22, 'transition', 10000.00, 12, 1208.33, 14500.00, 145.00, 1740.00, 1063.33, 12759.96, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (23, 'transition', 12000.00, 12, 1450.00, 17400.00, 174.00, 2088.00, 1276.00, 15312.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (24, 'transition', 15000.00, 12, 1812.50, 21750.00, 217.50, 2610.00, 1595.00, 19140.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (25, 'transition', 18000.00, 12, 2175.00, 26100.00, 261.00, 3132.00, 1914.00, 22968.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (26, 'transition', 20000.00, 12, 2416.67, 29000.00, 290.00, 3480.00, 2126.67, 25520.04, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (27, 'transition', 25000.00, 12, 3020.83, 36250.00, 362.50, 4350.00, 2658.33, 31899.96, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (28, 'transition', 30000.00, 12, 3625.00, 43500.00, 435.00, 5220.00, 3190.00, 38280.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (29, 'transition', 3000.00, 18, 279.17, 5025.00, 33.50, 603.00, 245.67, 4422.06, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (30, 'transition', 4000.00, 18, 372.22, 6700.00, 44.67, 804.06, 327.55, 5895.90, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (31, 'transition', 5000.00, 18, 465.28, 8375.00, 55.83, 1004.94, 409.45, 7370.10, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (32, 'transition', 6000.00, 18, 558.33, 10050.00, 67.00, 1206.00, 491.33, 8843.94, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (33, 'transition', 7000.00, 18, 651.39, 11725.00, 78.17, 1407.06, 573.22, 10317.96, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (34, 'transition', 8000.00, 18, 744.44, 13400.00, 89.33, 1607.94, 655.11, 11791.98, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (35, 'transition', 9000.00, 18, 837.50, 15075.00, 100.50, 1809.00, 737.00, 13266.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (36, 'transition', 10000.00, 18, 930.56, 16750.00, 111.67, 2010.06, 818.89, 14740.02, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (37, 'transition', 12000.00, 18, 1116.67, 20100.00, 134.00, 2412.00, 982.67, 17688.06, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (38, 'transition', 15000.00, 18, 1395.83, 25125.00, 167.50, 3015.00, 1228.33, 22109.94, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (39, 'transition', 18000.00, 18, 1675.00, 30150.00, 201.00, 3618.00, 1474.00, 26532.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (40, 'transition', 20000.00, 18, 1861.11, 33500.00, 223.33, 4019.94, 1637.78, 29480.04, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (41, 'transition', 25000.00, 18, 2326.39, 41875.00, 279.17, 5025.06, 2047.22, 36849.96, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (42, 'transition', 30000.00, 18, 2791.67, 50250.00, 335.00, 6030.00, 2456.67, 44220.06, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (43, 'transition', 3000.00, 24, 237.50, 5700.00, 28.50, 684.00, 209.00, 5016.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (44, 'transition', 4000.00, 24, 316.67, 7600.00, 38.00, 912.00, 278.67, 6688.08, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (45, 'transition', 5000.00, 24, 395.83, 9500.00, 47.50, 1140.00, 348.33, 8359.92, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (46, 'transition', 6000.00, 24, 475.00, 11400.00, 57.00, 1368.00, 418.00, 10032.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (47, 'transition', 7000.00, 24, 554.17, 13300.00, 66.50, 1596.00, 487.67, 11704.08, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (48, 'transition', 8000.00, 24, 633.33, 15200.00, 76.00, 1824.00, 557.33, 13375.92, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (49, 'transition', 9000.00, 24, 712.50, 17100.00, 85.50, 2052.00, 627.00, 15048.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (50, 'transition', 10000.00, 24, 791.67, 19000.00, 95.00, 2280.00, 696.67, 16720.08, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (51, 'transition', 12000.00, 24, 950.00, 22800.00, 114.00, 2736.00, 836.00, 20064.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (52, 'transition', 15000.00, 24, 1187.50, 28500.00, 142.50, 3420.00, 1045.00, 25080.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (53, 'transition', 18000.00, 24, 1425.00, 34200.00, 171.00, 4104.00, 1254.00, 30096.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (54, 'transition', 20000.00, 24, 1583.33, 38000.00, 190.00, 4560.00, 1393.33, 33439.92, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (55, 'transition', 25000.00, 24, 1979.17, 47500.00, 237.50, 5700.00, 1741.67, 41800.08, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (56, 'transition', 30000.00, 24, 2375.00, 57000.00, 285.00, 6840.00, 2090.00, 50160.00, 3.750, 12.000, '2025-11-14 06:28:37.101355+00');
INSERT INTO public.rate_profile_reference_table VALUES (57, 'standard', 3000.00, 3, 1127.50, 3382.50, 135.30, 405.90, 992.20, 2976.60, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (58, 'standard', 4000.00, 3, 1503.33, 4510.00, 180.40, 541.20, 1322.93, 3968.79, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (59, 'standard', 5000.00, 3, 1879.17, 5637.50, 225.50, 676.50, 1653.67, 4961.01, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (60, 'standard', 6000.00, 3, 2255.00, 6765.00, 270.60, 811.80, 1984.40, 5953.20, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (61, 'standard', 7000.00, 3, 2630.83, 7892.50, 315.70, 947.10, 2315.13, 6945.39, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (62, 'standard', 8000.00, 3, 3006.67, 9020.00, 360.80, 1082.40, 2645.87, 7937.61, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (63, 'standard', 9000.00, 3, 3382.50, 10147.50, 405.90, 1217.70, 2976.60, 8929.80, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (64, 'standard', 10000.00, 3, 3758.33, 11275.00, 451.00, 1353.00, 3307.33, 9921.99, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (65, 'standard', 12000.00, 3, 4510.00, 13530.00, 541.20, 1623.60, 3968.80, 11906.40, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (66, 'standard', 15000.00, 3, 5637.50, 16912.50, 676.50, 2029.50, 4961.00, 14883.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (67, 'standard', 18000.00, 3, 6765.00, 20295.00, 811.80, 2435.40, 5953.20, 17859.60, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (68, 'standard', 20000.00, 3, 7516.67, 22550.00, 902.00, 2706.00, 6614.67, 19844.01, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (69, 'standard', 25000.00, 3, 9395.83, 28187.50, 1127.50, 3382.50, 8268.33, 24804.99, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (70, 'standard', 30000.00, 3, 11275.00, 33825.00, 1353.00, 4059.00, 9922.00, 29766.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (71, 'standard', 3000.00, 6, 627.50, 3765.00, 75.30, 451.80, 552.20, 3313.20, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (72, 'standard', 4000.00, 6, 836.67, 5020.00, 100.40, 602.40, 736.27, 4417.62, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (73, 'standard', 5000.00, 6, 1045.83, 6275.00, 125.50, 753.00, 920.33, 5521.98, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (74, 'standard', 6000.00, 6, 1255.00, 7530.00, 150.60, 903.60, 1104.40, 6626.40, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (75, 'standard', 7000.00, 6, 1464.17, 8785.00, 175.70, 1054.20, 1288.47, 7730.82, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (76, 'standard', 8000.00, 6, 1673.33, 10040.00, 200.80, 1204.80, 1472.53, 8835.18, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (77, 'standard', 9000.00, 6, 1882.50, 11295.00, 225.90, 1355.40, 1656.60, 9939.60, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (78, 'standard', 10000.00, 6, 2091.67, 12550.00, 251.00, 1506.00, 1840.67, 11044.02, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (79, 'standard', 12000.00, 6, 2510.00, 15060.00, 301.20, 1807.20, 2208.80, 13252.80, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (80, 'standard', 15000.00, 6, 3137.50, 18825.00, 376.50, 2259.00, 2761.00, 16566.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (81, 'standard', 18000.00, 6, 3765.00, 22590.00, 451.80, 2710.80, 3313.20, 19879.20, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (82, 'standard', 20000.00, 6, 4183.33, 25100.00, 502.00, 3012.00, 3681.33, 22087.98, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (83, 'standard', 25000.00, 6, 5229.17, 31375.00, 627.50, 3765.00, 4601.67, 27610.02, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (84, 'standard', 30000.00, 6, 6275.00, 37650.00, 753.00, 4518.00, 5522.00, 33132.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (85, 'standard', 3000.00, 9, 460.83, 4147.50, 55.30, 497.70, 405.53, 3649.77, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (86, 'standard', 4000.00, 9, 614.44, 5530.00, 73.73, 663.57, 540.71, 4866.39, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (87, 'standard', 5000.00, 9, 768.06, 6912.50, 92.17, 829.53, 675.89, 6083.01, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (88, 'standard', 6000.00, 9, 921.67, 8295.00, 110.60, 995.40, 811.07, 7299.63, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (89, 'standard', 7000.00, 9, 1075.28, 9677.50, 129.03, 1161.27, 946.25, 8516.25, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (90, 'standard', 8000.00, 9, 1228.89, 11060.00, 147.47, 1327.23, 1081.42, 9732.78, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (91, 'standard', 9000.00, 9, 1382.50, 12442.50, 165.90, 1493.10, 1216.60, 10949.40, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (92, 'standard', 10000.00, 9, 1536.11, 13825.00, 184.33, 1658.97, 1351.78, 12166.02, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (93, 'standard', 12000.00, 9, 1843.33, 16590.00, 221.20, 1990.80, 1622.13, 14599.17, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (94, 'standard', 15000.00, 9, 2304.17, 20737.50, 276.50, 2488.50, 2027.67, 18249.03, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (95, 'standard', 18000.00, 9, 2765.00, 24885.00, 331.80, 2986.20, 2433.20, 21898.80, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (96, 'standard', 20000.00, 9, 3072.22, 27650.00, 368.67, 3318.03, 2703.55, 24331.95, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (97, 'standard', 25000.00, 9, 3840.28, 34562.50, 460.83, 4147.47, 3379.45, 30415.05, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (98, 'standard', 30000.00, 9, 4608.33, 41475.00, 553.00, 4977.00, 4055.33, 36497.97, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (99, 'standard', 3000.00, 12, 377.50, 4530.00, 45.30, 543.60, 332.20, 3986.40, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (100, 'standard', 4000.00, 12, 503.33, 6040.00, 60.40, 724.80, 442.93, 5315.16, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (101, 'standard', 5000.00, 12, 629.17, 7550.00, 75.50, 906.00, 553.67, 6644.04, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (102, 'standard', 6000.00, 12, 755.00, 9060.00, 90.60, 1087.20, 664.40, 7972.80, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (103, 'standard', 7000.00, 12, 880.83, 10570.00, 105.70, 1268.40, 775.13, 9301.56, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (104, 'standard', 8000.00, 12, 1006.67, 12080.00, 120.80, 1449.60, 885.87, 10630.44, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (105, 'standard', 9000.00, 12, 1132.50, 13590.00, 135.90, 1630.80, 996.60, 11959.20, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (106, 'standard', 10000.00, 12, 1258.33, 15100.00, 151.00, 1812.00, 1107.33, 13287.96, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (107, 'standard', 12000.00, 12, 1510.00, 18120.00, 181.20, 2174.40, 1328.80, 15945.60, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (108, 'standard', 15000.00, 12, 1887.50, 22650.00, 226.50, 2718.00, 1661.00, 19932.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (109, 'standard', 18000.00, 12, 2265.00, 27180.00, 271.80, 3261.60, 1993.20, 23918.40, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (110, 'standard', 20000.00, 12, 2516.67, 30200.00, 302.00, 3624.00, 2214.67, 26576.04, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (111, 'standard', 25000.00, 12, 3145.83, 37750.00, 377.50, 4530.00, 2768.33, 33219.96, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (112, 'standard', 30000.00, 12, 3775.00, 45300.00, 453.00, 5436.00, 3322.00, 39864.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (113, 'standard', 3000.00, 15, 327.50, 4912.50, 39.30, 589.50, 288.20, 4323.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (114, 'standard', 4000.00, 15, 436.67, 6550.00, 52.40, 786.00, 384.27, 5764.05, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (115, 'standard', 5000.00, 15, 545.83, 8187.50, 65.50, 982.50, 480.33, 7204.95, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (116, 'standard', 6000.00, 15, 655.00, 9825.00, 78.60, 1179.00, 576.40, 8646.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (117, 'standard', 7000.00, 15, 764.17, 11462.50, 91.70, 1375.50, 672.47, 10087.05, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (118, 'standard', 8000.00, 15, 873.33, 13100.00, 104.80, 1572.00, 768.53, 11527.95, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (119, 'standard', 9000.00, 15, 982.50, 14737.50, 117.90, 1768.50, 864.60, 12969.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (120, 'standard', 10000.00, 15, 1091.67, 16375.00, 131.00, 1965.00, 960.67, 14410.05, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (121, 'standard', 12000.00, 15, 1310.00, 19650.00, 157.20, 2358.00, 1152.80, 17292.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (122, 'standard', 15000.00, 15, 1637.50, 24562.50, 196.50, 2947.50, 1441.00, 21615.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (123, 'standard', 18000.00, 15, 1965.00, 29475.00, 235.80, 3537.00, 1729.20, 25938.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (124, 'standard', 20000.00, 15, 2183.33, 32750.00, 262.00, 3930.00, 1921.33, 28819.95, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (125, 'standard', 25000.00, 15, 2729.17, 40937.50, 327.50, 4912.50, 2401.67, 36025.05, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (126, 'standard', 30000.00, 15, 3275.00, 49125.00, 393.00, 5895.00, 2882.00, 43230.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (127, 'standard', 3000.00, 18, 294.17, 5295.00, 35.30, 635.40, 258.87, 4659.66, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (128, 'standard', 4000.00, 18, 392.22, 7060.00, 47.07, 847.26, 345.15, 6212.70, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (129, 'standard', 5000.00, 18, 490.28, 8825.00, 58.83, 1058.94, 431.45, 7766.10, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (130, 'standard', 6000.00, 18, 588.33, 10590.00, 70.60, 1270.80, 517.73, 9319.14, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (131, 'standard', 7000.00, 18, 686.39, 12355.00, 82.37, 1482.66, 604.02, 10872.36, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (132, 'standard', 8000.00, 18, 784.44, 14120.00, 94.13, 1694.34, 690.31, 12425.58, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (133, 'standard', 9000.00, 18, 882.50, 15885.00, 105.90, 1906.20, 776.60, 13978.80, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (134, 'standard', 10000.00, 18, 980.56, 17650.00, 117.67, 2118.06, 862.89, 15532.02, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (135, 'standard', 12000.00, 18, 1176.67, 21180.00, 141.20, 2541.60, 1035.47, 18638.46, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (136, 'standard', 15000.00, 18, 1470.83, 26475.00, 176.50, 3177.00, 1294.33, 23297.94, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (137, 'standard', 18000.00, 18, 1765.00, 31770.00, 211.80, 3812.40, 1553.20, 27957.60, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (138, 'standard', 20000.00, 18, 1961.11, 35300.00, 235.33, 4235.94, 1725.78, 31064.04, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (139, 'standard', 25000.00, 18, 2451.39, 44125.00, 294.17, 5295.06, 2157.22, 38829.96, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (140, 'standard', 30000.00, 18, 2941.67, 52950.00, 353.00, 6354.00, 2588.67, 46596.06, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (141, 'standard', 3000.00, 21, 270.36, 5677.50, 32.44, 681.24, 237.92, 4996.32, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (142, 'standard', 4000.00, 21, 360.48, 7570.00, 43.26, 908.46, 317.22, 6661.62, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (143, 'standard', 5000.00, 21, 450.60, 9462.50, 54.07, 1135.47, 396.53, 8327.13, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (144, 'standard', 6000.00, 21, 540.71, 11355.00, 64.89, 1362.69, 475.82, 9992.22, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (145, 'standard', 7000.00, 21, 630.83, 13247.50, 75.70, 1589.70, 555.13, 11657.73, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (146, 'standard', 8000.00, 21, 720.95, 15140.00, 86.51, 1816.71, 634.44, 13323.24, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (147, 'standard', 9000.00, 21, 811.07, 17032.50, 97.33, 2043.93, 713.74, 14988.54, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (148, 'standard', 10000.00, 21, 901.19, 18925.00, 108.14, 2270.94, 793.05, 16654.05, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (149, 'standard', 12000.00, 21, 1081.43, 22710.00, 129.77, 2725.17, 951.66, 19984.86, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (150, 'standard', 15000.00, 21, 1351.79, 28387.50, 162.21, 3406.41, 1189.58, 24981.18, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (151, 'standard', 18000.00, 21, 1622.14, 34065.00, 194.66, 4087.86, 1427.48, 29977.08, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (152, 'standard', 20000.00, 21, 1802.38, 37850.00, 216.29, 4542.09, 1586.09, 33307.89, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (153, 'standard', 25000.00, 21, 2252.98, 47312.50, 270.36, 5677.56, 1982.62, 41635.02, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (154, 'standard', 30000.00, 21, 2703.57, 56775.00, 324.43, 6813.03, 2379.14, 49961.94, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (155, 'standard', 3000.00, 24, 252.50, 6060.00, 30.30, 727.20, 222.20, 5332.80, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (156, 'standard', 4000.00, 24, 336.67, 8080.00, 40.40, 969.60, 296.27, 7110.48, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (157, 'standard', 5000.00, 24, 420.83, 10100.00, 50.50, 1212.00, 370.33, 8887.92, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (158, 'standard', 6000.00, 24, 505.00, 12120.00, 60.60, 1454.40, 444.40, 10665.60, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (159, 'standard', 7000.00, 24, 589.17, 14140.00, 70.70, 1696.80, 518.47, 12443.28, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (160, 'standard', 8000.00, 24, 673.33, 16160.00, 80.80, 1939.20, 592.53, 14220.72, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (161, 'standard', 9000.00, 24, 757.50, 18180.00, 90.90, 2181.60, 666.60, 15998.40, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (162, 'standard', 10000.00, 24, 841.67, 20200.00, 101.00, 2424.00, 740.67, 17776.08, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (163, 'standard', 12000.00, 24, 1010.00, 24240.00, 121.20, 2908.80, 888.80, 21331.20, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (164, 'standard', 15000.00, 24, 1262.50, 30300.00, 151.50, 3636.00, 1111.00, 26664.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (165, 'standard', 18000.00, 24, 1515.00, 36360.00, 181.80, 4363.20, 1333.20, 31996.80, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (166, 'standard', 20000.00, 24, 1683.33, 40400.00, 202.00, 4848.00, 1481.33, 35551.92, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (167, 'standard', 25000.00, 24, 2104.17, 50500.00, 252.50, 6060.00, 1851.67, 44440.08, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (168, 'standard', 30000.00, 24, 2525.00, 60600.00, 303.00, 7272.00, 2222.00, 53328.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (169, 'standard', 3000.00, 30, 227.50, 6825.00, 27.30, 819.00, 200.20, 6006.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (170, 'standard', 4000.00, 30, 303.33, 9100.00, 36.40, 1092.00, 266.93, 8007.90, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (171, 'standard', 5000.00, 30, 379.17, 11375.00, 45.50, 1365.00, 333.67, 10010.10, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (172, 'standard', 6000.00, 30, 455.00, 13650.00, 54.60, 1638.00, 400.40, 12012.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (173, 'standard', 7000.00, 30, 530.83, 15925.00, 63.70, 1911.00, 467.13, 14013.90, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (174, 'standard', 8000.00, 30, 606.67, 18200.00, 72.80, 2184.00, 533.87, 16016.10, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (175, 'standard', 9000.00, 30, 682.50, 20475.00, 81.90, 2457.00, 600.60, 18018.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (176, 'standard', 10000.00, 30, 758.33, 22750.00, 91.00, 2730.00, 667.33, 20019.90, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (177, 'standard', 12000.00, 30, 910.00, 27300.00, 109.20, 3276.00, 800.80, 24024.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (178, 'standard', 15000.00, 30, 1137.50, 34125.00, 136.50, 4095.00, 1001.00, 30030.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (179, 'standard', 18000.00, 30, 1365.00, 40950.00, 163.80, 4914.00, 1201.20, 36036.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (180, 'standard', 20000.00, 30, 1516.67, 45500.00, 182.00, 5460.00, 1334.67, 40040.10, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (181, 'standard', 25000.00, 30, 1895.83, 56875.00, 227.50, 6825.00, 1668.33, 50049.90, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (182, 'standard', 30000.00, 30, 2275.00, 68250.00, 273.00, 8190.00, 2002.00, 60060.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (183, 'standard', 3000.00, 36, 210.83, 7590.00, 25.30, 910.80, 185.53, 6679.08, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (184, 'standard', 4000.00, 36, 281.11, 10120.00, 33.73, 1214.28, 247.38, 8905.68, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (185, 'standard', 5000.00, 36, 351.39, 12650.00, 42.17, 1518.12, 309.22, 11131.92, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (186, 'standard', 6000.00, 36, 421.67, 15180.00, 50.60, 1821.60, 371.07, 13358.52, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (187, 'standard', 7000.00, 36, 491.94, 17710.00, 59.03, 2125.08, 432.91, 15584.76, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (188, 'standard', 8000.00, 36, 562.22, 20240.00, 67.47, 2428.92, 494.75, 17811.00, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (189, 'standard', 9000.00, 36, 632.50, 22770.00, 75.90, 2732.40, 556.60, 20037.60, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (190, 'standard', 10000.00, 36, 702.78, 25300.00, 84.33, 3035.88, 618.45, 22264.20, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (191, 'standard', 12000.00, 36, 843.33, 30360.00, 101.20, 3643.20, 742.13, 26716.68, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (192, 'standard', 15000.00, 36, 1054.17, 37950.00, 126.50, 4554.00, 927.67, 33396.12, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (193, 'standard', 18000.00, 36, 1265.00, 45540.00, 151.80, 5464.80, 1113.20, 40075.20, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (194, 'standard', 20000.00, 36, 1405.56, 50600.00, 168.67, 6072.12, 1236.89, 44528.04, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (195, 'standard', 25000.00, 36, 1756.94, 63250.00, 210.83, 7589.88, 1546.11, 55659.96, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (196, 'standard', 30000.00, 36, 2108.33, 75900.00, 253.00, 9108.00, 1855.33, 66791.88, 4.250, 12.000, '2025-11-14 06:28:43.931117+00');
INSERT INTO public.rate_profile_reference_table VALUES (197, 'premium', 3000.00, 3, 1135.00, 3405.00, 136.20, 408.60, 998.80, 2996.40, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (198, 'premium', 4000.00, 3, 1513.33, 4540.00, 181.60, 544.80, 1331.73, 3995.19, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (199, 'premium', 5000.00, 3, 1891.67, 5675.00, 227.00, 681.00, 1664.67, 4994.01, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (200, 'premium', 6000.00, 3, 2270.00, 6810.00, 272.40, 817.20, 1997.60, 5992.80, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (201, 'premium', 7000.00, 3, 2648.33, 7945.00, 317.80, 953.40, 2330.53, 6991.59, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (202, 'premium', 8000.00, 3, 3026.67, 9080.00, 363.20, 1089.60, 2663.47, 7990.41, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (203, 'premium', 9000.00, 3, 3405.00, 10215.00, 408.60, 1225.80, 2996.40, 8989.20, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (204, 'premium', 10000.00, 3, 3783.33, 11350.00, 454.00, 1362.00, 3329.33, 9987.99, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (205, 'premium', 12000.00, 3, 4540.00, 13620.00, 544.80, 1634.40, 3995.20, 11985.60, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (206, 'premium', 15000.00, 3, 5675.00, 17025.00, 681.00, 2043.00, 4994.00, 14982.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (207, 'premium', 18000.00, 3, 6810.00, 20430.00, 817.20, 2451.60, 5992.80, 17978.40, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (208, 'premium', 20000.00, 3, 7566.67, 22700.00, 908.00, 2724.00, 6658.67, 19976.01, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (209, 'premium', 25000.00, 3, 9458.33, 28375.00, 1135.00, 3405.00, 8323.33, 24969.99, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (210, 'premium', 30000.00, 3, 11350.00, 34050.00, 1362.00, 4086.00, 9988.00, 29964.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (211, 'premium', 3000.00, 6, 635.00, 3810.00, 76.20, 457.20, 558.80, 3352.80, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (212, 'premium', 4000.00, 6, 846.67, 5080.00, 101.60, 609.60, 745.07, 4470.42, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (213, 'premium', 5000.00, 6, 1058.33, 6350.00, 127.00, 762.00, 931.33, 5587.98, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (214, 'premium', 6000.00, 6, 1270.00, 7620.00, 152.40, 914.40, 1117.60, 6705.60, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (215, 'premium', 7000.00, 6, 1481.67, 8890.00, 177.80, 1066.80, 1303.87, 7823.22, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (216, 'premium', 8000.00, 6, 1693.33, 10160.00, 203.20, 1219.20, 1490.13, 8940.78, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (217, 'premium', 9000.00, 6, 1905.00, 11430.00, 228.60, 1371.60, 1676.40, 10058.40, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (218, 'premium', 10000.00, 6, 2116.67, 12700.00, 254.00, 1524.00, 1862.67, 11176.02, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (219, 'premium', 12000.00, 6, 2540.00, 15240.00, 304.80, 1828.80, 2235.20, 13411.20, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (220, 'premium', 15000.00, 6, 3175.00, 19050.00, 381.00, 2286.00, 2794.00, 16764.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (221, 'premium', 18000.00, 6, 3810.00, 22860.00, 457.20, 2743.20, 3352.80, 20116.80, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (222, 'premium', 20000.00, 6, 4233.33, 25400.00, 508.00, 3048.00, 3725.33, 22351.98, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (223, 'premium', 25000.00, 6, 5291.67, 31750.00, 635.00, 3810.00, 4656.67, 27940.02, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (224, 'premium', 30000.00, 6, 6350.00, 38100.00, 762.00, 4572.00, 5588.00, 33528.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (225, 'premium', 3000.00, 9, 468.33, 4215.00, 56.20, 505.80, 412.13, 3709.17, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (226, 'premium', 4000.00, 9, 624.44, 5620.00, 74.93, 674.37, 549.51, 4945.59, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (227, 'premium', 5000.00, 9, 780.56, 7025.00, 93.67, 843.03, 686.89, 6182.01, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (228, 'premium', 6000.00, 9, 936.67, 8430.00, 112.40, 1011.60, 824.27, 7418.43, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (229, 'premium', 7000.00, 9, 1092.78, 9835.00, 131.13, 1180.17, 961.65, 8654.85, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (230, 'premium', 8000.00, 9, 1248.89, 11240.00, 149.87, 1348.83, 1099.02, 9891.18, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (231, 'premium', 9000.00, 9, 1405.00, 12645.00, 168.60, 1517.40, 1236.40, 11127.60, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (232, 'premium', 10000.00, 9, 1561.11, 14050.00, 187.33, 1685.97, 1373.78, 12364.02, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (233, 'premium', 12000.00, 9, 1873.33, 16860.00, 224.80, 2023.20, 1648.53, 14836.77, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (234, 'premium', 15000.00, 9, 2341.67, 21075.00, 281.00, 2529.00, 2060.67, 18546.03, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (235, 'premium', 18000.00, 9, 2810.00, 25290.00, 337.20, 3034.80, 2472.80, 22255.20, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (236, 'premium', 20000.00, 9, 3122.22, 28100.00, 374.67, 3372.03, 2747.55, 24727.95, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (237, 'premium', 25000.00, 9, 3902.78, 35125.00, 468.33, 4214.97, 3434.45, 30910.05, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (238, 'premium', 30000.00, 9, 4683.33, 42150.00, 562.00, 5058.00, 4121.33, 37091.97, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (239, 'premium', 3000.00, 12, 385.00, 4620.00, 46.20, 554.40, 338.80, 4065.60, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (240, 'premium', 4000.00, 12, 513.33, 6160.00, 61.60, 739.20, 451.73, 5420.76, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (241, 'premium', 5000.00, 12, 641.67, 7700.00, 77.00, 924.00, 564.67, 6776.04, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (242, 'premium', 6000.00, 12, 770.00, 9240.00, 92.40, 1108.80, 677.60, 8131.20, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (243, 'premium', 7000.00, 12, 898.33, 10780.00, 107.80, 1293.60, 790.53, 9486.36, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (244, 'premium', 8000.00, 12, 1026.67, 12320.00, 123.20, 1478.40, 903.47, 10841.64, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (245, 'premium', 9000.00, 12, 1155.00, 13860.00, 138.60, 1663.20, 1016.40, 12196.80, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (246, 'premium', 10000.00, 12, 1283.33, 15400.00, 154.00, 1848.00, 1129.33, 13551.96, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (247, 'premium', 12000.00, 12, 1540.00, 18480.00, 184.80, 2217.60, 1355.20, 16262.40, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (248, 'premium', 15000.00, 12, 1925.00, 23100.00, 231.00, 2772.00, 1694.00, 20328.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (249, 'premium', 18000.00, 12, 2310.00, 27720.00, 277.20, 3326.40, 2032.80, 24393.60, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (250, 'premium', 20000.00, 12, 2566.67, 30800.00, 308.00, 3696.00, 2258.67, 27104.04, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (251, 'premium', 25000.00, 12, 3208.33, 38500.00, 385.00, 4620.00, 2823.33, 33879.96, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (252, 'premium', 30000.00, 12, 3850.00, 46200.00, 462.00, 5544.00, 3388.00, 40656.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (253, 'premium', 3000.00, 15, 335.00, 5025.00, 40.20, 603.00, 294.80, 4422.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (254, 'premium', 4000.00, 15, 446.67, 6700.00, 53.60, 804.00, 393.07, 5896.05, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (255, 'premium', 5000.00, 15, 558.33, 8375.00, 67.00, 1005.00, 491.33, 7369.95, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (256, 'premium', 6000.00, 15, 670.00, 10050.00, 80.40, 1206.00, 589.60, 8844.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (257, 'premium', 7000.00, 15, 781.67, 11725.00, 93.80, 1407.00, 687.87, 10318.05, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (258, 'premium', 8000.00, 15, 893.33, 13400.00, 107.20, 1608.00, 786.13, 11791.95, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (259, 'premium', 9000.00, 15, 1005.00, 15075.00, 120.60, 1809.00, 884.40, 13266.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (260, 'premium', 10000.00, 15, 1116.67, 16750.00, 134.00, 2010.00, 982.67, 14740.05, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (261, 'premium', 12000.00, 15, 1340.00, 20100.00, 160.80, 2412.00, 1179.20, 17688.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (262, 'premium', 15000.00, 15, 1675.00, 25125.00, 201.00, 3015.00, 1474.00, 22110.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (263, 'premium', 18000.00, 15, 2010.00, 30150.00, 241.20, 3618.00, 1768.80, 26532.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (264, 'premium', 20000.00, 15, 2233.33, 33500.00, 268.00, 4020.00, 1965.33, 29479.95, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (265, 'premium', 25000.00, 15, 2791.67, 41875.00, 335.00, 5025.00, 2456.67, 36850.05, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (266, 'premium', 30000.00, 15, 3350.00, 50250.00, 402.00, 6030.00, 2948.00, 44220.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (267, 'premium', 3000.00, 18, 301.67, 5430.00, 36.20, 651.60, 265.47, 4778.46, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (268, 'premium', 4000.00, 18, 402.22, 7240.00, 48.27, 868.86, 353.95, 6371.10, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (269, 'premium', 5000.00, 18, 502.78, 9050.00, 60.33, 1085.94, 442.45, 7964.10, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (270, 'premium', 6000.00, 18, 603.33, 10860.00, 72.40, 1303.20, 530.93, 9556.74, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (271, 'premium', 7000.00, 18, 703.89, 12670.00, 84.47, 1520.46, 619.42, 11149.56, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (272, 'premium', 8000.00, 18, 804.44, 14480.00, 96.53, 1737.54, 707.91, 12742.38, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (273, 'premium', 9000.00, 18, 905.00, 16290.00, 108.60, 1954.80, 796.40, 14335.20, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (274, 'premium', 10000.00, 18, 1005.56, 18100.00, 120.67, 2172.06, 884.89, 15928.02, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (275, 'premium', 12000.00, 18, 1206.67, 21720.00, 144.80, 2606.40, 1061.87, 19113.66, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (276, 'premium', 15000.00, 18, 1508.33, 27150.00, 181.00, 3258.00, 1327.33, 23891.94, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (277, 'premium', 18000.00, 18, 1810.00, 32580.00, 217.20, 3909.60, 1592.80, 28670.40, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (278, 'premium', 20000.00, 18, 2011.11, 36200.00, 241.33, 4343.94, 1769.78, 31856.04, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (279, 'premium', 25000.00, 18, 2513.89, 45250.00, 301.67, 5430.06, 2212.22, 39819.96, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (280, 'premium', 30000.00, 18, 3016.67, 54300.00, 362.00, 6516.00, 2654.67, 47784.06, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (281, 'premium', 3000.00, 21, 277.86, 5835.00, 33.34, 700.14, 244.52, 5134.92, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (282, 'premium', 4000.00, 21, 370.48, 7780.00, 44.46, 933.66, 326.02, 6846.42, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (283, 'premium', 5000.00, 21, 463.10, 9725.00, 55.57, 1166.97, 407.53, 8558.13, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (284, 'premium', 6000.00, 21, 555.71, 11670.00, 66.69, 1400.49, 489.02, 10269.42, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (285, 'premium', 7000.00, 21, 648.33, 13615.00, 77.80, 1633.80, 570.53, 11981.13, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (286, 'premium', 8000.00, 21, 740.95, 15560.00, 88.91, 1867.11, 652.04, 13692.84, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (287, 'premium', 9000.00, 21, 833.57, 17505.00, 100.03, 2100.63, 733.54, 15404.34, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (288, 'premium', 10000.00, 21, 926.19, 19450.00, 111.14, 2333.94, 815.05, 17116.05, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (289, 'premium', 12000.00, 21, 1111.43, 23340.00, 133.37, 2800.77, 978.06, 20539.26, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (290, 'premium', 15000.00, 21, 1389.29, 29175.00, 166.71, 3500.91, 1222.58, 25674.18, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (291, 'premium', 18000.00, 21, 1667.14, 35010.00, 200.06, 4201.26, 1467.08, 30808.68, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (292, 'premium', 20000.00, 21, 1852.38, 38900.00, 222.29, 4668.09, 1630.09, 34231.89, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (293, 'premium', 25000.00, 21, 2315.48, 48625.00, 277.86, 5835.06, 2037.62, 42790.02, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (294, 'premium', 30000.00, 21, 2778.57, 58350.00, 333.43, 7002.03, 2445.14, 51347.94, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (295, 'premium', 3000.00, 24, 260.00, 6240.00, 31.20, 748.80, 228.80, 5491.20, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (296, 'premium', 4000.00, 24, 346.67, 8320.00, 41.60, 998.40, 305.07, 7321.68, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (297, 'premium', 5000.00, 24, 433.33, 10400.00, 52.00, 1248.00, 381.33, 9151.92, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (298, 'premium', 6000.00, 24, 520.00, 12480.00, 62.40, 1497.60, 457.60, 10982.40, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (299, 'premium', 7000.00, 24, 606.67, 14560.00, 72.80, 1747.20, 533.87, 12812.88, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (300, 'premium', 8000.00, 24, 693.33, 16640.00, 83.20, 1996.80, 610.13, 14643.12, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (301, 'premium', 9000.00, 24, 780.00, 18720.00, 93.60, 2246.40, 686.40, 16473.60, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (302, 'premium', 10000.00, 24, 866.67, 20800.00, 104.00, 2496.00, 762.67, 18304.08, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (303, 'premium', 12000.00, 24, 1040.00, 24960.00, 124.80, 2995.20, 915.20, 21964.80, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (304, 'premium', 15000.00, 24, 1300.00, 31200.00, 156.00, 3744.00, 1144.00, 27456.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (305, 'premium', 18000.00, 24, 1560.00, 37440.00, 187.20, 4492.80, 1372.80, 32947.20, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (306, 'premium', 20000.00, 24, 1733.33, 41600.00, 208.00, 4992.00, 1525.33, 36607.92, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (307, 'premium', 25000.00, 24, 2166.67, 52000.00, 260.00, 6240.00, 1906.67, 45760.08, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (308, 'premium', 30000.00, 24, 2600.00, 62400.00, 312.00, 7488.00, 2288.00, 54912.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (309, 'premium', 3000.00, 30, 235.00, 7050.00, 28.20, 846.00, 206.80, 6204.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (310, 'premium', 4000.00, 30, 313.33, 9400.00, 37.60, 1128.00, 275.73, 8271.90, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (311, 'premium', 5000.00, 30, 391.67, 11750.00, 47.00, 1410.00, 344.67, 10340.10, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (312, 'premium', 6000.00, 30, 470.00, 14100.00, 56.40, 1692.00, 413.60, 12408.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (313, 'premium', 7000.00, 30, 548.33, 16450.00, 65.80, 1974.00, 482.53, 14475.90, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (314, 'premium', 8000.00, 30, 626.67, 18800.00, 75.20, 2256.00, 551.47, 16544.10, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (315, 'premium', 9000.00, 30, 705.00, 21150.00, 84.60, 2538.00, 620.40, 18612.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (316, 'premium', 10000.00, 30, 783.33, 23500.00, 94.00, 2820.00, 689.33, 20679.90, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (317, 'premium', 12000.00, 30, 940.00, 28200.00, 112.80, 3384.00, 827.20, 24816.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (318, 'premium', 15000.00, 30, 1175.00, 35250.00, 141.00, 4230.00, 1034.00, 31020.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (319, 'premium', 18000.00, 30, 1410.00, 42300.00, 169.20, 5076.00, 1240.80, 37224.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (320, 'premium', 20000.00, 30, 1566.67, 47000.00, 188.00, 5640.00, 1378.67, 41360.10, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (321, 'premium', 25000.00, 30, 1958.33, 58750.00, 235.00, 7050.00, 1723.33, 51699.90, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (322, 'premium', 30000.00, 30, 2350.00, 70500.00, 282.00, 8460.00, 2068.00, 62040.00, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (323, 'premium', 3000.00, 36, 218.33, 7860.00, 26.20, 943.20, 192.13, 6916.68, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (324, 'premium', 4000.00, 36, 291.11, 10480.00, 34.93, 1257.48, 256.18, 9222.48, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (325, 'premium', 5000.00, 36, 363.89, 13100.00, 43.67, 1572.12, 320.22, 11527.92, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (326, 'premium', 6000.00, 36, 436.67, 15720.00, 52.40, 1886.40, 384.27, 13833.72, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (327, 'premium', 7000.00, 36, 509.44, 18340.00, 61.13, 2200.68, 448.31, 16139.16, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (328, 'premium', 8000.00, 36, 582.22, 20960.00, 69.87, 2515.32, 512.35, 18444.60, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (329, 'premium', 9000.00, 36, 655.00, 23580.00, 78.60, 2829.60, 576.40, 20750.40, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (330, 'premium', 10000.00, 36, 727.78, 26200.00, 87.33, 3143.88, 640.45, 23056.20, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (331, 'premium', 12000.00, 36, 873.33, 31440.00, 104.80, 3772.80, 768.53, 27667.08, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (332, 'premium', 15000.00, 36, 1091.67, 39300.00, 131.00, 4716.00, 960.67, 34584.12, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (333, 'premium', 18000.00, 36, 1310.00, 47160.00, 157.20, 5659.20, 1152.80, 41500.80, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (334, 'premium', 20000.00, 36, 1455.56, 52400.00, 174.67, 6288.12, 1280.89, 46112.04, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (335, 'premium', 25000.00, 36, 1819.44, 65500.00, 218.33, 7859.88, 1601.11, 57639.96, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (336, 'premium', 30000.00, 36, 2183.33, 78600.00, 262.00, 9432.00, 1921.33, 69167.88, 4.500, 12.000, '2025-11-14 06:28:50.754992+00');
INSERT INTO public.rate_profile_reference_table VALUES (345, 'standard', 22000.00, 3, 8268.33, 24805.00, 992.20, 2976.60, 7276.13, 21828.39, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (347, 'standard', 27000.00, 3, 10147.50, 30442.50, 1217.70, 3653.10, 8929.80, 26789.40, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (357, 'standard', 22000.00, 6, 4601.67, 27610.00, 552.20, 3313.20, 4049.47, 24296.82, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (359, 'standard', 27000.00, 6, 5647.50, 33885.00, 677.70, 4066.20, 4969.80, 29818.80, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (369, 'standard', 22000.00, 9, 3379.44, 30415.00, 405.53, 3649.77, 2973.91, 26765.19, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (371, 'standard', 27000.00, 9, 4147.50, 37327.50, 497.70, 4479.30, 3649.80, 32848.20, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (381, 'standard', 22000.00, 12, 2768.33, 33220.00, 332.20, 3986.40, 2436.13, 29233.56, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (383, 'standard', 27000.00, 12, 3397.50, 40770.00, 407.70, 4892.40, 2989.80, 35877.60, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (393, 'standard', 22000.00, 15, 2401.67, 36025.00, 288.20, 4323.00, 2113.47, 31702.05, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (395, 'standard', 27000.00, 15, 2947.50, 44212.50, 353.70, 5305.50, 2593.80, 38907.00, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (405, 'standard', 22000.00, 18, 2157.22, 38830.00, 258.87, 4659.66, 1898.35, 34170.30, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (407, 'standard', 27000.00, 18, 2647.50, 47655.00, 317.70, 5718.60, 2329.80, 41936.40, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (417, 'standard', 22000.00, 21, 1982.62, 41635.00, 237.91, 4996.11, 1744.71, 36638.91, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (419, 'standard', 27000.00, 21, 2433.21, 51097.50, 291.99, 6131.79, 2141.22, 44965.62, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (429, 'standard', 22000.00, 24, 1851.67, 44440.00, 222.20, 5332.80, 1629.47, 39107.28, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (431, 'standard', 27000.00, 24, 2272.50, 54540.00, 272.70, 6544.80, 1999.80, 47995.20, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (441, 'standard', 22000.00, 30, 1668.33, 50050.00, 200.20, 6006.00, 1468.13, 44043.90, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (443, 'standard', 27000.00, 30, 2047.50, 61425.00, 245.70, 7371.00, 1801.80, 54054.00, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (453, 'standard', 22000.00, 36, 1546.11, 55660.00, 185.53, 6679.08, 1360.58, 48980.88, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (455, 'standard', 27000.00, 36, 1897.50, 68310.00, 227.70, 8197.20, 1669.80, 60112.80, 4.250, 12.000, '2025-11-14 07:06:09.511403+00');
INSERT INTO public.rate_profile_reference_table VALUES (515, 'legacy', 3000.00, 12, 392.00, 4704.00, 55.00, 660.00, 337.00, 4044.00, 4.733, 14.031, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (516, 'legacy', 4000.00, 12, 510.00, 6120.00, 64.00, 768.00, 446.00, 5352.00, 4.417, 12.549, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (517, 'legacy', 5000.00, 12, 633.00, 7596.00, 80.00, 960.00, 553.00, 6636.00, 4.327, 12.638, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (518, 'legacy', 6000.00, 12, 752.00, 9024.00, 90.00, 1080.00, 662.00, 7944.00, 4.200, 11.968, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (519, 'legacy', 7000.00, 12, 882.00, 10584.00, 112.00, 1344.00, 770.00, 9240.00, 4.267, 12.698, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (520, 'legacy', 8000.00, 12, 1006.00, 12072.00, 128.00, 1536.00, 878.00, 10536.00, 4.242, 12.724, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (521, 'legacy', 9000.00, 12, 1131.00, 13572.00, 144.00, 1728.00, 987.00, 11844.00, 4.233, 12.732, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (522, 'legacy', 10000.00, 12, 1255.00, 15060.00, 160.00, 1920.00, 1095.00, 13140.00, 4.217, 12.749, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (523, 'legacy', 11000.00, 12, 1385.00, 16620.00, 170.00, 2040.00, 1215.00, 14580.00, 4.258, 12.274, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (524, 'legacy', 12000.00, 12, 1504.00, 18048.00, 180.00, 2160.00, 1324.00, 15888.00, 4.200, 11.968, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (525, 'legacy', 13000.00, 12, 1634.00, 19608.00, 202.00, 2424.00, 1432.00, 17184.00, 4.236, 12.362, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (526, 'legacy', 14000.00, 12, 1765.00, 21180.00, 224.00, 2688.00, 1541.00, 18492.00, 4.274, 12.691, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (527, 'legacy', 15000.00, 12, 1888.00, 22656.00, 240.00, 2880.00, 1648.00, 19776.00, 4.253, 12.712, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (528, 'legacy', 16000.00, 12, 2012.00, 24144.00, 256.00, 3072.00, 1756.00, 21072.00, 4.242, 12.724, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (529, 'legacy', 17000.00, 12, 2137.00, 25644.00, 272.00, 3264.00, 1865.00, 22380.00, 4.237, 12.728, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (530, 'legacy', 18000.00, 12, 2262.00, 27144.00, 288.00, 3456.00, 1974.00, 23688.00, 4.233, 12.732, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (531, 'legacy', 19000.00, 12, 2386.00, 28632.00, 304.00, 3648.00, 2082.00, 24984.00, 4.225, 12.741, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (532, 'legacy', 20000.00, 12, 2510.00, 30120.00, 320.00, 3840.00, 2190.00, 26280.00, 4.217, 12.749, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (533, 'legacy', 21000.00, 12, 2640.00, 31680.00, 330.00, 3960.00, 2310.00, 27720.00, 4.238, 12.500, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (534, 'legacy', 22000.00, 12, 2759.00, 33108.00, 340.00, 4080.00, 2419.00, 29028.00, 4.208, 12.323, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (535, 'legacy', 23000.00, 12, 2889.00, 34668.00, 362.00, 4344.00, 2527.00, 30324.00, 4.228, 12.530, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (536, 'legacy', 24000.00, 12, 3020.00, 36240.00, 384.00, 4608.00, 2636.00, 31632.00, 4.250, 12.715, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (537, 'legacy', 25000.00, 12, 3143.00, 37716.00, 400.00, 4800.00, 2743.00, 32916.00, 4.239, 12.727, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (538, 'legacy', 26000.00, 12, 3267.00, 39204.00, 416.00, 4992.00, 2851.00, 34212.00, 4.232, 12.733, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (539, 'legacy', 27000.00, 12, 3392.00, 40704.00, 432.00, 5184.00, 2960.00, 35520.00, 4.230, 12.736, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (540, 'legacy', 28000.00, 12, 3517.00, 42204.00, 448.00, 5376.00, 3069.00, 36828.00, 4.227, 12.738, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (541, 'legacy', 29000.00, 12, 3641.00, 43692.00, 464.00, 5568.00, 3177.00, 38124.00, 4.222, 12.744, '2025-11-19 00:39:21.802725+00');
INSERT INTO public.rate_profile_reference_table VALUES (542, 'legacy', 30000.00, 12, 3765.00, 45180.00, 480.00, 5760.00, 3285.00, 39420.00, 4.217, 12.749, '2025-11-19 00:39:21.802725+00');


--
-- Data for Name: rate_profiles; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.rate_profiles VALUES (1, 'legacy', 'Tabla Histórica v2.0', 'Sistema actual con montos predefinidos en tabla. Totalmente editable por admin. Permite agregar nuevos montos como $7,500, $12,350, etc.', 'table_lookup', NULL, true, false, 1, NULL, NULL, '{12}', '2025-11-05 00:58:16.105135+00', '2025-11-05 00:58:16.105135+00', NULL, NULL, NULL);
INSERT INTO public.rate_profiles VALUES (3, 'standard', 'Estándar - Recomendado ⭐', 'Balance óptimo entre competitividad y rentabilidad. Tasa ~51% total (12Q), similar al promedio actual. Recomendado para mayoría de casos.', 'formula', 4.250, true, true, 3, NULL, NULL, '{3,6,9,12,15,18,21,24,30,36}', '2025-11-05 00:58:16.105135+00', '2025-11-25 11:34:00.499195+00', NULL, NULL, 1.600);
INSERT INTO public.rate_profiles VALUES (2, 'transition', 'Transición Suave 3.75%', 'Tasa reducida para facilitar adopción gradual. Cliente ahorra vs tabla actual. Ideal para primeros 6 meses de migración.', 'formula', 3.750, false, false, 2, NULL, NULL, '{6,12,18,24}', '2025-11-05 00:58:16.105135+00', '2025-11-05 00:58:16.105135+00', NULL, NULL, 12.000);
INSERT INTO public.rate_profiles VALUES (4, 'premium', 'Premium 4.5%', 'Tasa objetivo con máxima rentabilidad (54% total en 12Q). Mantiene competitividad vs mercado (60-80%). Activar desde mes 7+ de migración.', 'formula', 4.500, false, false, 4, NULL, NULL, '{3,6,9,12,15,18,21,24,30,36}', '2025-11-05 00:58:16.105135+00', '2025-11-05 00:58:16.105135+00', NULL, NULL, 12.000);
INSERT INTO public.rate_profiles VALUES (5, 'custom', 'Personalizado', 'Tasa ajustable manualmente para casos especiales. Requiere aprobación de gerente/admin. Rango permitido: 2.0% - 6.0% quincenal.', 'formula', 4.250, true, false, 5, NULL, NULL, '{3,6,9,12,15,18,21,24,30,36}', '2025-11-05 00:58:16.105135+00', '2025-11-05 00:58:16.105135+00', NULL, NULL, 1.600);


--
-- Data for Name: relationships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.relationships VALUES (1, 'Padre', 'Padre del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (2, 'Madre', 'Madre del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (3, 'Hijo', 'Hijo del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (4, 'Hija', 'Hija del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (5, 'Hermano', 'Hermano del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (6, 'Hermana', 'Hermana del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (7, 'Esposo', 'Esposo del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (8, 'Esposa', 'Esposa del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (9, 'Abuelo', 'Abuelo del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (10, 'Abuela', 'Abuela del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (11, 'Tío', 'Tío del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (12, 'Tía', 'Tía del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (13, 'Primo', 'Primo del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (14, 'Prima', 'Prima del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (15, 'Sobrino', 'Sobrino del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (16, 'Sobrina', 'Sobrina del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (17, 'Amigo', 'Amigo del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (18, 'Amiga', 'Amiga del titular', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');
INSERT INTO public.relationships VALUES (19, 'Otro', 'Otra relación no especificada', true, '2025-11-13 11:08:51.909367+00', '2025-11-13 11:08:51.909367+00');


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.roles VALUES (1, 'desarrollador', NULL, '2025-10-31 01:12:22.07323+00');
INSERT INTO public.roles VALUES (2, 'administrador', NULL, '2025-10-31 01:12:22.07323+00');
INSERT INTO public.roles VALUES (3, 'auxiliar_administrativo', NULL, '2025-10-31 01:12:22.07323+00');
INSERT INTO public.roles VALUES (4, 'asociado', NULL, '2025-10-31 01:12:22.07323+00');
INSERT INTO public.roles VALUES (5, 'cliente', NULL, '2025-10-31 01:12:22.07323+00');


--
-- Data for Name: statement_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.statement_statuses VALUES (6, 'DRAFT', 'BORRADOR - Vista preliminar editable. Admin puede ajustar antes de cerrar corte.', false, 0, '#FFC107', '2025-11-26 20:11:34.098392+00', '2025-12-04 08:30:19.259578+00');
INSERT INTO public.statement_statuses VALUES (3, 'PAID', 'PAGADO - Asociado pagó completamente a CrediCuenta.', true, 2, '#4CAF50', '2025-10-31 01:12:22.084329+00', '2025-12-04 08:30:19.259578+00');
INSERT INTO public.statement_statuses VALUES (1, 'GENERATED', 'DEPRECADO - Usar FINALIZED en su lugar.', false, 99, '#9E9E9E', '2025-10-31 01:12:22.084329+00', '2025-12-04 08:30:19.259578+00');
INSERT INTO public.statement_statuses VALUES (2, 'SENT', 'DEPRECADO - Usar flag sent_date en statement.', false, 99, '#2196F3', '2025-10-31 01:12:22.084329+00', '2025-12-04 08:30:19.259578+00');
INSERT INTO public.statement_statuses VALUES (7, 'COLLECTING', 'EN COBRO - Statement oficial, esperando pago del asociado a CrediCuenta.', false, 1, '#2196F3', '2025-11-26 20:11:34.098392+00', '2025-12-04 09:17:25.171181+00');
INSERT INTO public.statement_statuses VALUES (9, 'SETTLING', 'EN LIQUIDACIÓN - Período en proceso de cierre, último esfuerzo de cobro.', false, 5, '#9C27B0', '2025-12-18 06:17:27.755561+00', '2025-12-18 06:17:27.755561+00');
INSERT INTO public.statement_statuses VALUES (10, 'CLOSED', 'CERRADO - Período cerrado definitivamente.', false, 6, '#455A64', '2025-12-18 06:17:27.755561+00', '2025-12-18 06:17:27.755561+00');
INSERT INTO public.statement_statuses VALUES (8, 'ABSORBED', 'DEPRECADO - ABSORBIDO - Deuda transferida al balance acumulado del asociado.', false, 99, '#607D8B', '2025-12-04 08:30:19.259578+00', '2025-12-18 06:17:27.755561+00');
INSERT INTO public.statement_statuses VALUES (5, 'OVERDUE', 'DEPRECADO - VENCIDO - Período terminó sin pago completo del asociado.', false, 99, '#F44336', '2025-10-31 01:12:22.084329+00', '2025-12-18 06:17:27.755561+00');
INSERT INTO public.statement_statuses VALUES (4, 'PARTIAL', 'DEPRECADO - PAGO PARCIAL - Asociado realizó abono parcial, saldo pendiente.', false, 99, '#FF9800', '2025-10-31 01:12:22.084329+00', '2025-12-18 06:17:27.755561+00');


--
-- Name: associate_levels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.associate_levels_id_seq', 1, false);


--
-- Name: config_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.config_types_id_seq', 8, true);


--
-- Name: contract_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.contract_statuses_id_seq', 6, true);


--
-- Name: cut_period_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.cut_period_statuses_id_seq', 6, true);


--
-- Name: document_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.document_statuses_id_seq', 4, true);


--
-- Name: document_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.document_types_id_seq', 1, false);


--
-- Name: level_change_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.level_change_types_id_seq', 6, true);


--
-- Name: loan_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.loan_statuses_id_seq', 8, true);


--
-- Name: payment_methods_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payment_methods_id_seq', 7, true);


--
-- Name: payment_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payment_statuses_id_seq', 1, false);


--
-- Name: rate_profile_reference_table_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.rate_profile_reference_table_id_seq', 542, true);


--
-- Name: rate_profiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.rate_profiles_id_seq', 6, true);


--
-- Name: relationships_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.relationships_id_seq', 19, true);


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.roles_id_seq', 6, false);


--
-- Name: statement_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.statement_statuses_id_seq', 6, true);


--
-- PostgreSQL database dump complete
--

\unrestrict 3uv63XtWOjwyhK8u9ekZlu7MbruoDONIbZk75ZGh3dVGKalx73dd3stG7mBN8b7

