# Registro de Preguntas al Cliente y Reportes Técnicos

> **Regla (Criterio C7):** Cada integrante debe registrar al menos **4 entradas propias en al menos 2 semanas distintas**, cumpliendo siempre las **5 partes obligatorias** y agregando qué pasó después de recibir respuesta.

## Entradas de Discovery y Reportes

### Entrada #1 — Discovery sobre Donantes con Factura y Límites de Campaña
- **Fecha:** 2026-11-04
- **Autor:** Jareth Moo
- **Tipo:** Pregunta de Negocio al Cliente (Profesor)
1. **Qué intentábamos lograr (Historia y Criterio):** Definir los criterios de aceptación de `US-01` (`RF-D1a`), `US-04` (`RF-C1`), `US-05` (`RF-F1`), `US-06` (`RF-D3`) y `US-08` (`RF-D5`) respecto a las preguntas abiertas de la guía.
2. **Qué hicimos (Pasos concretos):** Analizamos los requisitos de la sección 4, identificamos 4 ambigüedades de negocio (visibilidad pública de donantes con factura, sobrecupo/vigencia de campañas, sesiones pendientes abandonadas y datos mínimos del comprobante fiscal/recibo) y consultamos al cliente.
3. **Qué esperábamos que pasara:** Obtener reglas de negocio cerradas para traducirlas en criterios *Dado / Cuando / Entonces* verificables.
4. **Qué pasó (Respuesta / Hallazgo):** El cliente definió: (1) Donante con factura aparece siempre en el reconocimiento público (solo nombre y monto); (2) Campañas vencidas por fecha se cierran definitivamente y cada campaña tiene un flag para permitir o no superar el 100% de la meta; (3) Las donaciones pendientes siguen el ciclo nativo de Stripe; (4) El comprobante varía según la modalidad elegida.
5. **Qué consultamos con la IA o documentación y qué resultó:** Validamos con IA los requisitos fiscales de CFDI 4.0 para donativos y el ciclo de vida de `checkout.session` en la documentación de Stripe.
- **Qué hicimos después (Resolución):** Actualizamos las historias `US-01`, `US-04`, `US-05`, `US-08` y `US-09` en GitHub Projects e incluimos los campos `Fecha_Fin__c` y `Permitir_Sobrecupo__c` en el diseño de `Campana__c`.

---

## Plantilla para Nuevas Entradas (Copiar y Pegar)

### Entrada #X — [Título descriptivo de la duda o bloqueo técnico]
- **Fecha:** `YYYY-MM-DD`
- **Autor:** `[Nombre del integrante]`
- **Tipo:** `[Pregunta de Negocio al Cliente / Reporte de Bloqueo Técnico]`
1. **Qué intentábamos lograr (Historia y Criterio):** `[US-XX / RF-XX y criterio específico]`
2. **Qué hicimos (Pasos concretos):** `[Pasos detallados ejecutados antes de preguntar]`
3. **Qué esperábamos que pasara:** `[Resultado esperado]`
4. **Qué pasó (Respuesta / Hallazgo / Error exacto):** `[Comportamiento observado o respuesta del cliente]`
5. **Qué consultamos con la IA o documentación y qué resultó:** `[Fuentes oficiales o prompts revisados]`
- **Qué hicimos después (Resolución):** `[Cambio aplicado en código, diseño o historias]`
