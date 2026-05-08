# Asistente Financiero Personal — n8n + IA

> Agente conversacional via WhatsApp para registrar gastos personales en tiempo real, clasificarlos automaticamente con IA y consultar reportes via dashboard PWA.

## Que hace

Mientras vivias el dia, le mandas un mensaje al WhatsApp del agente — *"cafe 2500 efectivo"*, *"super 18750 visa"*, *"cuanto gaste en comida este mes?"* — y el sistema:

1. Clasifica el gasto en categorias (alimentacion, transporte, ocio, etc.) usando un LLM.
2. Persiste el registro en una base de datos (Supabase / Postgres).
3. Devuelve confirmacion contextual ("registrado en alimentacion, llevas 47k este mes en esta categoria").
4. Responde consultas analiticas en lenguaje natural ("gasto del mes pasado", "promedio diario", "top 3 categorias").
5. Expone los datos en un dashboard PWA via webhook HTTP de n8n (los charts consumen el endpoint `/webhook/dash-data`).

## Arquitectura

```
WhatsApp -> Evolution API -> n8n (Router) -> [Asistente Financiero | Otros casos]
                                 |
                                 v
                           Postgres (gastos, memoria conversacional)
                                 |
                                 v
                           Dashboard PWA (consume webhook dash-data)
```

Cuatro workflows desacoplados:

| Workflow | Responsabilidad |
|---|---|
| **Enrutador para Webhook** | Recibe TODO de Evolution API, filtra por numero del usuario destino, distribuye a workflows internos. |
| **Asistente Financiero** | Cerebro conversacional (LLM + tools). Mantiene memoria de la conversacion y delega operaciones DB al Motor. |
| **Motor Financiero** | Operaciones de datos puras: insert gasto, update categoria, queries analiticas. Reutilizable. |
| **API Dashboard** | Endpoint HTTP que el dashboard PWA consume para mostrar metricas y graficos. |

## Stack

- **Orquestacion**: n8n self-hosted (Docker Swarm + Portainer)
- **LLM**: GPT-4 / Claude Sonnet (intercambiable via env)
- **Mensajeria**: WhatsApp Business via [Evolution API](https://evolution-api.com/)
- **Datos**: Postgres (Supabase self-hosted)
- **Frontend**: PWA vanilla (HTML + JS + Chart.js) consumiendo webhook
- **Memoria del agente**: PostgresChatMemory (n8n langchain)

## Decisiones tecnicas destacadas

- **Separacion Asistente / Motor**: el Asistente solo razona, el Motor solo ejecuta. Permite versionar el prompt del agente sin tocar la logica de datos, y reutilizar el Motor desde otros entry points (futuro voicebot, dashboard, telegram).
- **Router multi-usuario**: el Enrutador filtra por numero de WhatsApp para que multiples casos de uso convivan en una sola instancia n8n + Evolution. Bajisimo costo marginal por usuario adicional.
- **Memoria persistida en Postgres**: la conversacion sobrevive reinicios de n8n y permite analisis posterior del estilo conversacional.
- **Sin frontend pesado**: el dashboard es una PWA estatica que solo consume el webhook — desplegable a Netlify/Vercel sin backend propio.

## Como correrlo

1. Levantar n8n self-hosted (cualquier docker-compose oficial sirve).
2. Configurar credenciales en n8n: Postgres, OpenAI/Anthropic, Evolution API.
3. Importar los 4 workflows JSON desde `./` a tu instancia n8n.
4. Copiar `.env.example` a `.env.local` y completar.
5. En Evolution API, registrar el webhook entrante apuntando a `https://tu-n8n.example.com/webhook/router-wa`.
6. (Opcional) Deployar el dashboard PWA y apuntarlo al endpoint `/webhook/dash-data`.

## Estructura

```
.
+-- Enrutador para Webhook.json    # Router por numero WA
+-- Asistente Financiero.json      # Agente LLM + tools
+-- Motor Financiero.json          # Operaciones DB
+-- API Dashboard.json             # Endpoint para PWA
+-- .env.example                   # Template de variables
+-- README.md
```

Los workflows estan exportados en formato n8n, importables directamente desde la UI (`Settings -> Import from File`).

## Estado

Sistema personal en uso productivo desde abril 2026. El codigo se publica como showcase tecnico — los datos y credenciales han sido removidos del historial.

## Autor

Luis Molina Reinoso — AI & Automation Engineer
San Miguel de Tucuman, Argentina
[LinkedIn](https://linkedin.com/in/luis-molina-171190) · [GitHub](https://github.com/luis171190)
