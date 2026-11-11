# Functional Evidence Guide: Thank-You, Payment Cancelled & List Views (`US-07`, `US-10`, `US-11`)

This document details the functional tests, acceptance criteria, and required screenshots to validate the public portal response pages and the staff management application list views.

---

## 1. Public Portal Response Pages (`US-07`)

### 1.1 Thank-You Page (`/md2026/agradecimiento`)

- **Objective:** Inform the donor that the donation was received and that the receipt will be sent by email once the payment is confirmed, without prematurely claiming that payment is already confirmed or that the receipt has already been sent (`US-07 AC1–AC4`, `RF-D4`).
- **Security (`M2`):** Executes no Apex calls, runs no SOQL, and reads no URL parameters (`session_id`, emails, or folios).
- **Criteria to validate:**
  - Clear main message: *"Recibimos tu donación; te enviaremos tu comprobante por correo cuando se confirme el pago."* ("We received your donation; we will send your receipt by email once payment is confirmed.")
  - Summary of Mexico Dreamin 2026's student sponsorship impact.
  - Working button *"Volver a las campañas"* ("Back to campaigns") returning to the portal root (`/md2026/`) without breaking the Experience Cloud site path.
  - Responsive design aligned with the Mexico Dreamin 2026 "Departure Board & Tickets" visual system.

### 1.2 Payment Cancelled Page (`/md2026/pago-cancelado`)

- **Objective:** Provide immediate, reassuring feedback when the donor cancels the Stripe Checkout session (`US-07 AC5`).
- **Security (`M2`):** Executes no Apex calls, runs no SOQL, and reads no URL parameters.
- **Criteria to validate:**
  - Explicit clarification: *"No se realizó ningún cargo a tu cuenta y tu donación no se registró como pagada."* ("No charge was made to your account and your donation was not recorded as paid.")
  - Clear guidance on how to retry the donation process if desired.
  - Working button *"Volver a las campañas"* ("Back to campaigns") returning to the portal root (`/md2026/`).
  - Responsive design consistent with the portal visual system.

---

## 2. Staff List Views in Donation Management (`US-10`, `US-11`)

### 2.1 View: All Donations (`Todas_las_Donaciones` — `US-10`)

- **Navigation in Salesforce:** App Launcher → **Gestión de Donaciones MD2026** → **Donaciones** tab → **Todas las Donaciones** list view.
- **Criteria to validate:**
  - Full visibility of all records (`Pagada`, `Pendiente`, `Expirada`).
  - Visible columns: Folio (`Name`), Campaign (`Campana__c`), Amount (`Monto__c`), Modality (`Modalidad__c`), Status (`Estado__c`), Confirmation Type (`Tipo_Confirmacion__c`), Requests Invoice (`Solicita_Factura__c`), Created Date (`CREATED_DATE`).
  - Ability to sort by created date or folio and filter by status.

### 2.2 View: Invoice Requests (`Solicitudes_de_Factura` — `US-11`)

- **Navigation in Salesforce:** App Launcher → **Gestión de Donaciones MD2026** → **Donaciones** tab → **Solicitudes de Factura** list view.
- **Criteria to validate:**
  - Automatic filter: displays only donations where `Solicita_Factura__c = true` (i.e., `Modalidad__c = 'Con factura'`).
  - Visible columns: Folio (`Name`), Campaign (`Campana__c`), Donor / Legal Name (`Nombre_Donante__c`), Tax ID / RFC (`RFC__c`), Taxpayer Type (`Tipo_Persona__c`: `Moral` or `Física`), Email (`Correo__c`), Amount (`Monto__c`), Status (`Estado__c`), Confirmation Type (`Tipo_Confirmacion__c`), Created Date (`CREATED_DATE`).
  - Verification that `Anónima` or `Con crédito` donations do not appear in this view.

---

## 3. Delivery Screenshot Checklist

1. **Thank-You Page (`US-07`):**
   - Screenshot of `/md2026/agradecimiento` on desktop (1440 px) and mobile (390 px).
2. **Payment Cancelled Page (`US-07`):**
   - Screenshot of `/md2026/pago-cancelado` on desktop (1440 px) and mobile (390 px).
3. **All Donations List View (`US-10`):**
   - Screenshot of the view showing records in both `Pagada` and `Pendiente` statuses.
4. **Invoice Requests List View (`US-11`):**
   - Screenshot of the view showing records with 12-character (`Moral`) and 13-character (`Física`) RFCs, verifying the `RFC__c` and `Tipo_Persona__c` columns.
