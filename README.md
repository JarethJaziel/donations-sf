# SF Vibe Lab — Mexico Dreamin 2026 Donation Portal

A 100% Salesforce-hosted solution (Experience Cloud, LWC, Apex, Flows) integrated with **Stripe Checkout Sessions** and **Webhooks** in Test Mode to manage student sponsorship campaigns toward **Mexico Dreamin 2026**.

---

## Project Board & Backlog (GitHub Projects)

Tracking for the User Stories (`US-01` to `US-17`), acceptance criteria, 4-member team assignments, and delivery evidence is managed at:

👉 **[GitHub Projects Board #7](https://github.com/users/JarethJaziel/projects/7)**

---

## Project Structure

- [`GEMINI.md`](./GEMINI.md) and [`CLAUDE.md`](./CLAUDE.md): System rules, business context, critical minimums (`M1`, `M2`, `M3`), and coding standards (`C6`).
- [`docs/bitacora_ia.md`](./docs/bitacora_ia.md): Mandatory chronological log of AI interactions (**Criterion C3 — 20 pts**).
- [`docs/preguntas_y_reportes.md`](./docs/preguntas_y_reportes.md): Client discovery log and technical reports (**Criterion C7 — 15 pts**).
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
