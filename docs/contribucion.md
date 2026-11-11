# Contribution Log

One table per milestone. For each member: the stories and tasks they worked on, the evidence that backs it (commits, AI log entries, screenshots) and approximate hours.

**How the data was collected**
- **Stories:** assignees on the [backlog board](https://github.com/users/JarethJaziel/projects/7).
- **Commits:** `git log` of the `main` branch. Each hash links to the commit on GitHub.
- **AI log entries:** row numbers (`#`) in [`bitacora_ia.md`](./bitacora_ia.md).
- **Hours (approx.):** estimated from commit history. Commits by the same author less than 3 hours apart form one work session. Each session counts its span plus 1 hour for the work before its first commit. This is a lower bound: it misses work that produced no commit, such as org configuration, Stripe setup, testing in the org and recording the demo video.

## Delivery 1 (`entrega-1`, 2026-11-10)

| Member | Stories and tasks | Evidence | Hours (approx.) |
|---|---|---|---|
| **Jareth Moo** (`JarethJaziel`) | Project setup and data model (`Campana__c`, `Donacion__c`, `Aviso_Pasarela__c`, `Stripe_Config__c`). Agent rules and docs templates. Staff app, layouts, list views and permission set (US-09, US-10, US-11, US-13). Manual payment confirmation and receipt service (US-12, US-08). Stripe webhook with signature check and idempotency (US-16, US-17). Apex tests. Public webhook execution and security docs. Polish of the thank-you and cancelled pages (US-07). Documentation translation to English and evidence for US-08 to US-13 and US-16. | Commits: [`a72989d`](https://github.com/JarethJaziel/donations-sf/commit/a72989d), [`1f370a4`](https://github.com/JarethJaziel/donations-sf/commit/1f370a4), [`c3f0b18`](https://github.com/JarethJaziel/donations-sf/commit/c3f0b18), [`33dd0bb`](https://github.com/JarethJaziel/donations-sf/commit/33dd0bb), [`2454ffd`](https://github.com/JarethJaziel/donations-sf/commit/2454ffd), [`726ada2`](https://github.com/JarethJaziel/donations-sf/commit/726ada2), [`7ec231d`](https://github.com/JarethJaziel/donations-sf/commit/7ec231d), [`f09ef1a`](https://github.com/JarethJaziel/donations-sf/commit/f09ef1a), [`a416d98`](https://github.com/JarethJaziel/donations-sf/commit/a416d98) and 17 more (26 total). AI log: #1–#5, #14–#18. Questions log: Entry #1. Screenshots: [`evidencias/entrega-1/`](./evidencias/entrega-1/) (US-08 to US-13, US-16). | ~15 h (3 sessions; 2026-11-05, 06, 09, 10) |
| **Mauricio Dzay** (`Villanueva112`) | Public donation portal: Experience Cloud site `/md2026`, `DonationPublicController` and the campaign, donation form and recognition wall components (US-01 to US-06, US-14). Departure-board visual design. Corrections to the data model and backend (member 1 review). Fix for Stripe Checkout rejecting `payment_method_types`. Agent rules aligned with the deployed backend. Evidence screenshots for US-01 to US-06 and US-14. | Commits: [`dd1de10`](https://github.com/JarethJaziel/donations-sf/commit/dd1de10), [`e170c59`](https://github.com/JarethJaziel/donations-sf/commit/e170c59), [`1cf86d3`](https://github.com/JarethJaziel/donations-sf/commit/1cf86d3), [`41d03a7`](https://github.com/JarethJaziel/donations-sf/commit/41d03a7), [`06dcee2`](https://github.com/JarethJaziel/donations-sf/commit/06dcee2), [`1631b28`](https://github.com/JarethJaziel/donations-sf/commit/1631b28), [`a598e1e`](https://github.com/JarethJaziel/donations-sf/commit/a598e1e), [`37bc215`](https://github.com/JarethJaziel/donations-sf/commit/37bc215) (8 total). AI log: #6–#12. Questions log: Entry #2. Screenshots: [`evidencias/portal-actual/`](./evidencias/portal-actual/). | ~9 h (4 sessions; 2026-11-08, 09, 10) |
| **Aureo Alfaro** (`AureoIAlfaro`) | Thank-you and payment-cancelled pages (US-07). View guides for all donations and invoice filtering (US-10, US-11). Restoration of the AI log. Evidence for US-07 and US-10. | Commits: [`516fa5e`](https://github.com/JarethJaziel/donations-sf/commit/516fa5e), [`4f326b3`](https://github.com/JarethJaziel/donations-sf/commit/4f326b3), [`ba41d25`](https://github.com/JarethJaziel/donations-sf/commit/ba41d25), [`e4833fb`](https://github.com/JarethJaziel/donations-sf/commit/e4833fb), [`b8523fd`](https://github.com/JarethJaziel/donations-sf/commit/b8523fd), [`8a562d0`](https://github.com/JarethJaziel/donations-sf/commit/8a562d0) (6 total). AI log: #13. Screenshots: [`evidencias/entrega-1/`](./evidencias/entrega-1/) (US-07, US-10). | ~3 h (2 sessions; 2026-11-08, 09, 10) |
| **Roberto Moreno** (`RobertoMoreno-riptide`) | Product analysis and QA. Assigned on the board: guest security test (US-15). | No commits or AI log entries in the repository as of this delivery. | — |

## Delivery 2 (`entrega-2`, 2026-11-17)

| Member | Stories and tasks | Evidence | Hours (approx.) |
|---|---|---|---|
| Jareth Moo | | | |
| Mauricio Dzay | | | |
| Aureo Alfaro | | | |
| Roberto Moreno | | | |
