# Asistente Financiero Personal

## Descripcion
Sistema de finanzas personales basado en n8n con AI Agent (OpenAI GPT-4.1)
y notificaciones WhatsApp via YCloud API.
Dashboard PWA: https://finanzas-pwa-885.netlify.app

## Stack
- n8n (ssn8n.myaivaro.com)
- PostgreSQL schema: finanzas_personales (Supabase)
- OpenAI API — GPT-4.1 (AI Agent) + Whisper (transcripcion audio)
- YCloud API (WhatsApp — numero 5493815762656, respuesta outbound)
- Evolution API (WhatsApp — entrada/webhook de mensajes de Luis)
- DolarApi.com (tipo de cambio blue diario)

## Arquitectura actual (reconstruida 2026-04-07)

4 workflows activos en n8n:

| Workflow | ID | Rol |
|---|---|---|
| Enrutador para Webhook | tdjSWrSplaOfsfO4 | Recibe Evolution API, filtra por numero de Luis |
| Asistente Financiero | MRW99xAuOv5kVtHS | AI Agent principal (GPT-4.1 + 11 tools PostgreSQL + Whisper) |
| Motor Financiero | QP4sGT61smMGJU2m | Cron 09:00 diario — centraliza 6 tareas automaticas |
| API Dashboard | E0AwewlJN2GKMDzF | GET /webhook/dash-data — sirve datos al PWA Netlify |

## AI Agent — Tools PostgreSQL (11)
1. registrar_gasto
2. consultar_gastos_recientes
3. eliminar_gasto
4. registrar_ingreso_extra
5. actualizar_billetera
6. consultar_resumen_completo
7. consultar_presupuesto
8. consultar_compromisos_tc
9. consultar_pago_tarjetas
10. consultar_vencimientos_proximos
11. simular_cuotas

## Motor Financiero — Tareas automaticas
| Cuando | Tarea |
|---|---|
| Diario 09:00 (siempre) | Fetch + guardar tipo de cambio blue |
| Diario 09:00 (siempre) | Alerta vencimientos proximos 3 dias (si los hay) |
| Cada lunes 09:00 | Resumen semanal por WhatsApp |
| Dia 25 de cada mes | Recordatorio liquidacion (sueldo + reserva tarjetas) |
| Dia 1 de cada mes | Cierre mes anterior + preparar presupuesto nuevo + avanzar cuotas |

## Schema BD — finanzas_personales
Tablas: gastos_variables, categorias_gasto, gastos_fijos, compromisos_tarjeta,
        presupuesto_mensual, billeteras, tipos_billetera, historial_billeteras,
        tipo_cambio, ingresos, configuracion
Vistas: vista_resumen_completo
Funciones: registrar_gasto(), obtener_tc()

## Credenciales (configuradas en n8n)
- postgres (BD Supabase) — id: c5vJmoXD1JooCpKG
- openAiApi (OpenAi account) — id: doxD8wCrP7dw8oHa
- httpHeaderAuth (YCloud Cuenta) — id: pFmujxRRv8RAE6kX

## Flujo de mensaje
```
Evolution API (WhatsApp)
  -> /webhook/router-wa (Enrutador)
  -> [si es Luis: 5493814690975]
  -> /webhook/asistente-financiero
  -> [audio?] -> Whisper -> texto
  -> GPT-4.1 + 11 tools PostgreSQL
  -> YCloud API -> WhatsApp (respuesta)
```

## Convenciones
- Nombres de workflows con emoji + descripcion
- SQL: schema finanzas_personales, CTEs, funciones almacenadas
- Motor Financiero notifica por WhatsApp al finalizar cada tarea
- `from` YCloud hardcoded: 5493815762656 (en 5 nodos del Motor + Asistente)

## Pendientes conocidos
- Tarea "Actualizacion de Inversiones" eliminada en reconstruccion — no tiene rama en Motor Financiero
- Funcion `puedo_comprar()` en BD: posiblemente obsoleta, no invocada en ningun workflow
- Valores de columna `tarjeta` en compromisos_tarjeta: naming inconsistente (snake_case vs legible)
- Provider selector WhatsApp: el Asistente siempre responde por YCloud aunque el mensaje entro por Evolution

## Comandos utiles
- Validar workflow: usar n8n-mcp validate_workflow
- Ver ejecuciones: usar n8n-mcp n8n_executions
- Dashboard: https://finanzas-pwa-885.netlify.app
- API Dashboard endpoint: https://ssn8n.myaivaro.com/webhook/dash-data
