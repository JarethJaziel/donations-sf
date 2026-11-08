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

### Entrada #2 — Auditoría de exposición de secretos, backlog y contradicciones
- **Fecha:** 2026-11-08
- **Autor:** Mauricio Dzay
- **Tipo:** Reporte de Hallazgo Técnico / Planeación
1. **Qué intentábamos lograr (Historia y Criterio):** Confirmar el mínimo `M3` (ninguna llave de Stripe en el código ni en el historial) y que el backlog cubra todos los RF de la sección 4 de la guía y todas las respuestas del cliente (`C4`), antes de la Entrega 1.
2. **Qué hicimos (Pasos concretos):** Revisamos los 13 commits de todas las ramas con `git log --all -p` y expresiones regulares (`sk_`, `pk_`, `rk_`, `whsec_`, `force://`, tokens de sesión), además de renombres, stash, objetos huérfanos y `.gitignore`. Comparamos los issues `US-01` a `US-17` y el tablero contra la guía y contra las respuestas del cliente.
3. **Qué esperábamos que pasara:** Cero secretos en el historial, una historia para cada RF y ninguna respuesta del cliente sin reflejar en el backlog.
4. **Qué pasó (Respuesta / Hallazgo / Error exacto):** No hay llaves en el historial (`M3` se cumple) y los 17 RF están cubiertos. Sin embargo:
   - Hay 4 contradicciones entre la guía y el cliente:
     - Registro Pendiente antes de pagar (`RF-D3`) vs. "crear el registro solo después de un pago exitoso".
     - Meta editable (`RF-S1` CA2) vs. "no cambiar la meta de una campaña activa".
     - Sin CFDI (`RF-F1` CA3) vs. "quien pida factura debe recibirla".
     - Comprobante propio (`RF-D5`) vs. "basta el correo de la pasarela".
   - Faltaban en el backlog respuestas del cliente:
     - fecha de inicio, imagen y propósito de la campaña;
     - vista de campañas terminadas;
     - nombre público elegido por el donante y moderación;
     - montos sugeridos hasta $20,000, confirmación desde $1,000 y mínimo de la pasarela.
   - Riesgos técnicos:
     - el webhook marca como pagada una donación ante cualquier evento firmado, sin revisar el tipo de evento;
     - un método público recibe el Id de la donación;
     - el comprobante se marca como enviado aunque falle el correo.
   - El tablero no tiene campo "Hito", y los campos ID y Evidencia están vacíos.
5. **Qué consultamos con la IA o documentación y qué resultó:** Claude Code (Claude Opus 5.5) generó el reporte de auditoría. Verificamos con la documentación oficial de Stripe tres datos:
   - el mínimo para MXN es $10;
   - los pagos en modo de prueba no envían recibos automáticos;
   - las sesiones de Checkout expiran por defecto a las 24 h (configurable de 30 min a 24 h).
- **Qué hicimos después (Resolución):**
  - Actualizamos `US-01` a `US-17` con criterios nuevos y una sección de decisiones del cliente y preguntas abiertas.
  - Agregamos `US-18`, `US-19` y `US-20` para Entrega 2.
  - Las 4 contradicciones quedaron como decisiones provisionales marcadas *Pending client confirmation* (P1–P4). Cada pregunta se registrará como entrada propia cuando se envíe al cliente.
  - Reescribimos los prompts de los integrantes (guía de ejecución v2), incluido un prompt para corregir el código existente.

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
