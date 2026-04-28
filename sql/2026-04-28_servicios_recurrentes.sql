-- ═══════════════════════════════════════════════════════════════════════
-- Migracion: Servicios recurrentes (utilities + suscripciones + impuestos)
-- Fecha: 2026-04-28
-- Schema: finanzas_personales
-- ═══════════════════════════════════════════════════════════════════════

SET search_path TO finanzas_personales;

-- ═══════════════════════════════════════════════════════════════════════
-- 1. TABLAS
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS propiedades (
  id              SERIAL PRIMARY KEY,
  nombre          TEXT NOT NULL,
  direccion       TEXT,
  localidad       TEXT,
  provincia       TEXT DEFAULT 'Tucuman',
  tipo            TEXT,                       -- casa | depto | cochera | terreno | quinta
  titular_real    TEXT,                       -- "Luis + Gonzalo", "Padres", "Padres + Luis + hermanos"
  titular_legal   TEXT,                       -- nombre que figura en facturas (puede ser titular viejo)
  activa          BOOLEAN DEFAULT true,
  notas           TEXT,
  creado_en       TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS servicios_recurrentes (
  id                  SERIAL PRIMARY KEY,
  nombre              TEXT NOT NULL,
  tipo                TEXT NOT NULL,          -- luz | gas | agua | internet | celular | tv | suscripcion | gym | impuesto | otro
  propiedad_id        INT REFERENCES propiedades(id) ON DELETE SET NULL,
  proveedor           TEXT,                   -- EDET, Naturgy, Personal, Spotify, etc
  numero_cuenta       TEXT,                   -- referente de pago / nro cliente / nro suministro
  titular_factura     TEXT,                   -- titular legal en factura
  monto_estimado      NUMERIC(12,2),
  moneda              TEXT DEFAULT 'ARS',     -- ARS | USD
  dia_vencimiento     INT,                    -- 1-31 (dia del mes)
  mes_vencimiento     INT,                    -- 1-12 (solo para anuales: en que mes vence)
  frecuencia          TEXT DEFAULT 'mensual', -- mensual | bimestral | trimestral | anual
  paga                TEXT,                   -- Luis | Padres | Compartido | Inquilinos
  porcentaje_propio   NUMERIC(5,2) DEFAULT 100,  -- % del monto que pone Luis
  comparte_con        TEXT,                   -- Gonzalo, Padres, etc
  debito_automatico   BOOLEAN DEFAULT false,
  metodo_pago         TEXT,                   -- Galicia, Naranja, Efectivo, Mercado Pago
  componentes         JSONB,                  -- desglose interno: {"celular":22099,"internet":21027,...}
  notas               TEXT,
  activo              BOOLEAN DEFAULT true,
  creado_en           TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pagos_servicios (
  id                  SERIAL PRIMARY KEY,
  servicio_id         INT NOT NULL REFERENCES servicios_recurrentes(id) ON DELETE CASCADE,
  periodo             TEXT NOT NULL,          -- "2026-04" o "2026-04-bim" para bimestrales
  fecha_vencimiento   DATE,
  monto_real          NUMERIC(12,2),
  moneda              TEXT DEFAULT 'ARS',
  fecha_pago          DATE,
  pagado              BOOLEAN DEFAULT false,
  metodo_pago         TEXT,
  numero_factura      TEXT,
  comprobante_url     TEXT,
  notas               TEXT,
  creado_en           TIMESTAMPTZ DEFAULT now(),
  UNIQUE(servicio_id, periodo)
);

CREATE INDEX IF NOT EXISTS idx_serv_propiedad ON servicios_recurrentes(propiedad_id);
CREATE INDEX IF NOT EXISTS idx_serv_activo    ON servicios_recurrentes(activo);
CREATE INDEX IF NOT EXISTS idx_pagos_servicio ON pagos_servicios(servicio_id);
CREATE INDEX IF NOT EXISTS idx_pagos_pagado   ON pagos_servicios(pagado);

-- ═══════════════════════════════════════════════════════════════════════
-- 2. PROPIEDADES (6)
-- ═══════════════════════════════════════════════════════════════════════

INSERT INTO propiedades (id, nombre, direccion, localidad, provincia, tipo, titular_real, titular_legal, notas) VALUES
(1, 'Azcuenaga 276',          'Azcuenaga 276 (entre Mendoza y Don Bosco)', 'San Miguel de Tucuman', 'Tucuman', 'depto',     'Luis + Gonzalo',                'Luis Alberto Molina (papa)', 'Domicilio actual de Luis y Gonzalo. Comparten gastos del depto al 50%.'),
(2, 'Casa Padres - Nougues',  'Juan L. Nougues 1263 (B. Zenon Santillan)', 'San Miguel de Tucuman', 'Tucuman', 'casa',      'Padres',                        'Pedro Pablo Iturbe (titular viejo)', 'Casa de los padres. Luis solo gestiona.'),
(3, 'Cochera + Locales Italia', 'Italia 4167',                              'San Miguel de Tucuman', 'Tucuman', 'cochera',   'Padres + Luis + hermanos',      'Manuel Paz (titular viejo)', 'Cochera con locales comerciales. Pagan inquilinos + papa. Luis solo gestiona, registra para control.'),
(4, 'Raco - El Portezuelo',   'Ruta 340 km 18 - El Portezuelo',            'Raco',                  'Tucuman', 'casa',      'Padres',                        'Luis Alberto Molina (papa)', 'Casa de fin de semana. Padres pagan, Luis gestiona.'),
(5, 'Raco - Valle San Javier', 'Ruta 340 km 18 - Valle de San Javier',      'Raco',                  'Tucuman', 'casa',      'Padres',                        'Luis Alberto Molina (papa)', 'Casa de fin de semana. Padres pagan, Luis gestiona.'),
(6, 'San Pedro Colalao',      'Bo. Belgrano calle 39 (entre Mundial 78 y 86)', 'San Pedro de Colalao', 'Tucuman', 'casa',  'Padres',                        'Otilia Encarnacion Cabello (titular viejo)', 'Casa de fin de semana. Padres pagan, Luis gestiona.');

SELECT setval('propiedades_id_seq', 6, true);

-- ═══════════════════════════════════════════════════════════════════════
-- 3. SERVICIOS RECURRENTES
-- ═══════════════════════════════════════════════════════════════════════

-- ─── AZCUENAGA 276 (Luis paga, comparte con Gonzalo) ─────────────────
INSERT INTO servicios_recurrentes
  (nombre, tipo, propiedad_id, proveedor, numero_cuenta, titular_factura, monto_estimado, moneda, dia_vencimiento, frecuencia, paga, porcentaje_propio, comparte_con, metodo_pago, notas) VALUES
('Gas Azcuenaga',     'gas',      1, 'Naturgy', '1249149',           'Luis Alberto Molina',  26058.20,  'ARS', 7,  'bimestral', 'Compartido', 50, 'Gonzalo', 'Galicia',  'Categoria R3-1, segmentacion N3. Codigo pago online: 501249149.'),
('Agua Azcuenaga',    'agua',     1, 'SAT',     '16610336',          'Molina Luis Alberto',  23599.12,  'ARS', 20, 'bimestral', 'Compartido', 50, 'Gonzalo', 'Galicia',  'Bimestral.'),
('Luz Azcuenaga',     'luz',      1, 'EDET',    '80414',             'Molina Luis Alberto', 167350.00,  'ARS', 31, 'bimestral', 'Compartido', 50, 'Gonzalo', 'Galicia',  'Tarifa T1R. Bimestral.'),
('Pack Personal Luis - Azcuenaga', 'tv', 1, 'Personal', '1002612929410002', 'Patricia Marcela Reinoso (mama)', 47710.00, 'ARS', 7, 'mensual', 'Compartido', 73, 'Gonzalo', 'Galicia',
  'Factura unificada Personal: Cel Luis (3814690975) + Internet 300MB + Flow Full + Linea fija (3814366480). Reparto: cel Luis 100% + internet/flow/fija 50/50 con Gonzalo. Porcentaje propio aprox 73%.');

-- Componente JSONB del Pack Personal Luis (detalle del reparto)
UPDATE servicios_recurrentes SET componentes = '{
  "celular_luis":   {"linea":"3814690975", "monto":22099, "reparto":"100% Luis"},
  "internet_300mb": {"monto":21028, "reparto":"50/50 con Gonzalo"},
  "flow_full":      {"monto":9331,  "reparto":"50/50 con Gonzalo"},
  "linea_fija":     {"linea":"3814366480", "monto":0.01, "reparto":"50/50 con Gonzalo"},
  "descuentos":     -6000,
  "extras_eventuales": "WiFi Pass 4500 + intereses mora 1252"
}'::jsonb WHERE nombre = 'Pack Personal Luis - Azcuenaga';

-- ─── CASA PADRES NOUGUES 1263 (padres pagan, Luis gestiona) ──────────
INSERT INTO servicios_recurrentes
  (nombre, tipo, propiedad_id, proveedor, numero_cuenta, titular_factura, monto_estimado, moneda, dia_vencimiento, frecuencia, paga, porcentaje_propio, notas) VALUES
('Gas Nougues',      'gas',      2, 'Naturgy', '776151',            'Pedro Pablo Iturbe',   12236.42,  'ARS', 7,  'bimestral', 'Padres', 0, 'Categoria R1, N3. Codigo pago online: 500776151. Padres pagan.'),
('Agua Nougues',     'agua',     2, 'SAT',     '16612297',          'Iturbe Pedro Pablo',   17708.55,  'ARS', 20, 'bimestral', 'Padres', 0, 'Bimestral. Padres pagan.'),
('Internet Nougues', 'internet', 2, 'Claro',   '21216557262',       'Molina Reinoso Luis Hernan', 22687.12, 'ARS', 24, 'mensual', 'Padres', 0, 'Linea fija 381-2585756. Padres pagan, Luis figura como titular.'),
('Luz Nougues',      'luz',      2, 'EDET',    '81123',             'Iturbe Pedro Pablo',   74620.00,  'ARS', 23, 'bimestral', 'Padres', 0, 'Tarifa T1R. Bimestral. Padres pagan.');

-- ─── COCHERA + LOCALES ITALIA 4167 (inquilinos + papa, Luis gestiona) ─
INSERT INTO servicios_recurrentes
  (nombre, tipo, propiedad_id, proveedor, numero_cuenta, titular_factura, monto_estimado, moneda, dia_vencimiento, frecuencia, paga, porcentaje_propio, notas) VALUES
('Internet Italia',  'internet', 3, 'Claro',   '-',                 'Molina Reinoso Luis Hernan', 22687.12, 'ARS', 24, 'mensual', 'Padres', 0, 'Linea fija 381-3173300. ID linea 1706228. Domicilio Italia 4167 (corregido del Excel que decia 4145). Inquilinos + papa pagan.'),
('Luz Italia',       'luz',      3, 'EDET',    '82770',             'Manuel Paz',          614100.00,  'ARS', 24, 'bimestral', 'Padres', 0, 'Tarifa T1R. Monto alto por incluir locales comerciales. Inquilinos + papa pagan. Solo registro para control.');

-- ─── RACO EL PORTEZUELO (padres) ─────────────────────────────────────
INSERT INTO servicios_recurrentes
  (nombre, tipo, propiedad_id, proveedor, numero_cuenta, titular_factura, monto_estimado, moneda, dia_vencimiento, frecuencia, paga, porcentaje_propio, notas) VALUES
('Luz Raco Portezuelo', 'luz', 4, 'EDET', '644035', 'Molina Luis Alberto', 144100.00, 'ARS', 22, 'bimestral', 'Padres', 0, 'Tarifa T1R. Bimestral. Padres pagan. NOTA: hay internet en Raco que gestionan los padres, falta cargar (proveedor + monto + dia).');

-- ─── RACO VALLE SAN JAVIER (padres) ──────────────────────────────────
INSERT INTO servicios_recurrentes
  (nombre, tipo, propiedad_id, proveedor, numero_cuenta, titular_factura, monto_estimado, moneda, dia_vencimiento, frecuencia, paga, porcentaje_propio, notas) VALUES
('Luz Raco Valle San Javier', 'luz', 5, 'EDET', '716612', 'Molina Luis Alberto', 92780.00, 'ARS', 22, 'bimestral', 'Padres', 0, 'Tarifa T1R. Bimestral. Padres pagan.');

-- ─── SAN PEDRO COLALAO (padres) ──────────────────────────────────────
INSERT INTO servicios_recurrentes
  (nombre, tipo, propiedad_id, proveedor, numero_cuenta, titular_factura, monto_estimado, moneda, dia_vencimiento, frecuencia, paga, porcentaje_propio, notas) VALUES
('Luz San Pedro', 'luz', 6, 'EDET', '445102', 'Otilia Encarnacion Cabello', 62480.00, 'ARS', 5, 'bimestral', 'Padres', 0, 'Tarifa T1R. Bimestral. Padres pagan.');

-- ─── CELULARES PERSONAL SUELTOS (Luis paga) ──────────────────────────
INSERT INTO servicios_recurrentes
  (nombre, tipo, propiedad_id, proveedor, numero_cuenta, titular_factura, monto_estimado, moneda, dia_vencimiento, frecuencia, paga, porcentaje_propio, metodo_pago, notas) VALUES
('Celular Gonzalo',   'celular', NULL, 'Personal', '1002612929410004', 'Patricia Marcela Reinoso (mama)', 20000.00, 'ARS', 4, 'mensual', 'Luis', 100, 'Galicia', 'Linea 3814750821. Luis paga al 100% (revisar si Gonzalo aporta).'),
('Celular Papa',      'celular', NULL, 'Personal', '1002612929410003', 'Patricia Marcela Reinoso (mama)', 20000.00, 'ARS', 4, 'mensual', 'Luis', 100, 'Galicia', 'Linea 3814637099 (Pedro Pablo Iturbe / papa).'),
('Celular Mama',      'celular', NULL, 'Personal', '1002612929410001', 'Patricia Marcela Reinoso (mama)', 17927.96, 'ARS', 4, 'mensual', 'Luis', 100, 'Galicia', 'Linea 3814480816.'),
('Celular Luciano',   'celular', NULL, 'Personal', '1001585432410001', 'Molina Luis Alberto (papa)',      20000.00, 'ARS', 4, 'mensual', 'Luis', 100, 'Galicia', 'Linea 3816553100. Hermano Luciano.');

-- ─── SUSCRIPCIONES (Luis paga) ───────────────────────────────────────
INSERT INTO servicios_recurrentes
  (nombre, tipo, propiedad_id, proveedor, monto_estimado, moneda, dia_vencimiento, mes_vencimiento, frecuencia, paga, porcentaje_propio, debito_automatico, metodo_pago, notas) VALUES
('Spotify',           'suscripcion', NULL, 'Spotify',   3.27,     'USD', 15, NULL, 'mensual', 'Luis', 100, true, 'Naranja', 'Plan individual. Debito automatico.'),
('Hostinger',         'suscripcion', NULL, 'Hostinger', 37188.00, 'ARS', 7,  2,    'anual',   'Luis', 100, true, 'Galicia', 'Renovacion anual cada 7 de febrero. Hosting web.'),
('LinkedIn Premium',  'suscripcion', NULL, 'LinkedIn',  11988.00, 'ARS', 24, 3,    'anual',   'Luis', 100, true, 'Galicia', 'Renovacion anual cada 24 de marzo. Monto + impuestos (revisar monto exacto con impuestos).'),
('Claude Pro',        'suscripcion', NULL, 'Anthropic', 20.00,    'USD', 11, NULL, 'mensual', 'Luis', 100, true, 'Naranja', 'Una sola cuenta (paso de 3 a 1).'),
('Curso Academia IA', 'suscripcion', NULL, 'Academia IA', 55.00,  'USD', 29, NULL, 'mensual', 'Luis', 100, true, 'Naranja', 'Suscripcion mensual academia.');

-- ─── OTROS RECURRENTES ───────────────────────────────────────────────
INSERT INTO servicios_recurrentes
  (nombre, tipo, propiedad_id, proveedor, monto_estimado, moneda, dia_vencimiento, frecuencia, paga, porcentaje_propio, debito_automatico, metodo_pago, notas) VALUES
('Gimnasio',          'gym',  NULL, 'Gimnasio', 46000.00, 'ARS', 29, 'mensual', 'Luis', 100, false, 'Efectivo', 'Pago en efectivo.');

-- ═══════════════════════════════════════════════════════════════════════
-- 4. VISTAS UTILES PARA EL DASHBOARD / API
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW vista_servicios_dashboard AS
SELECT
  s.id,
  s.nombre,
  s.tipo,
  s.proveedor,
  s.numero_cuenta,
  s.monto_estimado,
  s.moneda,
  s.dia_vencimiento,
  s.mes_vencimiento,
  s.frecuencia,
  s.paga,
  s.porcentaje_propio,
  s.comparte_con,
  ROUND(s.monto_estimado * s.porcentaje_propio / 100, 2) AS monto_a_pagar_luis,
  s.debito_automatico,
  s.metodo_pago,
  s.activo,
  p.id   AS propiedad_id,
  p.nombre AS propiedad_nombre,
  p.tipo   AS propiedad_tipo
FROM servicios_recurrentes s
LEFT JOIN propiedades p ON p.id = s.propiedad_id
WHERE s.activo = true;

-- Vista: proximos vencimientos del mes actual con estado pagado
CREATE OR REPLACE VIEW vista_proximos_vencimientos AS
WITH mes_actual AS (
  SELECT
    s.*,
    CASE
      WHEN s.frecuencia = 'mensual'   THEN make_date(EXTRACT(YEAR FROM CURRENT_DATE)::int, EXTRACT(MONTH FROM CURRENT_DATE)::int, LEAST(s.dia_vencimiento, 28))
      WHEN s.frecuencia = 'bimestral' AND EXTRACT(MONTH FROM CURRENT_DATE)::int % 2 = 0 THEN make_date(EXTRACT(YEAR FROM CURRENT_DATE)::int, EXTRACT(MONTH FROM CURRENT_DATE)::int, LEAST(s.dia_vencimiento, 28))
      WHEN s.frecuencia = 'anual' AND s.mes_vencimiento = EXTRACT(MONTH FROM CURRENT_DATE)::int THEN make_date(EXTRACT(YEAR FROM CURRENT_DATE)::int, s.mes_vencimiento, LEAST(s.dia_vencimiento, 28))
      ELSE NULL
    END AS proximo_vto
  FROM servicios_recurrentes s
  WHERE s.activo = true
)
SELECT
  m.id, m.nombre, m.tipo, m.proveedor, m.monto_estimado, m.moneda,
  m.paga, m.porcentaje_propio,
  ROUND(m.monto_estimado * m.porcentaje_propio / 100, 2) AS monto_a_pagar_luis,
  m.proximo_vto,
  (m.proximo_vto - CURRENT_DATE)::int AS dias_para_vencer,
  COALESCE(ps.pagado, false) AS pagado,
  ps.fecha_pago,
  ps.monto_real
FROM mes_actual m
LEFT JOIN pagos_servicios ps ON ps.servicio_id = m.id
  AND ps.periodo = TO_CHAR(CURRENT_DATE, 'YYYY-MM')
WHERE m.proximo_vto IS NOT NULL
ORDER BY m.proximo_vto;

-- ═══════════════════════════════════════════════════════════════════════
-- 5. VALIDACION
-- ═══════════════════════════════════════════════════════════════════════

-- Resumen de carga
SELECT 'Propiedades' AS tabla, COUNT(*)::text AS total FROM propiedades
UNION ALL SELECT 'Servicios totales', COUNT(*)::text FROM servicios_recurrentes
UNION ALL SELECT 'Servicios que paga Luis (porcentaje > 0)', COUNT(*)::text FROM servicios_recurrentes WHERE porcentaje_propio > 0
UNION ALL SELECT 'Servicios solo gestion (porcentaje = 0)', COUNT(*)::text FROM servicios_recurrentes WHERE porcentaje_propio = 0
UNION ALL SELECT 'Total mensual ARS (que paga Luis)',
  TO_CHAR(SUM(CASE
    WHEN moneda = 'ARS' AND frecuencia = 'mensual' THEN monto_estimado * porcentaje_propio / 100
    WHEN moneda = 'ARS' AND frecuencia = 'bimestral' THEN monto_estimado * porcentaje_propio / 100 / 2
    WHEN moneda = 'ARS' AND frecuencia = 'anual' THEN monto_estimado * porcentaje_propio / 100 / 12
    ELSE 0
  END), 'FM999G999G990D00')
FROM servicios_recurrentes WHERE activo = true
UNION ALL SELECT 'Total mensual USD (que paga Luis)',
  TO_CHAR(SUM(CASE
    WHEN moneda = 'USD' AND frecuencia = 'mensual' THEN monto_estimado * porcentaje_propio / 100
    WHEN moneda = 'USD' AND frecuencia = 'anual' THEN monto_estimado * porcentaje_propio / 100 / 12
    ELSE 0
  END), 'FM999G990D00')
FROM servicios_recurrentes WHERE activo = true;

-- Listado completo
SELECT
  p.nombre AS propiedad,
  s.nombre AS servicio,
  s.tipo,
  s.frecuencia,
  s.paga,
  s.porcentaje_propio || '%' AS pct,
  s.moneda || ' ' || TO_CHAR(s.monto_estimado, 'FM999G999G990D00') AS monto,
  'Vence dia ' || s.dia_vencimiento AS vence
FROM servicios_recurrentes s
LEFT JOIN propiedades p ON p.id = s.propiedad_id
WHERE s.activo = true
ORDER BY p.nombre NULLS LAST, s.tipo, s.nombre;
