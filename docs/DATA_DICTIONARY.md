# Diccionario de Datos — Dashboard PWA

> Documento que explica qué muestra cada apartado del PWA `finanzas-pwa-885.netlify.app`,
> cómo se calcula cada métrica, y de qué tabla / workflow sale.
>
> Versión: 2026-04-29 (post-Fase 2 + ABM servicios)

---

## 🔌 Fuente de datos única

Todo el dashboard consume **un solo endpoint**:
```
GET https://sswebhook.myaivaro.com/webhook/dash-data
```

Workflow n8n: `📡 API Dashboard` (ID `E0AwewlJN2GKMDzF`)

Una única query a Supabase devuelve un JSON con TODA la info del mes en curso. El refresh manual (botón ↻ en el header) re-consulta este endpoint.

**Frecuencia:** on-demand. No hay polling. La página se cachea via service worker pero los datos NO (network-first).

---

## 🗂️ Estructura del JSON de respuesta

```jsonc
{
  "anio_mes": "2026-04",                  // periodo actual
  "ingreso_total_usd": 1400,
  "ingreso_total_ars": 1960000,
  "tipo_cambio": 1430,                    // TC al inicio del mes (histórico)
  "tc_blue": 1430,                        // TC actual (más reciente)
  "tc_fecha": "2026-04-29",
  "presupuesto_necesidades": 784000,
  "presupuesto_deseos": 490000,
  "presupuesto_ahorro": 392000,
  "gastado_necesidades": 1407069,
  "gastado_deseos": 380517,
  "ahorro_real": 0,
  "compromisos_tc": 750000,               // suma cuotas activas
  "disponible_para_gastar": -175312,
  "billeteras": [...],                    // todas las billeteras con saldo
  "gastos_mes": [...],                    // gastos_variables del mes
  "compromisos": [...],                   // cuotas activas
  "historial_meses": [...],               // últimos 5 meses
  "servicios": [...]                      // servicios recurrentes con estado
}
```

---

# 🎯 Header (siempre visible)

```
[Finanzas]  Abril 2026   [USD Blue $1.430 29/4]  [Ingreso $1.960.000]  [Disp. -$175.312]   [⚠️ alertas]   [Act. 11:21]   [↻]
```

| Elemento | Origen | Cómo se calcula |
|---|---|---|
| **Mes** | `anio_mes` | Convertido a "Abril 2026" con `mesL()` |
| **USD Blue $X / fecha** | `tc_blue`, `tc_fecha` | Última fila de `tipo_cambio` |
| **Ingreso $X** | `ingreso_total_ars` | Campo de `presupuesto_mensual` del mes actual |
| **Disp.** | `disponible_para_gastar` | Verde si ≥ 0, rojo si < 0 |
| **Badge ⚠️** | Calculado en JS | Cantidad de servicios vencidos + esta semana (sin pagar). Click → tab Servicios |
| **Act. HH:MM** | Hora de cliente | Momento del último fetch exitoso |
| **↻** | Botón | Re-fetch manual |

---

# 📊 Tab Resumen

## Sección KPIs (4 tarjetas)

| KPI | Fórmula | Edge case |
|---|---|---|
| **Ingresos del mes** | `ingreso_total_ars` | — |
| **Gasto variable** | `gastado_necesidades + gastado_deseos` | Sub: `% del ingreso` |
| **Disponible** | `disponible_para_gastar` | Rojo si negativo, "presupuesto excedido" |
| **Ahorro estimado** | `max(0, ingreso − gastoVariable − compromisosTC)` | Tasa = `ahorro / ingreso × 100` |

## Sección Presupuesto (3 barras)

| Línea | Gastado | Total | % | Color |
|---|---|---|---|---|
| 🏠 Necesidades | `gastado_necesidades` | `presupuesto_necesidades` | `min(100, g/t × 100)` | Verde < 75%, naranja 75-94%, rojo ≥ 95% |
| 🎯 Deseos | `gastado_deseos` | `presupuesto_deseos` | idem | idem |
| 💚 Ahorro | `ahorro_real` | `presupuesto_ahorro` | idem | idem |

## Sección Billeteras

Una grilla 2 columnas con todas las billeteras de la tabla `billeteras`. Cada celda:
```
NOMBRE
$saldo
[sub-info si aplica]
```

**Caso especial — "Reserva Tarjetas":**
- En vez de mostrar `saldo_actual`, muestra **el total a pagar el próximo mes** (suma de cuotas que continúan).
- Sub-info: "prox. mes · N compromisos" + USD si hay.
- Esto es para que veas cuánto deberías tener apartado.

## Sección Gastos del mes (lista)

- Origen: `gastos_mes[]`
- Agrupados por fecha (`fmtD`)
- Cada item: ícono + descripción + categoría + badge método + monto en rojo
- Total y conteo arriba a la derecha

## Sección Compromisos tarjeta

| Métrica | Cálculo |
|---|---|
| **Cuotas este mes** | `compromisos_tc` (suma cuotas ARS) + `Σ cuotaUSD × tc_blue` |
| **Deuda pendiente total** | `Σ cuota × max(0, total − cuota_actual)` para todos los compromisos |
| **Por tarjeta** | Agrupado por nombre de tarjeta — count, suma mensual, deuda restante |

**Filtro fijo:** se excluyen compromisos cuya descripción contiene `HERMANO` (entre tarjetas familiares).

---

# 💸 Tab Gastos

Vista detallada con búsqueda y filtros.

## Header
- **Título:** mes actual ("Abril 2026")
- **Sub:** cantidad de registros + "(filtrado)" si aplica
- **Total:** suma de los gastos visibles

## Filtros

| Control | Acción |
|---|---|
| 🔍 Búsqueda | Filtra por substring en `desc` |
| Categoría | Select dinámico de categorías presentes |
| Método | Select dinámico de métodos presentes |
| Limpiar | Reset de los 3 |

## Lista
Grupos por día con total diario. Cada gasto muestra ícono de categoría, descripción truncada, badge método de pago, y monto en rojo.

---

# 📈 Tab Análisis

4 cuadrantes con gráficos (Chart.js v4). Se renderiza la primera vez que abrís la tab.

## Cuadrante 1 — Gasto por categoría
- Barras horizontales sorteadas por monto desc
- Origen: agregación local de `gastos_mes[]` por `categoria`
- 8 colores cíclicos

## Cuadrante 2 — Necesidades vs Deseos (donut)
- 2 segmentos: `gastado_necesidades` vs `gastado_deseos`
- Leyenda con %

## Cuadrante 3 — Evolución mensual
- Stacked bar de últimos 5 meses (incluye el actual)
- Series: Necesidades / Deseos / Ahorro
- Origen: `historial_meses[]` (tabla `presupuesto_mensual`)

## Cuadrante 4 — Presupuestado vs Gastado
- Barras agrupadas (presupuestado en gris vs gastado en color)
- 3 categorías: Necesidades, Deseos, Ahorro

---

# 💳 Tab Tarjetas

## KPIs (3 tarjetas)

| KPI | Cálculo |
|---|---|
| **Cuotas este mes** | Σ cuotas ARS + Σ cuotasUSD × tc_blue |
| **Próximo mes (est.)** | Σ cuotas con `cuota_actual < total` (las que continúan) |
| **Deuda pendiente total** | Σ cuota × cuotas_restantes |

## Detalle por tarjeta

Una sección por tarjeta (Galicia, Naranja, Black) con:
- Header: badge tarjeta + "N cuotas" + total mensual + USD/mes si hay
- Lista de items: descripción + cuota X/Y + monto cuota + monto pendiente
- USD se muestra como `U$D X (=$Y)` para mostrar conversión

**Origen:** `compromisos[]` filtrado (sin "HERMANO" ni "REINTEGRO"), agrupado por tarjeta.

---

# 📅 Tab Servicios

El más complejo. Desde Fase 2 incluye check de pago + ABM.

## KPIs (4 tarjetas)

| KPI | Cálculo | Notas |
|---|---|---|
| **Vencidos** | Servicios con `dia_vencimiento < hoy` AND no pagado | Cuenta global, NO se filtra |
| **Esta semana** | Servicios con `dia_vencimiento − hoy ∈ [0..3]` AND no pagado | idem |
| **Pagados** | Cantidad pagada del mes + monto abonado | `Σ COALESCE(monto_real, monto_estimado × tc_si_USD)` |
| **Total mensual** | `Σ monto_estimado × tc_si_USD` (egreso bruto del mes) | Sub-line: "tu parte: $Y" si hay servicios compartidos |

## Filtros

| Control | Función |
|---|---|
| 🔍 Búsqueda | Por nombre o proveedor |
| Pills [Todos / Pendientes / Pagados] | Filtro de estado |
| Tipo | servicio / impuesto / suscripcion / etc. |
| Proveedor | Naturgy, EDET, Personal, etc. |
| Método | Galicia, Naranja, etc. |
| Limpiar | Reset |
| Badge `N / 25` | Contador visible del filtro |
| **+ Nuevo** | Abre modal vacío |

## Lista — secciones por urgencia

```
⚠️ Vencidos       (rojo)   — días pasados sin pagar
🔥 Vence en 3 días (naranja) — días 0-3 desde hoy
📅 Próximos 10 días (azul)
🚗 Este mes        (gris)   — más de 10 días o sin vencimiento fijo
✅ Pagados este mes (verde)
```

Cada fila contiene:
| Elemento | Origen |
|---|---|
| **Check ⭕/✅** | `pagado` (boolean) — click toggle |
| **Nombre** | `nombre` (color rojo si vencido, naranja si urgente) |
| **Proveedor** | `proveedor` |
| **Día X** | `dia_vencimiento` o "Sin vencimiento fijo" |
| **Badge método** | `metodo_pago` con color según tarjeta |
| **Badge X% propio** | Si `porcentaje_propio < 100` |
| **Monto principal** | `monto_estimado` (egreso real, no la parte de Luis) |
| **Sub: ~$X** | Conversión a ARS si moneda USD |
| **Sub: tu parte: $Y** | `monto_luis = monto_estimado × porcentaje_propio / 100` (si compartido) |
| **Sub: a cobrar: $Z** | `monto_estimado − monto_luis` (si compartido y no pagado) |
| **Sub: ✓ fecha · $X** | Si pagado, fecha real y monto_real |
| **Lápiz ✏️** | Aparece al hover — abre modal de edición |

## Modal de pago (al hacer check)

Se abre cuando tocás el círculo de un servicio NO pagado:

```
┌─────────────────────────────┐
│ Hostinger                    │
│ Estimado: $37.188            │
│                              │
│ Monto total pagado (ARS)     │
│ [$37.188_____________]       │
│                              │
│ Método de pago               │
│ [Galicia ▼]                  │
│                              │
│   [Cancelar] [✅ Confirmar]  │
└─────────────────────────────┘
```

Al confirmar:
1. POST a `/webhook/pagar-servicio` con `{servicio_id, monto_real, moneda, metodo_pago, periodo}`
2. Backend: UPSERT pagos_servicios + INSERT gastos_variables + UPDATE billeteras (CTE atómico)
3. Frontend: actualiza estado local + re-renderiza
4. Si era servicio ARS, actualiza saldo de billetera operativa también en tab Resumen

## Modal ABM (al hacer click en lápiz o "+ Nuevo")

11 campos en una grilla 2 cols:

| Campo | Tipo | Requerido | Default |
|---|---|---|---|
| **Nombre** | text | ✅ | — |
| **Tipo** | select | — | servicio |
| **Proveedor** | text | — | — |
| **Monto estimado** | number | — | 0 |
| **Moneda** | select ARS/USD | — | ARS |
| **Día vencimiento** | number 1-31 | — | null |
| **Mes (anuales)** | number 1-12 | — | null |
| **Frecuencia** | select | — | mensual |
| **% propio** | number 0-100 | — | 100 |
| **Método pago** | select | — | "" |
| **Quien paga** | text | — | Luis |

Endpoints según modo:
- **Crear:** `POST /webhook/crear-servicio`
- **Editar:** `POST /webhook/actualizar-servicio` (incluye `id`)
- **Eliminar:** `POST /webhook/eliminar-servicio` (soft delete: `activo=false`)

Después de cualquier ABM, se re-fetchea todo el dashboard.

---

# 🧮 Cálculos clave (referencia)

## Disponible para gastar
```
disponible = ingreso − gastado_necesidades − gastado_deseos − compromisos_tc − reserva
```
(El cálculo real está en BD; este es el modelo conceptual.)

## Tasa de ahorro estimada
```
ahorroEst = max(0, ingreso − gastoVariable − compromisosTC)
tasa = ahorroEst / ingreso × 100
```

## Servicios — tu parte real vs egreso bruto
```
egreso_bruto       = Σ monto_estimado (en ARS)
tu_parte_real_mes  = Σ (monto_estimado × porcentaje_propio / 100)
a_cobrar_familia   = egreso_bruto − tu_parte_real_mes
```

## Conversión USD → ARS
```
monto_ars = monto_usd × tc_blue   (tc actual del mes)
```

---

# 📦 Tablas Supabase referenciadas

Schema: `finanzas_personales`

| Tabla | Uso en PWA |
|---|---|
| `presupuesto_mensual` | Datos del mes actual + historial |
| `gastos_variables` | Lista de gastos del mes |
| `categorias_gasto` | Para iconos y nombres |
| `compromisos_tarjeta` | Cuotas activas |
| `billeteras` | Saldos |
| `tipos_billetera` | Nombres de billeteras |
| `tipo_cambio` | TC blue para conversiones |
| `servicios_recurrentes` | Maestro de servicios + ABM |
| `pagos_servicios` | Estado de pago por mes |
| `ingresos` | (no consumido por PWA todavía) |

---

# 🔁 Flujos completos

## Flujo: marcar servicio como pagado

```
1. PWA: click ⭕ → Modal abre con monto pre-llenado
2. PWA: usuario edita monto si difiere → click ✅ Confirmar
3. PWA: POST /pagar-servicio con {servicio_id, monto_real, moneda, metodo_pago, periodo}
4. n8n: Webhook → Code (validación) → Postgres (CTE atómico):
   a) UPSERT pagos_servicios SET pagado=true, monto_real, fecha=hoy
   b) INSERT gastos_variables (descripción "Servicio: X", monto convertido a ARS)
   c) UPDATE billeteras (resta monto_real a la operativa, solo si moneda=ARS)
5. n8n: Respond { ok, pago_id, monto, gasto_id, nuevo_saldo_operativo }
6. PWA: actualiza DATA.servicios local, re-renderiza tab Servicios
7. PWA: si nuevo_saldo_operativo viene, actualiza billetera y re-renderiza tab Resumen
```

## Flujo: crear servicio nuevo

```
1. PWA: click "+ Nuevo" → Modal vacío
2. PWA: usuario completa form → Guardar
3. PWA: POST /crear-servicio con todos los campos
4. n8n: Webhook → Code (escape de strings, default tipo/freq) → Postgres INSERT
5. n8n: Respond { ok, id, nombre }
6. PWA: cierra modal → fetchData() → todo se re-renderiza
```

## Flujo: registrar gasto vía WhatsApp

```
1. Luis manda audio o texto a WhatsApp
2. Evolution API → /webhook/router-wa (Enrutador)
3. Si remitente es Luis (5493814690975) → /webhook/asistente-financiero
4. Si es audio: download → Whisper → transcripción
5. Agente Financiero (GPT-4.1) recibe: mensaje + system prompt (con FECHA ACTUAL)
6. LLM decide qué tool llamar:
   - registrar_gasto si hay descripción + monto + método
   - consultar_X si pregunta
7. Tool ejecuta query Postgres
8. LLM formatea respuesta según prompts ("✅ Descripción — $monto")
9. Response → YCloud API (5493815762656) → WhatsApp respuesta
```

---

# 🎨 Convenciones visuales

| Color | Significado |
|---|---|
| 🔴 Rojo | Vencido / pasado / problemático |
| 🟠 Naranja | Esta semana / atención |
| 🔵 Azul | Próximo / informativo |
| 🟢 Verde | Pagado / OK / disponible |
| 🟣 Púrpura | Total mensual / agregado |
| 🌊 Teal | USD / monto en dólar |
| ⚪ Gris | Sin urgencia |

---

# 📍 Versión actual del PWA

- **URL:** https://finanzas-pwa-885.netlify.app
- **Service Worker:** `finanzas-v9` (al 2026-04-29)
- **Auto-deploy:** push a `master` en GitHub `luis171190/finanzas-pwa`
- **Dependencies:** Chart.js 4.4.0 (CDN), no build step
