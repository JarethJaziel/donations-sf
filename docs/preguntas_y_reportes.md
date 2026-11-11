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
