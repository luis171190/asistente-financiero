# 💰 Asistente Financiero Personal — n8n + WhatsApp + IA

> Agente conversacional via WhatsApp para registrar gastos en tiempo real, clasificarlos automaticamente con IA y consultar reportes via dashboard PWA. Sin formularios, sin apps extra: solo un mensaje de WhatsApp.

## 🎯 Problema que resuelve

Llevar las finanzas personales requiere disciplina de registro. Las apps de finanzas fallan porque el roce es alto: hay que abrirlas, navegar menus, tipear categorias. La tasa de abandono es enorme.

Este sistema baja el roce a cero: manda un mensaje al WhatsApp del agente — *"cafe 2500 efectivo"*, *"super 18750 visa"*, *"cuanto gaste en comida este mes?"* — y el sistema lo procesa de forma natural.

## 🛠️ Stack

- **Orquestacion**: n8n self-hosted (Docker Swarm + Portainer)
- **LLM**: GPT-4 / Claude Sonnet (intercambiable via `LLM_PROVIDER` env)
- **Mensajeria**: WhatsApp Business via Evolution API
- **Datos**: Postgres (Supabase self-hosted)
- **Frontend**: PWA vanilla (HTML + JS + Chart.js) — [finanzas-pwa](https://github.com/luis171190/finanzas-pwa)
- **Memoria del agente**: PostgresChatMemory (n8n langchain)

## 🏗️ Arquitectura

```
WhatsApp -> Evolution API -> n8n Router -> Asistente Financiero
                                              |
                                    11 tools disponibles
                                              |
                                         Postgres
                                              |
                              Dashboard PWA (endpoint /dash-data)
```

Cuatro workflows desacoplados:

| Workflow | Responsabilidad |
|---|---|
| **Enrutador para Webhook** | Recibe todo de Evolution API, filtra por numero, distribuye |
| **Asistente Financiero** | Cerebro conversacional (LLM + tools) con memoria persistida |
| **Motor Financiero** | Operaciones de datos puras: insert, update, queries analiticas. Reutilizable |
| **API Dashboard** | Endpoint HTTP que el dashboard PWA consume para charts y metricas |

## 📊 Resultados

- **Registro diario sostenido**: el formato conversacional reduce el roce de registro al minimo — mensaje de WhatsApp vs abrir app, buscar categoria, confirmar
- **Clasificacion automatica**: el LLM categoriza correctamente el 95%+ de los gastos sin intervencion manual
- **Consultas en lenguaje natural**: "cuanto gaste en comida este mes", "promedio diario esta semana", "top 3 categorias" — sin SQL, sin filtros

## 💡 Decisiones tecnicas destacadas

**Separacion Asistente / Motor**: el Asistente solo razona, el Motor solo ejecuta SQL. Permite cambiar el modelo de LLM o ajustar el prompt sin tocar la logica de datos, y reutilizar el Motor desde otros entry points (voicebot, Telegram, API externa).

**Router multi-tenant**: el Enrutador filtra por numero de WhatsApp origen. Multiples casos de uso conviven en la misma instancia n8n + Evolution API con costo marginal por usuario adicional practicamente nulo.

**Memoria persistida en Postgres**: la sesion conversacional sobrevive a reinicios de n8n y permite analizar historiales de conversacion para debug o mejora del prompt.

**Sin frontend pesado**: el dashboard es una PWA estatica que consume el webhook `/dash-data` — deployable en Netlify sin backend propio.

## 🚀 Como correrlo

1. Levantar n8n self-hosted (`docker-compose` con imagen oficial).
2. Configurar credenciales en n8n: Postgres, OpenAI/Anthropic, Evolution API.
3. Importar los 4 workflows JSON desde `./` a tu instancia n8n.
4. Copiar `.env.example` a `.env.local` y completar.
5. En Evolution API, registrar el webhook entrante -> `https://tu-n8n.example.com/webhook/router-wa`.
6. (Opcional) Deployar [finanzas-pwa](https://github.com/luis171190/finanzas-pwa) y apuntarlo al endpoint `/dash-data`.

## 📁 Estructura

```
.
+-- Enrutador para Webhook.json      # Router por numero WA
+-- Asistente Financiero.json        # Agente LLM con 11 tools
+-- Motor Financiero.json            # Operaciones DB desacopladas
+-- API Dashboard.json               # Endpoint para PWA
+-- .env.example                     # Template de variables
+-- README.md
```

## Estado

Sistema personal en uso productivo desde abril 2026. El codigo se publica como showcase tecnico — los datos y credenciales han sido removidos del historial.

## Autor

**Luis Molina Reinoso** — AI & Automation Engineer  
San Miguel de Tucuman, Argentina  
[LinkedIn](https://linkedin.com/in/luis-molina-171190) · [GitHub](https://github.com/luis171190)
