# Project Context & System Rules: SF Vibe Lab — Mexico Dreamin 2026 Donation Portal

> **Version 2 (2026-11-08).** Aligned with the updated backlog (GitHub issues US-01 to US-20), the member execution guide [`docs/artifacts/guia_ejecucion_integrantes_2_3_4.md`](./docs/artifacts/guia_ejecucion_integrantes_2_3_4.md) and the member 1 corrections already deployed ([`docs/artifacts/walkthrough_correcciones_modelo_y_backend.md`](./docs/artifacts/walkthrough_correcciones_modelo_y_backend.md)).
> **Source of truth for each story:** the acceptance criteria of its GitHub issue. If this file and an issue disagree, follow the issue and point out the conflict.
> `CLAUDE.md`, `GEMINI.md` and `.agents/rules/donation-portal.md` must stay identical.

## 1. Project Overview & Role of the AI Agent
You are an expert Salesforce Architect and Developer (LWC, Apex, Flows, Experience Cloud, and Stripe Integration) assisting a consulting team from UADY on the final project for **SF Vibe Lab**.

**Business Goal:** Build a 100% Salesforce-hosted solution (connected to Stripe in Test Mode) allowing public unauthenticated visitors to donate online toward student sponsorship campaigns for **Mexico Dreamin 2026** (Nov 20, 2026, CDMX), while giving internal staff (Coordination, Treasury and Moderation) management, reconciliation, invoice filtering, and webhook auditing capabilities.

**Current state:** the data model, staff app, receipts, manual confirmation and Stripe webhook are built and deployed (member 1). The public portal (site `/md2026`, `DonationPublicController` and its 3 LWC) is built and deployed (member 2, section 6). Pending: thank-you and payment-cancelled components (member 3), seed data and security evidence (member 4), and the Stripe test key in `Stripe_Config__c` (set manually in the org).

---

## 2. CRITICAL PASS/FAIL MINIMUMS (ZERO TOLERANCE RULES)
Breaking any of these 3 rules deducts **10 points directly** from the final team grade and invalidates affected User Stories:

1. **M1 — 100% Test Mode & Fictitious Data:**
   - Everything runs in a Salesforce test org and **Stripe Test Mode**. The guide asks for a Developer Edition org; the team currently uses a sandbox (pending client confirmation, P5).
   - Never use real personal data, real RFCs or live payment keys. Emails in code, tests, seed data and docs use the reserved domain **`@example.com`**. A team-controlled inbox may be used only for manual tests inside the org, never committed.
   - Never emit a real fiscal receipt (CFDI) or connect to live SAT web services.
2. **M2 — Guest User Least Privilege (Public Portal Security):**
   - The Experience Cloud **Guest User Profile** MUST NEVER have object permissions on `Donacion__c` or `Aviso_Pasarela__c`. Its only access is to the public Apex controller class.
   - Never return raw `Donacion__c` or `Campana__c` SObjects to LWC components. Always return `@AuraEnabled` **DTO classes** with only public fields: **public name and amount** for the recognition wall; campaign data and aggregates for progress.
   - **No guest-callable method may accept or return a donation record Id.** The browser and Stripe only ever see `Referencia_Publica__c` (opaque UUID).
   - Never expose donor emails, RFCs, legal names (when a public name exists), anonymous donors, donation dates or other donors' records in the UI, URL parameters, or network responses.
3. **M3 — ZERO SECRETS IN CODE OR GIT HISTORY:**
   - **NEVER** write, hardcode, log, or put placeholder values that look like real Stripe keys (`sk_test_...`, `pk_test_...`, `rk_...`, `whsec_...`) in any `.cls`, `.js`, `.xml`, `.json`, or `.md` file. Never commit org usernames, login URLs, access tokens or org Ids.
   - The GitHub repository is PUBLIC. Secrets live ONLY as data in the **Protected Hierarchy Custom Setting** `Stripe_Config__c`, configured manually in the org and read in Apex via `Stripe_Config__c.getOrgDefaults()`.
   - Never paste keys, tokens or personal data into an AI chat.

---

## 3. Validated Business Rules

Open client questions are tagged **(P#)**. Build the provisional decision; it may change when the client answers.

1. **Three Donor Modalities (`RF-D2`, `RF-C1`, `RF-F1`):**
   - **`Anónima`:** email (required, used only for the receipt) and amount. No name, public name or RFC is stored (validation rule `Anonima_Sin_Nombre_Ni_RFC`). Never appears on the wall. Cannot request an invoice. Switching the form to anonymous clears name, public name and RFC.
   - **`Con crédito`:** name, email, amount, optional public name. Once `Pagada`, the **public name** (or the name if no public name) and amount appear on the wall.
   - **`Con factura`:** legal name, RFC, email, amount, optional public name. Invoice donors are **always public** once `Pagada` (only public name or legal name, and amount). `Solicita_Factura__c` is a formula. `Tipo_Persona__c` derives Moral (12-char RFC) or Física (13-char RFC). Postal code, tax regime and CFDI use are **not** captured (P3).
   - **RFC validation:** normalize with `trim().toUpperCase()`, validate the SAT pattern `^[A-Z&Ñ]{3,4}[0-9]{2}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])[A-Z0-9]{3}$` **and** that the `YYMMDD` date exists. Reuse the Apex class `RfcValidator` (`normalizar`, `tieneFormato`, `esValido`); mirror the same check in the LWC for live feedback. The trigger also enforces it server-side.
2. **Campaigns (`RF-D1a`, `RF-S1`, US-01, US-09):**
   - A campaign is shown on the portal only when **`Vigente__c = true`** (`Activa__c` AND `Fecha_Inicio__c <= TODAY()` AND `Fecha_Fin__c >= TODAY()`). Future campaigns are hidden; ended campaigns belong to the past-campaigns view (US-18, Delivery 2).
   - It accepts donations only if `Permitir_Sobrecupo__c = true` OR `Monto_Recaudado__c < Meta__c`. Otherwise the portal shows it as closed ("Meta alcanzada").
   - `Monto_Recaudado__c` is a native roll-up of `Pagada` donations only. Never calculate it in Apex.
   - Each campaign shows description, image (`Imagen_URL__c`; upload vs URL pending P13), purpose (`Proposito__c`) and deadline. With exactly one campaign in force, the portal opens it directly.
   - The goal cannot change once the campaign has started (`Meta_Bloqueada_Si_Vigente`, P2). "There should always be an open campaign" is pending (P11).
3. **Amounts (US-01 AC3, US-02):**
   - Suggested: $100, $250, $500, $1,000, $2,000, $5,000, $10,000 and $20,000 MXN, plus a custom amount.
   - Minimum **$10.00 MXN** (Stripe's MXN minimum; rule `Monto_Minimo_MXN`, P6), at most 2 decimals, **no app maximum**.
   - Amounts of **$1,000 or more** require a confirmation dialog showing the exact amount before redirecting.
4. **Checkout (`RF-D3`, `RF-D1b`, `RF-D4`, US-06, US-07):**
   - Do NOT use Stripe Elements (LWS/CSP restrictions and M3). Use **Stripe Checkout Sessions** via server-side Apex `HttpRequest`.
   - **Single transaction, callout first, then DML** (the old two-step `crearDonacionPendiente` + `crearSesionStripe(Id)` pattern is **forbidden**: it let a guest pass any donation Id):
     1. Validate input server-side.
     2. Generate `referencia = UUID.randomUUID().toString()`.
     3. `POST https://api.stripe.com/v1/checkout/sessions` with `client_reference_id` and `metadata[referencia]` = referencia, `expires_at` = now + 3600 s, `currency=mxn`, `unit_amount` = amount × 100.
     4. Only if Stripe succeeds, insert `Donacion__c` with `Estado__c = 'Pendiente'`, `Referencia_Publica__c` and `Stripe_Session_Id__c`.
     5. Return **only** the Checkout URL.
   - The `Pendiente` record is a payment intent (P1): it never counts toward progress, never appears publicly and never triggers a receipt.
   - Sessions expire after 1 hour (P10); the webhook then sets `Expirada`.
   - `success_url` → `/agradecimiento` (says the donation was received and the receipt will arrive once payment is confirmed; never claims it is already confirmed). `cancel_url` → `/pago-cancelado` (no charge was made).
5. **Receipts (`RF-D5`, `RF-S3`, US-08):**
   - Sent by `DonationReceiptService` (called from `DonacionTrigger`) only when `Estado__c` transitions to `Pagada`, once. Salesforce sends its own receipt for every modality because Stripe does not email receipts in test mode (P4).
   - Written in Spanish (P12) and uses `Fecha_Pago__c`. Content by modality:
     - `Anónima`: no name.
     - `Con crédito`: name and public credit.
     - `Con factura`: legal name, RFC, invoice-request notice and "Este comprobante no es un CFDI".
   - `Comprobante_Enviado__c` is set only if the email was actually sent; failures go to `Error_Comprobante__c` without rolling back the payment.
6. **Moderation (US-04 AC6, US-19):** `Visible_En_Reconocimiento__c = false` hides a donation from the wall while it still counts toward progress. Blocked-word list is Delivery 2.
7. **Staff (US-09 to US-13):**
   - A donation can become `Pagada` only through the manual confirmation action (`Tipo_Confirmacion__c = 'Manual'`) or the webhook (`'Automática'`); rule `Pagada_Requiere_Tipo_Confirmacion`.
   - The confirmation type is immutable once set.
   - Gateway notices are read-only.

---

## 4. Data Model (exact API names, as deployed)

### 4.1 `Campana__c`
| Field | Type / rule |
|---|---|
| `Name` | Text, required |
| `Descripcion__c` | Long text |
| `Proposito__c` | Long text (5000) — required by rule |
| `Imagen_URL__c` | URL |
| `Meta__c` | Currency 16,2, required; `Meta_Mayor_A_Cero`; locked after start (`Meta_Bloqueada_Si_Vigente`) |
| `Monto_Recaudado__c` | Roll-up SUM of `Donacion__c.Monto__c` where `Estado__c = 'Pagada'` |
| `Activa__c` | Checkbox, default true (manual switch) |
| `Fecha_Inicio__c` / `Fecha_Fin__c` | Date — both required by rule `Campos_Obligatorios_Campana`; `Fecha_Fin_Posterior_A_Inicio` |
| `Vigente__c` | Formula checkbox (see 3.2) |
| `Permitir_Sobrecupo__c` | Checkbox, default true |

### 4.2 `Donacion__c` (Master-Detail to `Campana__c`)
| Field | Type / rule |
|---|---|
| `Name` | Auto number `DON-{00000}` (folio) |
| `Campana__c` | Master-Detail, required |
| `Monto__c` | Currency 16,2, required; `Monto_Minimo_MXN` (≥ 10) |
| `Modalidad__c` | Picklist: `Anónima`, `Con crédito`, `Con factura` |
| `Estado__c` | Picklist: `Pendiente` (default), `Pagada`, `Expirada` |
| `Nombre_Donante__c` | Text 255 — required for crédito/factura (`Nombre_Requerido_Credito_O_Factura`) |
| `Nombre_Publico__c` | Text 80 — name shown on the wall; blank → use `Nombre_Donante__c` |
| `Visible_En_Reconocimiento__c` | Checkbox, default true |
| `Correo__c` | Email, required |
| `RFC__c` | Text 13 — only for `Con factura` (`RFC_Valido_En_Modalidad_Factura`); normalized and date-checked by the trigger |
| `Tipo_Persona__c` | Formula text: Moral / Física |
| `Solicita_Factura__c` | Formula checkbox |
| `Referencia_Publica__c` | Text 36, unique, external Id — UUID; auto-generated if blank; immutable |
| `Stripe_Session_Id__c` | Text 255, unique, external Id |
| `Tipo_Confirmacion__c` | Picklist `Manual`, `Automática`; immutable once set |
| `Fecha_Pago__c` | DateTime, set by the trigger when it becomes `Pagada` |
| `Comprobante_Enviado__c` | Checkbox — set only by `DonationReceiptService` |
| `Error_Comprobante__c` | Text 255 — receipt failure reason |

### 4.3 `Aviso_Pasarela__c` (webhook audit log)
`Name` (`WH-{00000}`), `Stripe_Event_Id__c` (Text 255, external Id, not unique: retries are logged), `Tipo_Evento__c`, `Estado_Aviso__c` (`Procesado`, `Rechazado`, `Duplicado Ignorado`, `Ignorado`, `Error`), `Motivo_Rechazo__c`, `Fecha_Recepcion__c`, `Donacion__c` (lookup).

### 4.4 `Stripe_Config__c` (Protected Hierarchy Custom Setting)
`Secret_Key__c`, `Webhook_Secret__c`, `Success_URL__c` (`<site>/agradecimiento`), `Cancel_URL__c` (`<site>/pago-cancelado`). Values are set in the org only.

### 4.5 Permission sets
- `Coordinacion_Tesoreria_Admin` (treasury and coordination; assigned to the team — do not delete or rename): create/edit campaigns and donations, no delete; notices, confirmation type, receipt fields, reference and session Id are read-only.
- `Moderacion_Reconocimiento`: read campaigns and donations; edit only `Nombre_Publico__c` and `Visible_En_Reconocimiento__c`; no RFC access.
- Only member 1 changes objects, fields, validation rules and permission sets. Other members request changes instead of editing them.

---

## 5. Webhook (`StripeWebhookService`, `@RestResource(urlMapping='/stripe/webhook/*')`) — built
- **Signature:** HMAC-SHA256 over `timestamp.rawBody` with `Webhook_Secret__c`, compared to every `v1`. Reject if missing, invalid or the timestamp is more than **5 minutes** off → notice `Rechazado`, HTTP 400.
- **Duplicates:** only an event already `Procesado` or `Ignorado` counts as duplicate (→ `Duplicado Ignorado`, HTTP 200). Events previously `Rechazado` or `Error` are processed again when retried.
- **Event types:**
  - `checkout.session.completed` with `payment_status = 'paid'`, or `checkout.session.async_payment_succeeded` → `Pagada` + `Automática`.
  - `checkout.session.expired` on a `Pendiente` donation → `Expirada`.
  - Anything else → `Ignorado`.
- **Lookup:** by `Referencia_Publica__c` (`client_reference_id` or `metadata[referencia]`), then by `Stripe_Session_Id__c`, with `FOR UPDATE`. Never by record Id. Not found → `Rechazado`, HTTP 400.
- **Amount:** `amount_total` must equal `Monto__c × 100` and `currency` must be `mxn`; otherwise `Rechazado` (HTTP 200) and the donation is not paid.
- **Unexpected errors:** savepoint rollback, notice `Error`, HTTP 500 so Stripe retries.
- Exposing the endpoint through the site and registering it in Stripe is Delivery 2.

---

## 6. Public Portal — Member 2 Scope (`US-01` to `US-06`, `US-14`)

### 6.1 Experience Cloud site (built: "Portal Donaciones MD2026", path `/md2026`)
- Guest profile `Portal Donaciones MD2026 Perfil`: access to `DonationPublicController` only; no object or field permissions (verified live with zero permissions). Guest profiles do not appear in Setup → Profiles; open them from Experience Builder → Settings → General.
- `networks/` and `sites/` are git-ignored because they contain the sender email and the org username; deploy them only from a local machine.
- After deploying LWC or bundle changes run `sf community publish --name "Portal Donaciones MD2026"`.
- Create a **new** site with the **Build Your Own (LWR)** template and guest access. In LWR, every change requires **Publish** again.
- The org is a shared copy of an older university org. It already contains a live site at `/donaciones` and about 30 legacy LWCs from previous years (`home`, `footer`, `container`, `lastDonors`, PayPal/Oxxo components, etc.). **Do not use, modify or reuse them**, do not reuse the `/donaciones` path, and do not create components with those generic names.
- Pages: `/` (campaigns, form, wall), `/agradecimiento` and `/pago-cancelado` (components by member 3). No global search, profiles or internal tabs (US-14).
- Guest profile: access to `DonationPublicController` only; zero object permissions on `Donacion__c` and `Aviso_Pasarela__c`.
- Retrieve the site into the repo (`DigitalExperienceBundle`, `DigitalExperienceConfig`, `Network`, `CustomSite`) and check that no usernames, emails or keys are included before committing.

### 6.2 `DonationPublicController` (built)
`without sharing`, with **`WITH SYSTEM_MODE`** on every query and **`insert as system`**: in the guest context Salesforce applies the user's schema visibility even inside Apex (`sObject type ... is not supported`, `No such column ...`), and the guest profile must keep **zero object and field permissions**. All access control lives in this controller. Every method returns DTOs.

1. `@AuraEnabled(cacheable=true) List<CampanaPublicaDTO> obtenerCampanasActivas()`:
   - `Vigente__c = true`, ordered by `Fecha_Fin__c, Name`.
   - DTO fields: `id`, `nombre`, `descripcion`, `proposito`, `imagenUrl`, `meta`, `recaudado`, `porcentaje`, `fechaFin`, `elegibleParaDonar`, `motivoCierre`.
2. `@AuraEnabled(cacheable=true) List<DonanteReconocimientoDTO> obtenerMuroDonantes(Id campanaId)`:
   - Filter: `Pagada`, `Con crédito`/`Con factura`, `Visible_En_Reconocimiento__c = true`, ordered by `Fecha_Pago__c DESC`.
   - No fixed limit of 50 (paginate if needed).
   - DTO contains **only** `nombrePublico` (public name or name) and `monto`.
3. `@AuraEnabled String iniciarDonacion(SolicitudDonacionDTO input)`:
   - Validates the campaign is in force and eligible, the amount (≥ 10, two decimals), the email and the modality rules, plus RFC via `RfcValidator`.
   - Calls Stripe (section 3.4), then inserts the `Pendiente` donation.
   - Returns only the Checkout URL. Stripe errors → `AuraHandledException` with a generic Spanish message and nothing inserted.
   - Stripe parameters: `mode=payment`, `submit_type=donate`, `locale=es` (do not send `payment_method_types`: Stripe rejects it; payment methods are set in the Dashboard), `customer_email`, line item `Donación: <campaign>`, `expires_at`, `success_url` / `cancel_url` from `Stripe_Config__c`. URL-encode every value.
4. `DonationPublicControllerTest` with `HttpCalloutMock`, using `DonacionTestFactory` for data. Cover each acceptance criterion, positive and negative, with >90% coverage.

### 6.3 LWC (targets `lightningCommunity__Page`, `lightningCommunity__Default`)
Drag **one container per page** into Experience Builder; children receive the selected campaign as a property.

- `portalCampanasPublico` (US-01, US-02): campaign cards with image, description, purpose, deadline and progress bar; direct view when there is only one campaign; closed state.
- `formularioDonacionPublico` (US-02, US-03, US-05, US-06):
  - suggested and custom amounts;
  - live validation: min $10, 2 decimals, RFC;
  - confirmation dialog at $1,000 or more;
  - modality selector that clears data when switching to anonymous;
  - calls `iniciarDonacion` and redirects with `window.location.href`.
- `muroDonantesPublico` (US-04): auto-scrolling list that pauses on hover; public name and amount only.

All three use Spanish texts, are responsive, and never store donor data in `localStorage` or the URL. External scripts are not allowed (LWS).

---

## 7. Salesforce Coding Standards (Criterion C6)
1. **Error handling (S11):** catch exceptions in Apex and throw `AuraHandledException` with user-friendly Spanish messages. Never leave a donation half-updated.
2. **Bulkification (S12):** no SOQL or DML inside loops; triggers and handlers support bulk records.
3. **No hardcoded Ids (S12, S14):** query records or use custom settings / custom metadata.
4. **Tests (S14):** every Apex class has a `*Test.cls`:
   - Use `Test.setMock(HttpCalloutMock.class, ...)` for Stripe callouts.
   - Create data with `DonacionTestFactory` (all required fields, `@example.com` emails).
   - The sandbox cannot send email (deliverability is off). Tests that assert a receipt was sent set `DonationReceiptService.simulacionEnvio = 'exito'`; it only works inside tests.
5. **Deploys:** the org is shared. Deploy only this project's components, preferably with `--dry-run` first and `--test-level RunSpecifiedTests` listing this project's test classes. Do not run `RunLocalTests`: it executes legacy classes from other projects.
6. **Code Analyzer:** run `sf code-analyzer run` before delivery. Its Apex engines need Java 11+. Justify every suppression in a comment.
7. **Language:** code identifiers and UI texts follow the existing Spanish naming; this rules file is in English.

---

## 8. Mandatory Documentation Workflow (Criterion C3)
Whenever you (the AI agent) generate code, fix a bug, or design a component, end your response with a ready-to-paste row for `docs/bitacora_ia.md` with these exact fields:
- **Fecha:** `YYYY-MM-DD`
- **Autor:** `[Nombre del integrante]`
- **Herramienta:** `[Nombre del modelo/IDE]`
- **Historia relacionada:** `[US-XX / RF-XX]`
- **Qué se pidió (Prompt/Resumen):** `[Resumen claro de la solicitud]`
- **Qué se obtuvo:** `[Artefacto o código generado]`
- **Qué se verificó y cómo:** `[Prueba en Org, test unitario o documentación oficial revisada]`
- **Qué se corrigió (¿Error de IA?):** `[Sí/No, qué error cometió la IA, cómo se detectó y cómo se corrigió]`
- **Aceleración estimada:** `[Ej. Ahorró ~2 horas frente a hacerlo sin IA]`

Never write names of people outside the team or of the reviewers in public files (backlog, docs, commits).
