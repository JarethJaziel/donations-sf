# SF Vibe Lab — Mexico Dreamin 2026 Donation Portal

A 100% Salesforce-hosted solution (Experience Cloud, LWC, Apex, Flows) integrated with **Stripe Checkout Sessions** and **Webhooks** in Test Mode to manage student sponsorship campaigns toward **Mexico Dreamin 2026**.

---

## Project Board & Backlog (GitHub Projects)

Tracking for the User Stories (`US-01` to `US-17`), acceptance criteria, 4-member team assignments, and delivery evidence is managed at:

👉 **[GitHub Projects Board #7](https://github.com/users/JarethJaziel/projects/7)**

---

## Delivery 1 (`entrega-1`)

| Item | Link |
|---|---|
| Public site (no login) | https://uady--class2026d.sandbox.my.site.com/md2026/ |
| Functional demo video (5 min) | https://www.youtube.com/watch?v=iNPcFQLaQjI |
| Backlog board | [GitHub Projects Board #7](https://github.com/users/JarethJaziel/projects/7) |
| Security & personal data | [`docs/seguridad.md`](./docs/seguridad.md) |
| AI log | [`docs/bitacora_ia.md`](./docs/bitacora_ia.md) |
| Contribution log | [`docs/contribucion.md`](./docs/contribucion.md) |
| Questions & reports log | [`docs/preguntas_y_reportes.md`](./docs/preguntas_y_reportes.md) |
| Evidence screenshots | [`docs/evidencias/`](./docs/evidencias/) |
| Metadata backup | [`force-app/`](./force-app/) |

> Payments run only in **Stripe Test Mode** with test cards and fictitious donors (M1). No real money is involved.

---

## Progress

### How progress is calculated

- **Unit of measure: user stories (count-based).** The backlog does not use story points, so every story weighs the same. Progress = stories **done** ÷ stories **in scope** × 100.
- **Done means verified, with no partial credit.** A story counts as done only when **all** its acceptance criteria (minimum and team-defined) are demonstrated with evidence (video, screenshot or reproducible test) in the test scenario, without breaking a minimum (M1–M3). A partially working story counts as not done.
- **Scope per milestone.** Each story belongs to the milestone of the requirement (RF) it covers:
  - **Delivery 1 %** = done stories that cover Delivery 1 requirements ÷ all stories that cover Delivery 1 requirements.
  - **Delivery 2 %** = done stories ÷ **all** stories in the backlog (Delivery 1 + Delivery 2).
- **Source of status:** the *Status* and *Evidence* fields of the backlog board on the delivery date. Cancelled stories would be excluded from the denominator (there are none).

### Delivery 1 — 100% (12 / 12)

`████████████████████` **12 of 12** stories covering Delivery 1 requirements are done.

| Story | RF | Status | Evidence |
|---|---|---|---|
| US-01 · Browse active campaigns, progress and eligibility | RF-D1a | ✅ Done | [screenshot](./docs/evidencias/portal-actual/US-01_campanas_avance_y_estado.png) |
| US-03 · Anonymous donation | RF-D2 | ✅ Done | [screenshot](./docs/evidencias/portal-actual/US-03_modalidad_anonima.png) |
| US-04 · Public recognition wall | RF-C1 | ✅ Done | [screenshot](./docs/evidencias/portal-actual/US-04_muro_donantes.png) |
| US-05 · Invoice data with SAT RFC pattern | RF-F1 | ✅ Done | [screenshot](./docs/evidencias/portal-actual/US-05_rfc_invalido.png) |
| US-06 · Pending donation registered before payment | RF-D3 | ✅ Done | [screenshot](./docs/evidencias/portal-actual/US-06_donacion_pendiente_salesforce.png) |
| US-07 · Thank-you page | RF-D4 | ✅ Done | [screenshot](./docs/evidencias/entrega-1/US-07%20%C2%B7%20View%20Thank-You%20Page%20After%20Returning%20from%20Payment%20Gateway.jpg) |
| US-09 · Manage campaigns | RF-S1 | ✅ Done | [screenshot](./docs/evidencias/entrega-1/US-09_campana_creada_admin.png) |
| US-10 · View all donations | RF-S2 | ✅ Done | [screenshot](./docs/evidencias/entrega-1/US-10_todas_las_donaciones.png) |
| US-11 · Flag and filter invoice requests | RF-F2 | ✅ Done | [screenshot](./docs/evidencias/entrega-1/US-11%20Visualizaci%C3%B3n%20filtrado%20por%20factura.png) |
| US-12 · Manual payment confirmation and receipt | RF-S3 | ✅ Done | [screenshot](./docs/evidencias/entrega-1/US-12_confirmar_pago_manual.png) |
| US-14 · Public, login-free portal | RF-V1 | ✅ Done | [screenshot](./docs/evidencias/portal-actual/US-14_portal_publico_sin_login.png) |
| US-15 · Guest security test | RF-V2 | ✅ Done | [`docs/seguridad.md`](./docs/seguridad.md) |

**Calculation:** 12 done ÷ 12 in scope × 100 = **100%**.

### Full backlog snapshot (toward Delivery 2) — 80% (16 / 20)

`████████████████░░░░` Stories that cover Delivery 2 requirements were started early. This snapshot applies the same rule to the whole backlog.

| Story | RF | Status | Evidence |
|---|---|---|---|
| US-02 · Donate a custom amount | RF-D1b | ✅ Done | [screenshot](./docs/evidencias/portal-actual/US-02_monto_libre.png) |
| US-08 · Automatic confirmation and email receipt | RF-D5 | ✅ Done | [screenshot](./docs/evidencias/entrega-1/US-08_donacion_pagada_automatica.png) |
| US-13 · Audit automatic confirmations and rejected notices | RF-S4 | ✅ Done | [screenshot](./docs/evidencias/entrega-1/US-13_US-16_avisos_pasarela.png) |
| US-16 · Receive the gateway notification | RF-V3a | ✅ Done | [screenshot](./docs/evidencias/entrega-1/US-16_stripe_webhook_200.png) |
| US-17 · Authentic notices only, no duplicates | RF-V3b | ⏳ Not counted yet (evidence pending) | — |
| US-18 · Browse completed campaigns | — | ⬜ To do | — |
| US-19 · Moderate public donor names | — | ⬜ To do | — |
| US-20 · Simulated invoice by email | — | ⬜ To do | — |

**Calculation:** (12 Delivery 1 stories + 4 Delivery 2 stories done) ÷ 20 stories × 100 = **80%**.

---

## Project Structure

- [`GEMINI.md`](./GEMINI.md) and [`CLAUDE.md`](./CLAUDE.md): System rules, business context, critical minimums (`M1`, `M2`, `M3`), and coding standards (`C6`).
- [`docs/bitacora_ia.md`](./docs/bitacora_ia.md): Mandatory chronological log of AI interactions (**Criterion C3 — 20 pts**).
- [`docs/preguntas_y_reportes.md`](./docs/preguntas_y_reportes.md): Client discovery log and technical reports (**Criterion C7 — 15 pts**).
- [`docs/contribucion.md`](./docs/contribucion.md): Contribution log, one table per milestone (**Criterion C9**).
- [`docs/seguridad.md`](./docs/seguridad.md): Guest security test, guest permissions, secret handling, personal data classification and known risks (**Criterion C5**).
- [`docs/evidencias/`](./docs/evidencias/): Evidence screenshots per user story.
- [`docs/arquitectura_y_decisiones.md`](./docs/arquitectura_y_decisiones.md): Sequence diagram and ADRs (single-transaction Checkout with opaque reference, Guest User security `M2`, and protected secrets `M3`).
- [`docs/plan_pruebas_y_seguridad.md`](./docs/plan_pruebas_y_seguridad.md): Critical minimums checklist and functional/negative test matrix.
- [`force-app/main/default/objects/`](./force-app/main/default/objects/):
  - `Campana__c`: Sponsorship campaigns (`Meta__c`, `Monto_Recaudado__c` Roll-Up Summary filtered by `Estado__c = 'Pagada'`, `Activa__c`, `Fecha_Fin__c`, `Permitir_Sobrecupo__c`).
  - `Donacion__c`: Donation records (`Modalidad__c`, `Estado__c`, `Monto__c`, `Correo__c`, `Nombre_Donante__c`, `RFC__c`, `Solicita_Factura__c`, `Stripe_Session_Id__c`, `Tipo_Confirmacion__c`, `Comprobante_Enviado__c`) and their validation rules.
  - `Aviso_Pasarela__c`: Audit and idempotency log for Stripe Webhooks (`Stripe_Event_Id__c`, `Estado_Aviso__c`, `Motivo_Rechazo__c`, `Fecha_Recepcion__c`, `Donacion__c`).
  - `Stripe_Config__c`: **Protected** Hierarchy Custom Setting to store keys and URLs in the Org without ever exposing them in code or Git (`M3`).
- [`force-app/main/default/remoteSiteSettings/Stripe_API.remoteSite-meta.xml`](./force-app/main/default/remoteSiteSettings/Stripe_API.remoteSite-meta.xml): Callout authorization to `https://api.stripe.com`.

---

## Quick Guide: Org Authentication & Deployment

### 1. Authenticate Your Org (Sandbox or Developer Edition)

For a Sandbox (such as `<org-alias>` / `<sandbox-username>`):

```bash
sf org login web --instance-url https://test.salesforce.com --alias <org-alias> --set-default
```

_(For a Developer Edition or production org, omit `--instance-url` or use `https://login.salesforce.com`.)_

### 2. Deploy the Data Model and Base Configuration

```bash
sf project deploy start --source-dir force-app
```

### 3. Manually Configure `Stripe_Config__c` in Salesforce Setup (Minimum M3)

1. In your Org, go to **Setup** -> **Custom Settings**.
2. Click **Manage** next to **Stripe Config**.
3. Click **New** (at the *Default Organization Level Value* level) and enter the test values from your Stripe Sandbox account (`Secret_Key__c`, `Webhook_Secret__c`, `Success_URL__c`, `Cancel_URL__c`).
   > **IMPORTANT (M3):** Never store or write live or test keys in repository files.
