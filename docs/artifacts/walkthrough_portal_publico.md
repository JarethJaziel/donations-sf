# Walkthrough: Public Portal & Stripe Checkout (Member 2)

**Date:** 2026-11-08  
**Stories:** `US-01`, `US-02`, `US-03`, `US-04`, `US-05`, `US-06`, `US-14`  
**Origin:** Section 1 prompt from the team execution guide v2 and Section 6 of [`CLAUDE.md`](../../CLAUDE.md).  
**Status:** Deployed and published in the team sandbox. Tested as an anonymous visitor.

---

## 1. Experience Cloud Site

| Item | Value |
|---|---|
| Name | Portal Donaciones MD2026 |
| Template | Build Your Own (LWR) |
| Public path | `/md2026` (the `/donaciones` path belongs to a legacy org site) |
| Status | Live, public guest access enabled |
| Pages | `/` (portal), `/agradecimiento`, `/pago-cancelado` |

- The `/agradecimiento` and `/pago-cancelado` pages hold accurate **provisional text** (never claiming payment is confirmed and clarifying no charge was made). Member 3 replaces them with `paginaAgradecimiento` and `paginaPagoCancelado`.
- The site is versioned under `digitalExperiences/` and `digitalExperienceConfigs/`. `networks/` and `sites/` metadata **are not committed to the repository** (listed in `.gitignore`) because they contain the sender email and admin username; they are deployed only from a local machine.
- After deploying changes to components or pages, run: `sf community publish --name "Portal Donaciones MD2026"`.

## 2. Guest User (`M2`)

- Profile `Portal Donaciones MD2026 Perfil` (versioned in `profiles/`): access **only** to `DonationPublicController`.
- **Zero object and field permissions** on `Donacion__c`, `Campana__c`, and `Aviso_Pasarela__c` (verified live in the org).
- Guest profiles do not appear under Setup → Profiles; open them via Experience Builder → Settings → General → Guest User Profile.

**Implementation finding:** With the profile set to zero permissions, the initial version failed with `sObject type 'Campana__c' is not supported` and then `No such column 'Descripcion__c'`. In guest context, Salesforce enforces schema visibility even inside Apex. Rather than granting read permissions to the guest (which would expose email and RFC schemas), the controller uses `WITH SYSTEM_MODE` on queries and `insert as system`. Tested live with zero profile permissions: queries execute without errors (guest log: campaigns `Rows:1`, wall `Rows:0`).

## 3. `DonationPublicController`

| Method | Behavior | Stories |
|---|---|---|
| `obtenerCampanasActivas()` (cacheable) | Campaigns where `Vigente__c = true`; DTO containing name, description, purpose, image, goal, raised amount, percentage, end date, eligibility flag, and closure reason | US-01 |
| `obtenerMuroDonantes(Id campanaId)` (cacheable) | Paid donations with credit or invoice and visible flag; DTO containing **only** public name (or donor name) and amount. Passing a non-campaign Id returns an empty list | US-04, US-15 AC5 |
| `iniciarDonacion(SolicitudDonacionDTO)` | Validates input, creates Stripe session, then inserts the `Pendiente` donation; returns **only** the Checkout URL | US-02, US-03, US-05, US-06 |

Server-side validations in `iniciarDonacion`:

- Campaign must be active (`Vigente__c = true`) and accepting donations.
- Amount must be at least $10.00 MXN with at most 2 decimal places; no application-side maximum.
- Email is required and must have a valid format.
- Modality rules:
  - **Anónima:** clears donor name, public name, and RFC.
  - **Con crédito:** requires donor name and clears RFC.
  - **Con factura:** requires legal name and a valid RFC via `RfcValidator`.

Parameters sent to Stripe:

- `client_reference_id` and `metadata[referencia]` set to the UUID (never the Salesforce record Id).
- `expires_at` = 1 hour.
- `submit_type=donate`, `locale=es`, `currency=mxn`, and amount in cents (`unit_amount`).
- `success_url` and `cancel_url` from `Stripe_Config__c`.
- `Idempotency-Key` header set to the public reference.

If Stripe fails, nothing is inserted and the donor sees a generic Spanish error message.

**Tests:** `DonationPublicControllerTest`, 14 tests, 100% coverage. Covering:

- active, future, inactive, and full campaigns;
- recognition wall omitting email, RFC, and dates;
- Stripe request body omitting the record Id;
- invalid amounts, invalid donor data, and RFCs with nonexistent dates;
- passing a donation Id as the campaign Id;
- Stripe HTTP error and incomplete JSON response;
- missing `Stripe_Config__c` and DML insert failure.

## 4. LWC Components

| Component | Exposed | Behavior |
|---|---|---|
| `portalCampanasPublico` | Yes (dragged onto page) | Campaign list with image, description, progress bar, and deadline; opens detail directly when only one campaign is active (`US-01 AC8`); detail view with purpose; embeds the form and wall |
| `formularioDonacionPublico` | No (child) | 8 suggested amounts + custom input; live validation of amount, email, name, and RFC (matching `RfcValidator`); switching to `Anónima` clears name, public name, and RFC; confirmation dialog starting at $1,000; redirects to Stripe |
| `muroDonantesPublico` | No (child) | Public name and amount only; auto-scrolls starting at 6 donors, pauses on hover or focus, and respects `prefers-reduced-motion` |

All UI texts are in Spanish and responsive. Components never store donor data in browser storage or the URL.

## 5. Org Configuration (Not Stored in Repository)

- `Stripe_Config__c`:
  - `Success_URL__c` = `<site>/md2026/agradecimiento`
  - `Cancel_URL__c` = `<site>/md2026/pago-cancelado`
- **Pending:** the **Stripe test secret key** (`Secret_Key__c`). Until configured, the form shows *"El pago en línea no está disponible en este momento"* ("Online payment is not available right now"). A team member must configure it in Setup → Custom Settings → Stripe Config → Manage. Never write it in the repository or in a chat.
- The existing campaign now has start date and purpose set, so it appears on the portal.

## 6. How to Test

1. Open `https://<site-domain>/md2026` in an **incognito window** (with an active Salesforce session you enter as admin rather than guest).
2. Verify the campaign, progress, and recognition wall.
3. Choose $2,000: the confirmation dialog must appear.
4. Test an amount of $9.99, an invalid email, and an RFC dated February 30: the form must block all three.
5. With the Stripe key configured:
   - pay using the test card `4242 4242 4242 4242`: you should return to `/agradecimiento`, and in Salesforce the donation appears as **Pendiente** with its public reference;
   - cancel in Stripe: you should return to `/pago-cancelado`.
   Automatic confirmation (transition to `Pagada`) arrives via webhook in Delivery 2.

## 7. Pending Items

- Configure the Stripe test key in the org.
- Member 3: thank-you and payment-cancelled components.
- Member 4: Guest User security verification (`US-15`) and seed data.
- Run `sf code-analyzer run` on a machine with Java 11+.
- Verify the full end-to-end payment flow once the key is configured (guest `insert as system` has only been exercised in unit tests so far).
