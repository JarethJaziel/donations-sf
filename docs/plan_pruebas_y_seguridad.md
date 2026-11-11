# Test Plan, Security & Pre-Delivery Checklist — SF Vibe Lab

> **Purpose:** Ensure compliance with all acceptance criteria (positive and negative), pass/fail minimums (**M1**, **M2**, **M3**), and code quality standards (**C6**) prior to each delivery or Pull Request.

## 1. Critical Minimums Verification (Zero Tolerance)

- [x] **M1 (100% Test Mode & Fictitious Data):**
  - [x] Only Stripe test cards (`4242...`) and reserved-domain emails (`@example.com`) are used.
  - [x] No real third-party RFCs have been entered in tests or the database.
- [x] **M2 (Least Privilege on Guest User Profile):**
  - [x] The Experience Cloud Guest User Profile (`Portal Donaciones MD2026 Perfil`) has `Read = false`, `Create = false`, `Edit = false`, `Delete = false` on `Donacion__c`, `Campana__c`, and `Aviso_Pasarela__c`.
  - [x] No `@AuraEnabled` method returns raw `Donacion__c` SObjects; all methods use DTOs omitting `Correo__c` and `RFC__c`.
  - [x] No public method accepts or returns a donation record Id; only `Referencia_Publica__c` (opaque UUID) is used.
- [x] **M3 (Zero Secrets in Code or Git):**
  - [x] Clean Git history audit: no file contains real key prefixes (`sk_test_...`, `whsec_...`).
  - [x] `Stripe_Config__c` (Protected Custom Setting) is configured manually in the Org.

---

## 2. Functional & Negative Test Case Matrix

| Case ID | Story / RF | Scenario | Input | Expected Result | Status |
|---|---|---|---|---|---|
| TC-01 | `RF-D1a` | Expired campaign by date | `Fecha_Fin__c < TODAY()` | Portal shows campaign as closed and Apex rejects new donations. | ✅ Passing |
| TC-02 | `RF-D1a` | Campaign at 100% without overfunding | `Monto_Recaudado__c >= Meta__c` and `Permitir_Sobrecupo__c = false` | Checkout is blocked; displays `"Meta alcanzada"` (Goal reached). | ✅ Passing |
| TC-03 | `RF-D1a` | Campaign at 100% with overfunding allowed | `Monto_Recaudado__c >= Meta__c` and `Permitir_Sobrecupo__c = true` | Allows donating normally while `Vigente__c = true`. | ✅ Passing |
| TC-04 | `RF-D2` | Anonymous donation | `Modalidad = 'Anónima'`, Email, Amount | Stores `Nombre_Donante__c = null`; never appears on public wall or in receipt with a name. | ✅ Passing |
| TC-05 | `RF-C1` | Credited donation | `Modalidad = 'Con crédito'`, Name, Email, Amount | While `Pendiente`, does not count or appear; once `Pagada`, public name and amount appear on wall. | ✅ Passing |
| TC-06 | `RF-F1` | Invoiced donation (valid RFC) | `Modalidad = 'Con factura'`, Legal Name, valid RFC (`EKU9003173C9`), Email, Amount | Sets `Solicita_Factura__c = true`; once paid, appears on public wall (hiding RFC and Email). | ✅ Passing |
| TC-07 | `RF-F1` | Invoiced donation (invalid RFC / nonexistent date) | RFC with Feb 30 (`GODE560230GR8`) | Both LWC and Apex reject the entry indicating the date does not exist. | ✅ Passing |
| TC-08 | `US-02` | Amount below Stripe minimum ($10.00 MXN) | Amount $9.99 MXN | LWC and Apex block checkout (`"El monto mínimo es $10.00 MXN"` / Minimum amount is $10.00 MXN). | ✅ Passing |
| TC-09 | `US-02` | Amount above Stripe limit ($999,999.99 MXN) | Amount $1,000,000.00 MXN | LWC and Apex block checkout (`"El monto máximo por transacción en Stripe es $999,999.99 MXN"` / Max per Stripe transaction is $999,999.99 MXN). | ✅ Passing |
| TC-10 | `US-02` | High-amount confirmation dialog | Amount >= $1,000.00 MXN | Displays confirmation modal showing exact amount before redirecting to Stripe. | ✅ Passing |
| TC-11 | `US-06` | Opaque public reference generation | Checkout initiation | Unique UUID generated; Stripe receives `metadata[referencia]` and never the record Id. | ✅ Passing |
| TC-12 | `US-07` | Payment cancelled on gateway | User clicks "Back" or cancels in Stripe | Redirects to `/md2026/pago-cancelado`; clarifies that no charges were made. | ✅ Passing |
| TC-13 | `US-08` | Salesforce email deliverability failure | Email send rejected by org configuration | Reason recorded in `Error_Comprobante__c` without rolling back the paid donation status. | ✅ Passing |
| TC-14 | `US-12` | Manual confirmation by Treasury | Donation in `Pendiente` status | Transitions to `Pagada` with `Tipo_Confirmacion__c = 'Manual'`, immutable on subsequent edits. | ✅ Passing |
| TC-15 | `US-16` | Confirmed payment webhook | Signed `checkout.session.completed` event | Transitions to `Pagada` with `Tipo_Confirmacion__c = 'Automática'`, current payment timestamp, and `Procesado` notice. | ✅ Passing |
| TC-16 | `US-16` | Webhook with tampered amount or currency | `amount_total` or `currency` mismatch | Donation stays `Pendiente`; creates audit notice with `Rechazado` status. | ✅ Passing |
| TC-17 | `US-16` | Expired session webhook | `checkout.session.expired` event | `Pendiente` donation transitions to `Expirada`; notice logged as `Procesado`. | ✅ Passing |
| TC-18 | `US-17` | Webhook with invalid or missing signature | Incorrect HMAC signature or missing header | Returns HTTP 400 and logs notice with `Rechazado` status. | ✅ Passing |
| TC-19 | `US-17` | Webhook with expired timestamp (> 5 min) | Old signature (potential replay attack) | Returns HTTP 400 and logs notice with `Rechazado` status. | ✅ Passing |
| TC-20 | `US-17` | Duplicate webhook (Idempotency) | Same `evt_...` sent a second time | Returns HTTP 200 and logs notice as `Duplicado Ignorado` without duplicating receipts. | ✅ Passing |
