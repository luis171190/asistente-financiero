-- ═══════════════════════════════════════════════════════════════════════
-- Limpieza: gastos_fijos -> migrar a servicios_recurrentes (Fase 1.5)
-- Fecha: 2026-04-28
-- Schema: finanzas_personales
-- ═══════════════════════════════════════════════════════════════════════
-- Acciones:
--   1. INSERT en servicios_recurrentes: Monotributo AFIP + VPN Contabo
--   2. UPDATE activo=false en gastos_fijos para 18 entradas:
--      - 13 duplicados con servicios_recurrentes (luz/gas/agua/internet/cel/spotify/claude/academia/hostinger/gym)
--      - 2 migrados (monotributo, vpn)
--      - 3 dados de baja (kie.ai pago unico, openai pago unico, seguro auto no paga)
-- ═══════════════════════════════════════════════════════════════════════

SET search_path TO finanzas_personales;

-- ─── 0. GRANTS (CRITICO) ──────────────────────────────────────────────
-- El rol que usa n8n necesita permisos INSERT/UPDATE/DELETE en las
-- tablas nuevas y SELECT en las vistas. Sin esto el AI Agent y la API
-- Dashboard no pueden escribir/leer los servicios.
-- Ajustar 'postgres' por el rol real que usa n8n si es distinto.
DO $$
DECLARE
  rol TEXT := 'postgres';  -- cambiar si el rol de n8n es otro (ej: anon, authenticator)
BEGIN
  EXECUTE format('GRANT USAGE ON SCHEMA finanzas_personales TO %I', rol);
  EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA finanzas_personales TO %I', rol);
  EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA finanzas_personales TO %I', rol);
  EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA finanzas_personales GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I', rol);
  EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA finanzas_personales GRANT USAGE, SELECT ON SEQUENCES TO %I', rol);
END $$;

-- ─── 1. MIGRAR 2 SERVICIOS A servicios_recurrentes ───────────────────

INSERT INTO servicios_recurrentes
  (nombre, tipo, propiedad_id, proveedor, numero_cuenta, titular_factura,
   monto_estimado, moneda, dia_vencimiento, mes_vencimiento, frecuencia,
   paga, porcentaje_propio, comparte_con,
   debito_automatico, metodo_pago, notas, activo) VALUES

-- Monotributo AFIP — obligacion mensual fiscal
('Monotributo AFIP', 'impuesto', NULL, 'AFIP', NULL, 'Luis Molina Reinoso',
 4780.46, 'ARS', 20, NULL, 'mensual',
 'Luis', 100, NULL,
 false, 'Galicia',
 'Categoria mensual obligatoria del monotributo. Migrado de gastos_fijos #20 (2026-04-28).',
 true),

-- VPN Contabo — servidor VPN privado
('VPN Contabo', 'suscripcion', NULL, 'Contabo', NULL, NULL,
 7.95, 'USD', 30, NULL, 'mensual',
 'Luis', 100, NULL,
 true, 'Naranja',
 'Servidor VPN privado en Contabo. Migrado de gastos_fijos #12 (2026-04-28).',
 true);

-- ─── 2. SOFT DELETE en gastos_fijos (activo = false) ─────────────────

UPDATE gastos_fijos
SET activo = false,
    actualizado_en = now(),
    notas = COALESCE(notas, '') || E'\n[2026-04-28] Desactivado: migrado a servicios_recurrentes o dado de baja.'
WHERE id IN (
  -- Duplicados (ya estan en servicios_recurrentes desglosados):
  1,    -- Luz (EDET)            -> servicios_recurrentes (6 entradas por propiedad)
  2,    -- Gas (Naturgy)         -> servicios_recurrentes (Azcuenaga + Nougues)
  3,    -- Agua (SAT)            -> servicios_recurrentes (Azcuenaga + Nougues)
  4,    -- Internet (Flow)       -> incluido en Pack Personal Luis
  5,    -- Celular (Personal)    -> incluido en Pack Personal Luis
  9,    -- Claude Pro #1         -> consolidado a 1 cuenta
  10,   -- Claude Pro #2         -> consolidado a 1 cuenta
  21,   -- Claude Pro #3         -> consolidado a 1 cuenta
  13,   -- Spotify (ARS)         -> consolidado a USD
  24,   -- Spotify (USD)         -> ya en servicios_recurrentes
  14,   -- Academia IA Masters   -> ya en servicios_recurrentes
  15,   -- Hostinger (anual)     -> ya en servicios_recurrentes (con monto correcto)
  16,   -- Gimnasio              -> ya en servicios_recurrentes
  -- Migrados ahora:
  20,   -- Monotributo AFIP      -> servicios_recurrentes (recien insertado)
  12,   -- VPN Contabo           -> servicios_recurrentes (recien insertado)
  -- Dados de baja:
  22,   -- Kie.ai                -> fue pago unico, no recurrente
  23,   -- OpenAI API            -> fue pago unico, no recurrente
  7     -- Seguro Auto           -> Luis no paga seguro por el momento
);

-- ─── 3. VALIDACION ───────────────────────────────────────────────────

-- Confirmar que servicios_recurrentes ahora tiene 25 (23 anteriores + 2 nuevos)
SELECT 'servicios_recurrentes_total'::text AS metric, COUNT(*)::text AS valor
FROM servicios_recurrentes
WHERE activo = true
UNION ALL
-- Confirmar que gastos_fijos activos quedaron en 2 (Honorarios Jorge + McAfee Hermano)
SELECT 'gastos_fijos_activos_restantes', COUNT(*)::text
FROM gastos_fijos WHERE activo = true
UNION ALL
SELECT 'gastos_fijos_dados_de_baja_hoy', COUNT(*)::text
FROM gastos_fijos
WHERE activo = false AND DATE(actualizado_en) = CURRENT_DATE;

-- Listado de gastos_fijos que quedan activos (deberian ser solo los 2 legitimos)
SELECT id, nombre, monto, moneda, dia_vencimiento, activo
FROM gastos_fijos
WHERE activo = true
ORDER BY id;

-- Listado de los 2 nuevos servicios migrados
SELECT id, nombre, tipo, monto_estimado, moneda, dia_vencimiento, frecuencia, paga, porcentaje_propio
FROM servicios_recurrentes
WHERE nombre IN ('Monotributo AFIP', 'VPN Contabo')
ORDER BY id;
