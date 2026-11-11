# Technical Architecture & Design Decisions (ADR) — SF Vibe Lab

> **Purpose:** Document the system architecture, data model, Stripe integration flow, and strict compliance with critical minimums **M1**, **M2**, and **M3**.
> **Version 2 (2026-11-08):** The payment flow changed to a single transaction with an opaque public reference (ADR-01 and ADR-04), and the webhook now verifies event type, amount/currency, and signature timestamp age. See field and rule details in [`CLAUDE.md`](../CLAUDE.md), Section 4.

## 1. Integration Flow Diagram (Single Transaction + Webhook)

```mermaid
sequenceDiagram
    autonumber
    actor Donor as Public Visitor (Guest User)
    participant LWC as LWC Donation Portal
    participant Apex as DonationPublicController (DTOs)
    participant DB as Salesforce DB (Donacion__c / Campana__c)
    participant Stripe as Stripe API (Test Mode)
    participant WH as StripeWebhookService (@RestResource)

    Donor->>LWC: Completes form (Modality, Amount, Email, [Name, Public Name, RFC])
    LWC->>LWC: Validates min $10, max 2 decimals, RFC; confirms if amount >= $1,000
    LWC->>Apex: iniciarDonacion(SolicitudDonacionDTO)
    Apex->>Apex: Validates active & eligible campaign, amount, email, modality, and RFC (RfcValidator)
    Apex->>Apex: Generates referencia = UUID
    Apex->>DB: Reads Stripe_Config__c.getOrgDefaults() (Protected Custom Setting)
    Apex->>Stripe: POST /v1/checkout/sessions (client_reference_id = referencia, metadata[referencia], expires_at = +1 h)
    alt Stripe returns an error
        Stripe-->>Apex: Error
        Apex-->>LWC: AuraHandledException (generic message); nothing is inserted
    else Session created
        Stripe-->>Apex: session.id (cs_test_...) and session.url
        Apex->>DB: INSERT Donacion__c (Pendiente, Referencia_Publica__c, Stripe_Session_Id__c)
        Apex-->>LWC: Checkout URL only
        LWC->>Donor: Redirects (window.location.href) to Stripe Checkout
    end

    alt Donor pays
        Donor->>Stripe: Pays with test card
        Stripe->>Donor: Redirects to /agradecimiento
        Stripe->>WH: checkout.session.completed (Header: Stripe-Signature)
    else Donor cancels
        Stripe->>Donor: Redirects to /pago-cancelado (no charge made)
    else Unpaid after 1 hour
        Stripe->>WH: checkout.session.expired
    end

    WH->>WH: Verifies HMAC-SHA256 and checks signature age < 5 minutes
    alt Invalid, missing, or expired signature
        WH->>DB: INSERT Aviso_Pasarela__c (Rechazado)
        WH-->>Stripe: HTTP 400
    else Event already Procesado or Ignorado
        WH->>DB: INSERT Aviso_Pasarela__c (Duplicado Ignorado)
        WH-->>Stripe: HTTP 200
    else Paid with matching amount and currency
        WH->>DB: UPDATE Donacion__c (Pagada, Automática, Fecha_Pago__c) looked up by Referencia_Publica__c
        DB->>Donor: DonationReceiptService sends receipt based on Modalidad__c
        WH->>DB: INSERT Aviso_Pasarela__c (Procesado)
        WH-->>Stripe: HTTP 200
    else Amount or currency mismatch
        WH->>DB: INSERT Aviso_Pasarela__c (Rechazado); donation stays Pendiente
        WH-->>Stripe: HTTP 200
    else Session expired
        WH->>DB: UPDATE Donacion__c (Expirada) + Notice Procesado
        WH-->>Stripe: HTTP 200
    else Unexpected error
        WH->>DB: Rollback + INSERT Aviso_Pasarela__c (Error)
        WH-->>Stripe: HTTP 500 (Stripe retries)
    end
```

## 2. Key Architectural Decisions (ADRs)

### ADR-01: Server-Side Stripe Checkout Sessions in a Single Transaction

- **Context:** Lightning Web Security (LWS) and Content Security Policy (CSP) in Experience Cloud restrict third-party iframes, and minimum **M3** forbids keys in code or the repository. Furthermore, Apex does not allow a callout after DML in the same transaction (`You have uncommitted work pending`).
- **Decision:** Call `POST https://api.stripe.com/v1/checkout/sessions` from Apex in a **single transaction: callout first, then DML** (`iniciarDonacion`). If Stripe fails, nothing is inserted; if it succeeds, the `Pendiente` (Pending) donation is inserted before returning the URL, satisfying `RF-D3` AC1.
- **Previous Decision (Superseded):** The two-transaction pattern `crearDonacionPendiente` + `crearSesionStripe(Id)`. It was discarded because the second guest-callable method accepted any donation Id (`M2` risk identified during audit).
- **Consequence:** Zero keys on the client, no public method receives record Ids, and an orphaned Stripe session (if the insert were to fail) simply expires without charging.

### ADR-02: Guest User Security Isolation (Minimum M2)

- **Context:** Unauthenticated public visitors need to view campaign progress and the recognition wall without direct access to `Donacion__c`.
- **Decision:** The Guest User Profile has zero permissions on `Donacion__c` or `Aviso_Pasarela__c`; it only has access to the `DonationPublicController` class, which exposes DTOs. The wall returns only **public name** (or donor name if no public name is set) and **amount**, for donations that are `Pagada` (Paid), `Con crédito` or `Con factura`, and visible (`Visible_En_Reconocimiento__c`). Never email, RFC, legal name (when a public name exists), date, or Id.
- **Consequence:** Prevents extracting emails, RFCs, or other donors' records from browser DevTools or standard Salesforce APIs.

### ADR-03: Protected Secret Storage (Minimum M3)

- **Context:** The GitHub repository is public, and any key in source code or Git history causes direct point deductions.
- **Decision:** Create `Stripe_Config__c` as a **Hierarchy Custom Setting** with `Protected` visibility. Values are loaded manually in the org and read via `Stripe_Config__c.getOrgDefaults()`.

### ADR-04: Opaque Public Reference Instead of Record Id

- **Context:** A Salesforce record Id directly identifies the database record; if it reaches the browser or Stripe, it could be used to attempt reading or modifying another donation.
- **Decision:** Every donation has `Referencia_Publica__c` (UUID, unique, immutable, auto-generated by the trigger if blank). This is the only identifier sent to Stripe (`client_reference_id`, `metadata[referencia]`) and used by the webhook to locate the donation.
- **Consequence:** Satisfies `US-06` AC5 and `US-15` AC5.

### ADR-05: Salesforce-Sent Receipts for All Modalities

- **Context:** The client noted that the gateway email would suffice, but Stripe does not send receipts in Test Mode and manual confirmation does not trigger a Stripe email (`RF-D5`, `RF-S3`).
- **Decision:** `DonationReceiptService` sends the receipt once when transitioning to `Pagada`. It only sets `Comprobante_Enviado__c = true` if sending succeeded; on failure, it records the reason in `Error_Comprobante__c` without rolling back the payment. Pending client confirmation (P4).

### ADR-06: The `Pendiente` Record Acts as a Payment Intent

- **Context:** `RF-D3` AC1 requires a `Pendiente` record before opening the gateway, whereas the client asked to create records only after successful payment.
- **Decision:** Keep the `Pendiente` record because it is a minimum guide criterion, but it never counts toward campaign progress, never appears publicly, and never triggers a receipt. It expires after 1 hour via the `checkout.session.expired` event. Pending client confirmation (P1).
