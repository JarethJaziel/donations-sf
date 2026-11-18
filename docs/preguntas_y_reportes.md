# Client Questions & Technical Reports Log

> **Rule (Criterion C7):** Each team member must record at least **4 individual entries across at least 2 different weeks**, always completing all **5 mandatory parts** and documenting what happened after receiving an answer.

## Discovery & Report Entries

### Entry #1 — Discovery on Invoiced Donors and Campaign Limits

- **Date:** 2026-11-04
- **Author:** Jareth Moo
- **Type:** Business Question to Client (Instructor)
1. **What we were trying to achieve (Story & Criterion):** Define acceptance criteria for `US-01` (`RF-D1a`), `US-04` (`RF-C1`), `US-05` (`RF-F1`), `US-06` (`RF-D3`), and `US-08` (`RF-D5`) regarding open questions in the project guide.
2. **What we did (Concrete steps):** Analyzed Section 4 requirements, identified 4 business ambiguities (public visibility of invoiced donors, campaign overfunding/validity, abandoned pending sessions, and minimum tax-receipt/acknowledgment data), and consulted the client.
3. **What we expected to happen:** Obtain finalized business rules to translate into verifiable *Given / When / Then* acceptance criteria.
4. **What happened (Response / Finding):** The client defined: (1) Invoiced donors always appear on the public recognition wall (name and amount only); (2) Date-expired campaigns close permanently, and each campaign has a flag allowing or blocking donations above 100% of the goal; (3) Pending donations follow Stripe's native lifecycle; (4) Receipts vary by selected donation modality.
5. **What we consulted with AI or documentation and the outcome:** Validated CFDI 4.0 tax requirements for donations and the `checkout.session` lifecycle in Stripe documentation using AI.
- **What we did afterward (Resolution):** Updated stories `US-01`, `US-04`, `US-05`, `US-08`, and `US-09` in GitHub Projects and added `Fecha_Fin__c` and `Permitir_Sobrecupo__c` to the `Campana__c` design.

---

### Entry #2 — Secret Exposure, Backlog & Contradiction Audit

- **Date:** 2026-11-08
- **Author:** Mauricio Dzay
- **Type:** Technical Finding / Planning Report
1. **What we were trying to achieve (Story & Criterion):** Confirm minimum `M3` (no Stripe keys in code or Git history) and verify that the backlog covered all RFs from Section 4 of the guide and all client answers (`C4`) before Delivery 1.
2. **What we did (Concrete steps):** Inspected all 13 commits across all branches using `git log --all -p` and regex patterns (`sk_`, `pk_`, `rk_`, `whsec_`, `force://`, session tokens), plus renames, stash, dangling objects, and `.gitignore`. Cross-checked issues `US-01` through `US-17` and the project board against the guide and client answers.
3. **What we expected to happen:** Zero secrets in Git history, one story per RF, and every client answer reflected in the backlog.
4. **What happened (Response / Finding / Exact error):** No keys exist in Git history (`M3` passes) and all 17 RFs are covered. However:
   - 4 contradictions exist between the guide and the client:
     - Creating a `Pendiente` record before payment (`RF-D3`) vs. "create the record only after a successful payment."
     - Editable goal (`RF-S1` AC2) vs. "do not change the goal of an active campaign."
     - No CFDI (`RF-F1` AC3) vs. "anyone who requests an invoice must receive one."
     - Custom Salesforce receipt (`RF-D5`) vs. "the gateway email is enough."
   - Client answers missing from the backlog:
     - campaign start date, image, and purpose;
     - past campaigns view;
     - donor-chosen public name and moderation;
     - suggested amounts up to $20,000, confirmation starting at $1,000, and gateway minimum.
   - Technical risks:
     - the webhook marks a donation as paid on any signed event without checking the event type;
     - a public method receives the donation Id;
     - the receipt is marked as sent even when email delivery fails.
   - The project board lacked a "Milestone" (`Hito`) field, and ID and Evidence fields were empty.
5. **What we consulted with AI or documentation and the outcome:** Claude Code (Claude Opus 5.5) produced the audit report. We verified three facts against official Stripe documentation:
   - the minimum amount for MXN is $10;
   - payments in Test Mode do not send automatic receipts;
   - Checkout sessions expire at 24 h by default (configurable between 30 min and 24 h).
- **What we did afterward (Resolution):**
  - Updated `US-01` through `US-17` with new criteria and a *Client Decisions & Open Questions* section.
  - Added `US-18`, `US-19`, and `US-20` for Delivery 2.
  - Recorded the 4 contradictions as provisional decisions tagged *Pending client confirmation* (`P1`–`P4`). Each question will be logged as its own entry when sent to the client.
  - Rewrote the team member prompts (execution guide v2), including a prompt to fix the existing code.

---

### Entry #3 — Stripe Checkout Rejects the `payment_method_types` Parameter

- **Date:** 2026-11-09
- **Author:** Mauricio Dzay
- **Type:** Technical Blocker Report
1. **What we were trying to achieve (Story & Criterion):** `US-06` (`RF-D3`): register the pending donation and redirect the donor to Stripe Checkout. Also `US-02` and `US-03`, which depend on the same flow.
2. **What we did (Concrete steps):** Opened the published site as an anonymous visitor, filled the form with a fictitious donor and pressed *Donate* in all three modes. Every attempt showed the generic message "No pudimos iniciar tu donación". We then reproduced the Checkout Session callout from `DonationPublicController` with the test key and read the full Stripe response.
3. **What we expected to happen:** Stripe returns a Checkout Session (`id` and `url`), the donation is saved as `Pendiente` and the browser opens the Stripe payment page.
4. **What happened (Response / Finding / Exact error):** Stripe answered `HTTP 400` (`invalid_request_error`) because the request included `payment_method_types[0]=card`. No donation was created, which is correct: the controller only inserts the record after Stripe answers successfully (single-transaction design, `RF-D3`).
5. **What we consulted with AI or documentation and the outcome:** Claude Code (Claude Opus 5.5) compared the request with the Stripe API reference for Checkout Sessions. Stripe now manages payment methods from the Dashboard (*Settings → Payment methods*), so the parameter is no longer needed. Card payments stay enabled in the test account.
- **What we did afterward (Resolution):**
  - Removed the parameter from the callout (commit [`1631b28`](https://github.com/JarethJaziel/donations-sf/commit/1631b28)). `DonationPublicControllerTest` passed 14/14 on deploy.
  - Verified on the published site as a guest that *Donate* now opens Stripe Checkout.
  - Updated the Stripe parameter list in `CLAUDE.md`, `GEMINI.md` and the agent rules so the parameter is not added back.

---

### Entry #4 — Login Page Appearing on the Public Portal

- **Date:** 2026-11-10
- **Author:** Mauricio Dzay
- **Type:** Technical Finding
1. **What we were trying to achieve (Story & Criterion):** `US-14` (`RF-V1`): the portal is public and never asks the donor to log in.
2. **What we did (Concrete steps):** After leaving the site open for several hours, reloading it showed a Salesforce login page at `/md2026/login`. Nobody on the team had added a login page. We listed the site routes in the metadata, checked the public access setting of each page, and opened the home page again in a new private window.
3. **What we expected to happen:** The home page with the active campaigns, with no login.
4. **What happened (Response / Finding / Exact error):**
   - The *Build Your Own (LWR)* template creates the Login, Register, Forgot Password, Check Password, Error, Service Not Available and Too Many Requests pages automatically. All site pages inherit public access.
   - The redirect came from an expired internal Salesforce session in the same browser (the team member was also logged into the org). A visitor with no Salesforce session never sees it.
   - In the private window, the home page loaded without login.
5. **What we consulted with AI or documentation and the outcome:** Claude Code (Claude Opus 5.5) reviewed the site metadata (`sfdc_cms__route`, `sfdc_cms__view`) and the Experience Cloud documentation on LWR template pages. The finding: the login page is part of the template and is not linked from the portal.
- **What we did afterward (Resolution):**
  - No change to the site configuration.
  - Took the `US-14` evidence from a clean session ([`US-14_portal_publico_sin_login.png`](./evidencias/portal-actual/US-14_portal_publico_sin_login.png)).
  - Recommendation for the team: test the public site in a private window, not in a browser that is logged into the org.

---

### Entry #5 — Can an Invoice Donor Stay Off the Public Wall?

- **Date:** 2026-11-17
- **Author:** Mauricio Dzay
- **Type:** Business Question to Client
1. **What we were trying to achieve (Story & Criterion):** Define how the invoice mode (`US-05`, `RF-F1`) relates to the public wall (`US-04`, `RF-C1`) and the anonymous mode (`US-03`, `RF-D2`).
2. **What we did (Concrete steps):**
   - Feedback after Delivery 1 asked that a donor who requests an invoice could also be anonymous.
   - We compared the request with the guide. `RF-D2` CA3 (a minimum) says the anonymous mode does not include an invoice. The guide also lists this open question: "Can an invoice donor ask not to appear on the public wall?"
3. **What we expected to happen:** A rule we could write as *Given / When / Then* criteria without breaking a minimum.
4. **What happened (Response / Finding / Exact error):**
   - An "anonymous with invoice" mode breaks `RF-D2` CA3, so we did not build it.
   - The version that fits the guide: the invoice donor still gives a legal name and RFC (`RF-F1`, `RF-F2`) and only chooses not to appear on the public wall.
   - We raised the question with the client. **Pending client confirmation (`P1`).**
5. **What we consulted with AI or documentation and the outcome:** Claude Code (Claude Opus 5.5) reviewed sections 4 and "Open questions" of the guide against the request and confirmed the contradiction with `RF-D2` CA3. The first story draft did allow an anonymous invoice; we rejected it for that reason.
- **What we did afterward (Resolution):**
  - Closed the first draft (`US-21`) as *not planned*.
  - Created `US-24`: a "No mostrar mi donación en el muro" checkbox, shown only in the invoice mode.
  - Implemented it: the donation is saved with `Visible_En_Reconocimiento__c = false`, still counts toward the goal, and staff still sees the invoice flag, name and RFC.
  - If the client rejects it, we remove the checkbox and close `US-24`.

---

### Entry #6 — Delivery 2 Security, Compliance & Code Audit (`US-18` to `US-24`)

- **Date:** 2026-11-17
- **Author:** Jareth Moo
- **Type:** Technical Finding / Security & Code Audit Report
1. **What we were trying to achieve (Story & Criterion):** Audit all 12 new commits pushed to `origin/main` since Delivery 1 (`a416d98..3cff89c`, covering `US-18`, `US-19`, `US-20`, `US-22`, `US-23`, `US-24`, and `US-07` impact prototype) for compliance with Critical Minimums (`M1`–`M3`), Salesforce coding standards (`C6`), LWS/accessibility, and documentation consistency before tagging `entrega-2`.
2. **What we did (Concrete steps):** Inspected `git log a416d98..origin/main` and `git diff a416d98..origin/main` across all 52 changed files (Apex classes, triggers, permission sets, validation rules, LWCs, and the 18 PNG/PDF evidence files in `docs/evidencias/entrega-2/`). Verified `Blob.toPdf()` HTML escaping in `DonationReceiptService`, `WITH SYSTEM_MODE` / `as system` usage in `DonationPublicController` and `FiltroPalabrasBloqueadas`, and the interaction of `Moderacion_Solo_Nombre_Y_Visibilidad` across Guest, Moderator, Treasury, and Webhook contexts.
3. **What we expected to happen:** Full compliance with `M1`, `M2`, and `M3`, zero governor-limit or XSS regressions, and synchronized documentation across rules and tracking logs.
4. **What happened (Response / Finding / Exact error):**
   - **Critical Minimums (`M1`, `M2`, `M3`):** **PASS.** Only `@example.com` emails and fictitious RFCs are used; the simulated invoice PDF includes the `"Sin validez fiscal – no es un CFDI"` disclaimer top and bottom; `DonationPublicController` and `FiltroPalabrasBloqueadas` keep zero Guest object permissions (`WITH SYSTEM_MODE` + DTOs only); zero Stripe keys, tokens, org IDs, or usernames appear in code, docs, or evidence binaries.
   - **HTML Escaping (`US-20`):** Verified `DonationReceiptService.construirFacturaHtml` and `fila()` escape all dynamic values via `.escapeHtml4()`.
   - **Medium Findings Identified for Follow-Up:**
     1. `FiltroPalabrasBloqueadas` is invoked in `DonationPublicController` (skipped when `ocultarDelMuro = true`), not in `DonacionTriggerHandler`, so a moderator editing `Nombre_Publico__c` or re-enabling `Visible_En_Reconocimiento__c` in Salesforce could publish a blocked word.
     2. `Moderacion_Solo_Nombre_Y_Visibilidad` omits `Stripe_Session_Id__c` and `Error_Comprobante__c` and would block a System Administrator who holds `Moderacion_Reconocimiento` without `Coordinacion_Tesoreria_Admin`.
     3. Documentation drift: `GEMINI.md` / `CLAUDE.md` / `.agents/rules/donation-portal.md` still state that invoice donors are always public (`US-24` exception not reflected) and omit `Palabra_Bloqueada__c` / `US-20` PDF details; `README.md` still shows the pre-Delivery 2 progress table (16/20).
   - **Low Findings:** Synchronous `Blob.toPdf()` inside `enviarComprobantes` loop (safe for single confirmations, monitor for bulk updates) and `FiltroPalabrasBloqueadas` static cache lacking a `@TestVisible` reset helper.
5. **What we consulted with AI or documentation and the outcome:** Used Gemini / Antigravity (`code-auditor` subagent) to inspect the full diff against `GEMINI.md` rules (`M1`–`M3`, `C6`), Salesforce LWS constraints, and Flying Saucer `Blob.toPdf()` XHTML behavior, then verified every cited line and file directly.
- **What we did afterward (Resolution):**
  - Approved integration of `origin/main` (`3cff89c`) into local `main` via fast-forward merge.
  - Documented the audit findings in this entry, `docs/contribucion.md` (Delivery 2), and `docs/bitacora_ia.md` (row #24), keeping Apex/LWC code unmodified in this sync step while tracking the 3 medium findings for team follow-up.

---

## Template for New Entries (Copy & Paste)

### Entry #X — [Descriptive Title of Question or Technical Blocker]

- **Date:** `YYYY-MM-DD`
- **Author:** `[Team member name]`
- **Type:** `[Business Question to Client / Technical Blocker Report]`
1. **What we were trying to achieve (Story & Criterion):** `[US-XX / RF-XX and specific criterion]`
2. **What we did (Concrete steps):** `[Detailed steps taken before asking]`
3. **What we expected to happen:** `[Expected outcome]`
4. **What happened (Response / Finding / Exact error):** `[Observed behavior or client answer]`
5. **What we consulted with AI or documentation and the outcome:** `[Official sources or prompts reviewed]`
- **What we did afterward (Resolution):** `[Change applied to code, design, or stories]`
