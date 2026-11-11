# Security Architecture & Verification: Guest User and Gateway (`US-15`, `M2`, `M3`)

This document describes the security architecture, data classification, and reproducible verification procedures ensuring strict compliance with critical minimums **M2** (least privilege for the Experience Cloud Guest User) and **M3** (strict protection of payment gateway secrets and keys).

---

## 1. Reproducible Guest User Verification Steps (`US-15`)

Any external evaluator or security auditor can reproduce these tests without authenticating into Salesforce:

### Test 1.1: Public Browsing in an Incognito Window

1. Open an incognito/private browser window (with no active Salesforce session).
2. Navigate to the public portal URL: `https://<sandbox-domain>.sandbox.my.site.com/md2026/`.
3. **Expected result:**
   - The page loads without prompting for login (`US-14`).
   - Active and in-force campaigns (`Vigente__c = true`) are displayed.
   - The Recognition Wall displays only the public name (or donor name) and amount for paid donations. No date, email, or RFC is shown.

### Test 1.2: Network Payload Inspection in DevTools

1. Open browser Developer Tools (`F12`) and go to the **Network** tab.
2. Filter by `DonationPublicController` or `obtenerMuroDonantes`.
3. Reload the page or select a campaign to load the wall.
4. Inspect the JSON response payload returned by Apex.
5. **Expected result:**
   - Each object in the array contains only the `nombrePublico` and `monto` properties.
   - It contains no fields such as `Id`, `Correo__c`, `RFC__c`, `Nombre_Donante__c`, `CreatedDate`, or `Fecha_Pago__c`.

### Test 1.3: Unauthenticated Direct Access Attempt via Standard REST API

1. Run a `curl` request against the standard Salesforce REST endpoint for `Donacion__c`:
   ```bash
   curl -i -X GET "https://<sandbox-domain>.sandbox.my.site.com/services/data/v60.0/sobjects/Donacion__c"
   ```
2. **Expected result:**
   - HTTP **`401 Unauthorized`** or **`404 Not Found`** response code.
   - The Guest User lacks an OAuth token, and the object is not exposed through the standard public API.

### Test 1.4: Parameter Tampering Attempt on Public Methods (Aura/Apex)

1. Attempt to call `obtenerMuroDonantes` passing a donation Id or an arbitrary Id from another object:
   - The server validates `campanaId.getSobjectType() == Campana__c.SObjectType`.
   - If a `Donacion__c` Id is supplied, it immediately returns an empty list (`US-15 AC5`).
2. Attempt to call `iniciarDonacion`:
   - No parameter accepts a donation record Id. The server generates a new, immutable UUID (`Referencia_Publica__c`) on every request.

---

## 2. Guest User Profile Permission Matrix (`Portal Donaciones MD2026 Perfil`)

| Resource / Object | Granted Permission | Security Justification (`M2`) |
|---|---|---|
| `Donacion__c` | **None** (`Read=false`, `Create=false`, `Edit=false`, `Delete=false`) | Prevents any attacker from querying or modifying other donors' records via Salesforce APIs. |
| `Campana__c` | **None** (`Read=false`, `Create=false`, `Edit=false`, `Delete=false`) | Campaigns are exposed exclusively through filtered DTOs in `obtenerCampanasActivas()`. |
| `Aviso_Pasarela__c` | **None** (`Read=false`, `Create=false`, `Edit=false`, `Delete=false`) | Webhook auditing is strictly internal; public visitors must not see gateway logs or retries. |
| Apex: `DonationPublicController` | **Enabled** | Exposes the 3 secure public methods operating exclusively with DTOs. |
| Apex: `StripeWebhookService` | **Enabled** | Allows receiving signed Stripe webhooks on the site's public REST endpoint. |
| All other Apex classes | **Disabled** | Strict least privilege; administrative controllers and utilities remain inaccessible to guests. |

> **Technical access implementation:** Because the Guest User Profile has zero schema/object permissions, public controllers internally execute queries with `WITH SYSTEM_MODE` and DML with `insert as system` / `update as system`. All authorization and filtering logic runs centrally inside Apex.

---

## 3. Protection of Gateway Secrets and Keys (`M3`)

- **Storage location:** Stripe credentials (`Secret_Key__c` and `Webhook_Secret__c`) live exclusively inside the Protected Hierarchy Custom Setting **`Stripe_Config__c`** in the Salesforce Org.
- **Zero secrets in code or version control:** No file in the Git repository (`.cls`, `.js`, `.xml`, `.json`, `.md`) contains live or test key prefixes (`sk_test_...`, `whsec_...`).
- **Server-side retrieval:** Keys are read only inside server-side Apex transactions via `Stripe_Config__c.getOrgDefaults()`.

### Incident Response Protocol for Accidental Key Exposure

1. **Immediate Revocation in Stripe:**
   - Immediately open the Stripe Dashboard (Developers → API Keys / Webhooks) and revoke the compromised key.
2. **New Key Generation:**
   - Generate a new Secret Key or Signing Secret in Stripe.
3. **Update in Salesforce:**
   - Navigate to **Setup → Custom Settings → Stripe Config → Manage** and update the corresponding field with the new value.
4. **Git History Audit:**
   - Verify with `git log -S` and secret-scanning tools that the key was never committed to local or remote branches.

---

## 4. Personal Data Classification & Handling

| Data Element | Classification | Storage | Public Exposure |
|---|---|---|---|
| **Card number, CVC, expiry** | Critical / PCI-DSS | **Stripe only** (Salesforce never receives or stores card details) | None |
| **Email address (`Correo__c`)** | Confidential Personal | `Donacion__c.Correo__c` (private) | **Never.** Used solely to deliver the digital receipt. |
| **Donor / Legal Name (`Nombre_Donante__c`)** | Confidential Personal | `Donacion__c.Nombre_Donante__c` (private) | Hidden when an alternative public name is provided or when the donation is anonymous. |
| **Tax ID / RFC (`RFC__c`)** | Confidential Tax Data | `Donacion__c.RFC__c` (private) | **Never.** Visible only to Treasury staff in the internal invoicing list view. |
| **Public Wall Name (`Nombre_Publico__c`)** | Consented Public | `Donacion__c.Nombre_Publico__c` | Shown on the recognition wall when the donor selected `Con crédito` or `Con factura`. |
| **Donation Amount (`Monto__c`)** | Consented Financial | `Donacion__c.Monto__c` | Shown on the recognition wall and aggregated into the campaign goal progress. |

---

## 5. Known Risks & Mitigations

| Identified Risk | Impact | Implemented Mitigation |
|---|---|---|
| **Client-side amount tampering** | High | The server (`DonationPublicController`) re-validates that the amount is >= $10.00 MXN, <= $999,999.99 MXN, and has at most 2 decimals. Stripe Checkout charges the Apex-verified `unit_amount`. |
| **Webhook amount tampering** | High | `StripeWebhookService` verifies `amount_total == Monto__c * 100` and `currency == 'mxn'`. On mismatch, the donation is not marked `Pagada` and an `Aviso_Pasarela__c` notice with `Rechazado` (Rejected) status is logged. |
| **Replay attack** | Medium | `Stripe-Signature` header timestamp check: signatures older than 300 seconds (5 minutes) relative to server time are rejected. |
| **Duplicate Stripe events** | Low | Idempotency control in `Aviso_Pasarela__c` via `Stripe_Event_Id__c`: automatic HTTP 200 responses without duplicating payments or receipts. |
| **Email delivery failure** | Low | `DonationReceiptService` captures `Messaging.sendEmail()` failures in `Error_Comprobante__c` without rolling back the payment or blocking the transaction. |

---

## 6. Stripe Webhook Endpoint Security

- **Official LWR URL:** `https://<sandbox-domain>.sandbox.my.site.com/md2026vforcesite/services/apexrest/stripe/webhook`
- **Cryptographic Authentication:** HMAC-SHA256 using the `v1` signature computed over `timestamp.rawBody` with `Webhook_Secret__c`.
- **Opaque Reference Lookup:** The donation is resolved exclusively by `Referencia_Publica__c` (UUID) or `Stripe_Session_Id__c`, locking the row with `FOR UPDATE`. The internal Salesforce record Id is never accepted or queried.
- **Audit Trail:** Every processed, rejected, or duplicate request creates an audit record in `Aviso_Pasarela__c`.
