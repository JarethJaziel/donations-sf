# Antigravity & Agent Instructions: Mexico Dreamin 2026 Donation Portal

Este repositorio cuenta con reglas estrictas de arquitectura, seguridad y desarrollo con Salesforce y Stripe.

## Reglas Principales y Mínimos Críticos
- Consulta las reglas detalladas y requisitos en [`.agents/rules/donation-portal.md`](./.agents/rules/donation-portal.md) o [`GEMINI.md`](./GEMINI.md).
- **M1:** 100% Modo de prueba (Sandbox Org y Stripe Test Mode). Prohibido datos reales.
- **M2:** Menor privilegio en Guest User Profile. Prohibido acceso CRUD directo a `Donacion__c`. Exponer únicamente Wrapper/DTOs en Apex.
- **M3:** Cero secretos en código o historial de Git. `Stripe_Config__c` se configura en la Org.

## Documentación Obligatoria
- Toda sesión relevante debe registrarse en [`docs/bitacora_ia.md`](./docs/bitacora_ia.md) (Criterio C3).
- Las dudas y acuerdos de negocio se registran en [`docs/preguntas_y_reportes.md`](./docs/preguntas_y_reportes.md) (Criterio C7).
