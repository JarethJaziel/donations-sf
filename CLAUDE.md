# Project Context & System Rules: SF Vibe Lab — Mexico Dreamin 2026 Donation Portal

## 1. Project Overview & Role of the AI Agent
You are an expert Salesforce Architect and Developer (LWC, Apex, Flows, Experience Cloud, and Stripe Integration) assisting a 4-person consulting team from UADY on the final project for **SF Vibe Lab**.

**Business Goal:** Build a 100% Salesforce-hosted solution (connected to Stripe in Test Mode) allowing public unauthenticated visitors to donate online toward student sponsorship campaigns for **Mexico Dreamin 2026** (Nov 20, 2026, CDMX), while giving internal staff (Coordination and Treasury) full management, reconciliation, invoice filtering, and webhook auditing capabilities.

---

## 2. CRITICAL PASS/FAIL MINIMUMS (ZERO TOLERANCE RULES)
Breaking any of these 3 rules deducts **10 points directly** from the final team grade and invalidates affected User Stories:

1. **M1 — 100% Test Mode & Fictitious Data:**
   - Everything runs in a **Salesforce Developer Edition Org** and **Stripe Test Mode (Sandbox)**.
   - Never use real personal data, real emails of third parties (only team-controlled test emails), real RFCs, or live payment keys.
   - Never emit a real fiscal receipt (CFDI) or connect to live SAT web services.
2. **M2 — Guest User Least Privilege (Public Portal Security):**
   - The Experience Cloud **Guest User Profile** MUST NEVER have direct `Read`, `Edit`, or `Delete` permissions on `Donacion__c` via standard Salesforce APIs.
   - Never return raw `Donacion__c` SObjects to LWC components. Always return custom Apex `@AuraEnabled` **Wrapper/DTO classes** containing ONLY the strictly required public fields (`Name` and `Amount` for public recognition; campaign aggregates for progress).
   - Never expose donor emails, RFCs, anonymous donor names, or other donors' records in the UI, URL parameters, or browser network responses.
3. **M3 — ZERO SECRETS IN CODE OR GIT HISTORY:**
   - **NEVER** write, hardcode, log, or put placeholder values that look like real Stripe keys (`sk_test_...`, `pk_test_...`, `whsec_...`) in any `.cls`, `.js`, `.xml`, `.json`, or `.md` file.
   - The GitHub repository is PUBLIC. Secrets must ONLY be stored as data inside a **Protected/Private Hierarchy Custom Setting** (`Stripe_Config__c`) configured manually in the Salesforce Setup UI and retrieved in Apex via `Stripe_Config__c.getOrgDefaults()`.

---

## 3. Validated Business Rules (From Client Discovery Q&A)

1. **Three Donor Modalities (`RF-D2`, `RF-C1`, `RF-F1`):**
   - **`Anonymous` (`Anónima`):** Donor provides email (for receipt) and amount. Name is NOT captured or is ignored. Name must NEVER appear on the public website, thank-you page, or email receipt. Cannot request an invoice.
   - **`With Credit` (`Con crédito`):** Donor provides Name, Email, and Amount. Once `Estado__c == 'Pagada'`, their **Name and Amount** appear on the campaign's public donor recognition wall (never exposing their email).
   - **`With Invoice` (`Con factura`):** Donor provides Legal Name (`Nombre / Razón Social`), Email, RFC, and Amount.
     - **Client Discovery Rule #1:** Invoice donors are **ALWAYS PUBLIC** on the campaign recognition wall once `Estado__c == 'Pagada'` (showing ONLY their Name and Amount on the public wall, strictly hiding their RFC and Email).
     - **RFC Validation:** Must be validated both in LWC and Apex against the official SAT Regex pattern (12 chars for companies/personas morales, 13 chars for individuals/personas físicas: letters + 6-digit valid date `YYMMDD` + 3-char homoclave). Normalize to uppercase and trim whitespace before validation.
2. **Campaign Eligibility & Overfunding (`RF-D1a`, `RF-S1`, Client Discovery Rule #2):**
   - Only `Activa__c == true` campaigns appear on the public portal.
   - Campaign progress (`Monto_Recaudado__c`) ONLY sums donations where `Estado__c == 'Pagada'`. `Pendiente` donations never count toward progress.
   - **Deadline Rule:** If `Fecha_Fin__c < TODAY()`, the campaign is strictly closed and cannot accept new donations.
   - **Overfunding Rule:** Each campaign has a boolean flag `Permitir_Sobrecupo__c` (`Allow Overfunding`). If `Monto_Recaudado__c >= Meta__c` AND `Permitir_Sobrecupo__c == false`, the campaign is closed for new donations. If `Permitir_Sobrecupo__c == true` (and the end date has not passed), donors can continue donating past 100%.
3. **Pre-Payment Registration & Stripe Checkout (`RF-D3`, `RF-D1b`, `RF-D4`, Client Discovery Rule #3):**
   - Do NOT use Stripe Elements (iframe/JS SDK) in LWC due to Lightning Web Security (LWS), CSP restrictions, and Minimum M3.
   - Use **Stripe Checkout Sessions API** (`POST https://api.stripe.com/v1/checkout/sessions`) via server-side Apex `HttpRequest`.
   - **Two-Transaction Pattern (Preventing `System.CalloutException: You have uncommitted work pending`):**
     - **Step 1 (Apex DML):** LWC calls `crearDonacionPendiente(...)` -> validates inputs -> inserts `Donacion__c` with `Estado__c = 'Pendiente'` -> returns the Salesforce Record `Id`.
     - **Step 2 (Apex Callout + DML):** LWC immediately calls `crearSesionStripe(Id donacionId)` -> performs `HttpRequest` to Stripe sending `client_reference_id = donacionId`, `metadata[donacion_id] = donacionId`, dynamic `unit_amount` (amount * 100 in cents), and `success_url` pointing to `/agradecimiento` -> updates `Donacion__c.Stripe_Session_Id__c` with Stripe's session ID (`cs_test_...`) -> returns the Checkout URL to LWC for `window.location.href` redirection.
   - Abandoned/unpaid sessions follow Stripe's native lifecycle (remain `Pendiente` or expire without counting as `Pagada`).
4. **Tailored Email Receipts (`RF-D5`, `RF-S3`, Client Discovery Rule #4):**
   - Triggered automatically (via Record-Triggered Flow or Apex Email Service) ONLY when `Donacion__c.Estado__c` transitions to `'Pagada'` (preventing duplicate emails if an already-paid record is edited).
   - Receipt content adapts by modality:
     - `Anónima`: Donation Folio/Reference, Campaign Name, Date, Amount Paid, generic thank-you message. **Strictly NO donor name.**
     - `Con crédito`: Donor Name, Donation Folio/Reference, Campaign Name, Date, Amount Paid, and confirmation of public credit on the campaign wall.
     - `Con factura`: Legal Name, RFC, Donation Folio/Reference, Campaign Name, Date, Amount Paid, and notice confirming that their invoice request (`Solicita factura`) is queued for Treasury.

---

## 4. Data Model Specification (Salesforce Custom Objects & Fields)

Always use these exact API names unless instructed otherwise:

### 4.1 `Campana__c` (Custom Object)
- `Name` (Standard Text): Campaign Name (Required).
- `Descripcion__c` (Long Text Area): Campaign details.
- `Meta__c` (Currency 16,2): Financial target (Validation Rule: `Meta__c <= 0` blocks save).
- `Monto_Recaudado__c` (Roll-Up Summary or Apex/Flow calculated Currency 16,2): Sum of `Donacion__c.Monto__c` filtered by `Estado__c = 'Pagada'`.
- `Activa__c` (Checkbox, Default `true`): Controls visibility on the public site.
- `Fecha_Fin__c` (Date): Campaign deadline.
- `Permitir_Sobrecupo__c` (Checkbox, Default `true`): Whether donations are accepted after reaching 100% of `Meta__c`.

### 4.2 `Donacion__c` (Custom Object)
- `Name` (Auto Number: `DON-{00000}`): Unique donation folio.
- `Campana__c` (Master-Detail or Lookup to `Campana__c`, Required).
- `Monto__c` (Currency 16,2, Required): Validation `Monto__c > 0`.
- `Modalidad__c` (Picklist, Required): `'Anónima'`, `'Con crédito'`, `'Con factura'`.
- `Estado__c` (Picklist, Required, Default `'Pendiente'`): `'Pendiente'`, `'Pagada'`, `'Expirada'`.
- `Nombre_Donante__c` (Text 255): Required if `Modalidad__c` is `'Con crédito'` or `'Con factura'`; MUST be blank/null if `'Anónima'`.
- `Correo__c` (Email, Required): Used to send the receipt.
- `RFC__c` (Text 13): Required ONLY if `Modalidad__c == 'Con factura'`; blank otherwise.
- `Solicita_Factura__c` (Formula Checkbox or Checkbox): `ISPICKVAL(Modalidad__c, 'Con factura')`.
- `Stripe_Session_Id__c` (Text 255, External ID / Unique): Stores `cs_test_...` reference.
- `Tipo_Confirmacion__c` (Picklist): `'Manual'`, `'Automática'`.
- `Comprobante_Enviado__c` (Checkbox, Default `false`): Guard flag to prevent sending duplicate receipt emails.

### 4.3 `Aviso_Pasarela__c` (Custom Object — Delivery 2 Audit Log)
- `Name` (Auto Number: `WH-{00000}`).
- `Stripe_Event_Id__c` (Text 255, External ID / Unique): Stores Stripe's `evt_...` ID for idempotency (`RF-V3b`).
- `Estado_Aviso__c` (Picklist): `'Procesado'`, `'Rechazado'`, `'Duplicado Ignorado'`.
- `Motivo_Rechazo__c` (Text 255): Reason for rejection (e.g., `'Missing Stripe-Signature'`, `'Invalid HMAC-SHA256 Signature'`, `'Donation Not Found'`).
- `Fecha_Recepcion__c` (DateTime, Default `NOW()`).
- `Donacion__c` (Lookup to `Donacion__c`, Optional).

### 4.4 `Stripe_Config__c` (Hierarchy Custom Setting — Protected)
- `Secret_Key__c` (Text 255): Stores Stripe secret key in the Org database (NEVER in metadata/Git).
- `Webhook_Secret__c` (Text 255): Stores Stripe webhook signing secret in the Org database (NEVER in metadata/Git).
- `Success_URL__c` (Text 255): Public thank-you page URL.
- `Cancel_URL__c` (Text 255): Public portal home URL.

---

## 5. Webhook Security & Idempotency Architecture (Delivery 2: `RF-V3a`, `RF-V3b`, `RF-S4`)
- Expose an Apex REST class `@RestResource(urlMapping='/stripe/webhook/*')` with `global without sharing class StripeWebhookService`.
- **Signature Verification (`RF-V3b CA1`):**
  - Read `Stripe-Signature` header (`t=timestamp,v1=signature`).
  - Compute expected HMAC using `Crypto.generateMac('hmacSHA256', Blob.valueOf(timestamp + '.' + rawBody), Blob.valueOf(webhookSecret))` and convert with `EncodingUtil.convertToHex(mac)`.
  - If header is missing or signature does not match `v1`, insert an `Aviso_Pasarela__c` record with `Estado_Aviso__c = 'Rechazado'` and `Motivo_Rechazo__c = 'Firma criptográfica inválida'`, set `RestContext.response.statusCode = 400`, and do NOT modify any `Donacion__c`.
- **Idempotency (`RF-V3b CA2`):**
  - Query `Aviso_Pasarela__c` by `Stripe_Event_Id__c`. If an event with the same `evt_...` ID was already processed (or if the target `Donacion__c.Estado__c` is already `'Pagada'`), log/ignore the duplicate and return HTTP `200` without updating the donation or triggering a second receipt email.

---

## 6. Salesforce Coding Standards (Criterion C6)
1. **Error Handling (S11):** Catch exceptions cleanly in Apex and throw `AuraHandledException` with user-friendly messages in Spanish. Never leave a donation in an inconsistent state.
2. **Bulkification & Governor Limits (S12):** NEVER place SOQL queries or DML statements inside `for` loops in Apex or Flows. All triggers/flows/handlers must support bulk records.
3. **Zero Hardcoded IDs (S12, S14):** Never hardcode Salesforce Record IDs (`a00...`, `005...`, `012...`). Query records dynamically or use Custom Settings / Custom Metadata.
4. **Unit Tests & Code Analyzer (S14):** Every Apex class must have a corresponding `*Test.cls` (`@isTest`) using `Test.setMock(HttpCalloutMock.class, ...)` for Stripe callouts. All code must pass `sf code-analyzer run` with zero unaddressed critical findings.

---

## 7. Mandatory Documentation Workflow (Criterion C3 — 20 Points)
Whenever you (the AI agent) generate code, fix a bug, or design a component, provide a ready-to-paste Markdown row at the end of your response so the developer can log it immediately in `docs/bitacora_ia.md` with these exact fields:
- **Fecha:** `YYYY-MM-DD`
- **Autor:** `[Nombre del integrante]`
- **Herramienta:** `[Nombre del modelo/IDE]`
- **Historia relacionada:** `[US-XX / RF-XX]`
- **Qué se pidió (Prompt/Resumen):** `[Resumen claro de la solicitud]`
- **Qué se obtuvo:** `[Artefacto o código generado]`
- **Qué se verificó y cómo:** `[Prueba en Org, test unitario o documentación oficial revisada]`
- **Qué se corrigió (Errores de la IA):** `[Ajustes manuales o errores detectados en la respuesta de la IA]`
- **Aceleración estimada:** `[Ej. Ahorró ~2 horas frente a hacerlo sin IA]`
