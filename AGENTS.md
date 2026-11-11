# Antigravity & Agent Instructions: Mexico Dreamin 2026 Donation Portal

This repository enforces strict architecture, security, and development rules for Salesforce and Stripe.

## Core Rules & Critical Minimums

- Review the detailed rules and requirements in [`.agents/rules/donation-portal.md`](./.agents/rules/donation-portal.md) or [`GEMINI.md`](./GEMINI.md).
- **M1:** 100% Test Mode (Sandbox Org and Stripe Test Mode). Real personal data is strictly prohibited.
- **M2:** Least privilege on the Guest User Profile. Direct CRUD access to `Donacion__c` is prohibited. Expose only Wrapper/DTO classes in Apex.
- **M3:** Zero secrets in code or Git history. `Stripe_Config__c` is configured directly in the Org.

## Mandatory Documentation

- Every relevant session must be logged in [`docs/bitacora_ia.md`](./docs/bitacora_ia.md) (Criterion C3).
- Business questions and agreements are recorded in [`docs/preguntas_y_reportes.md`](./docs/preguntas_y_reportes.md) (Criterion C7).
