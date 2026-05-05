-- ═══════════════════════════════════════════════════════════════════════
-- Fase 2 Setup: columna pago_servicio_id en gastos_variables + categoria
-- Fecha: 2026-04-28
-- Schema: finanzas_personales
-- ═══════════════════════════════════════════════════════════════════════

SET search_path TO finanzas_personales;

-- ─── 1. COLUMNA pago_servicio_id en gastos_variables ─────────────────
-- Permite vincular un gasto_variable al pago de servicio que lo generó.
-- Evita duplicados: si ya existe un gasto con este pago_servicio_id, no se inserta otro.

ALTER TABLE gastos_variables
  ADD COLUMN IF NOT EXISTS pago_servicio_id integer
    REFERENCES pagos_servicios(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_gastos_variables_pago_servicio
  ON gastos_variables(pago_servicio_id)
  WHERE pago_servicio_id IS NOT NULL;

-- ─── 2. CATEGORIA "Servicios Fijos" (si no existe) ────────────────────
-- Usada para los gastos_variables auto-generados al pagar un servicio recurrente.

INSERT INTO categorias_gasto (nombre, icono, tipo)
SELECT 'Servicios Fijos', '🏠', 'necesidad'
WHERE NOT EXISTS (
  SELECT 1 FROM categorias_gasto
  WHERE nombre ILIKE '%servicio%' OR nombre ILIKE '%fijo%'
);

-- ─── 3. VALIDACION ───────────────────────────────────────────────────

SELECT
  (SELECT column_name FROM information_schema.columns
   WHERE table_schema = 'finanzas_personales'
     AND table_name = 'gastos_variables'
     AND column_name = 'pago_servicio_id') AS columna_existe,
  (SELECT nombre FROM categorias_gasto
   WHERE nombre ILIKE '%servicio%' OR nombre ILIKE '%fijo%'
   LIMIT 1) AS categoria_servicios;
