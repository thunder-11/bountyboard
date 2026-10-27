# GitHub publication — 27 October 2026

- Initialized Git on main and configured origin as https://github.com/thunder-11/bountyboard.git.
- Destination was empty before publication.
- Prepared application source, SQL, tests, PRD, README and this progress log for the initial push.
- Excluded .env, node_modules, dist, caches, logs and browser test artifacts. Secret-pattern scan found only the documented session-secret placeholder.
- Latest validation: production build and all 13 browser tests passed.

# Project restarted — 27 October 2026

- Started existing MySQL and MongoDB containers; both healthy.
- Started frontend http://127.0.0.1:5173/ and API http://127.0.0.1:3001/.
- Existing data preserved.

# Workspace selector fix — 27 October 2026

- Replaced the decorative workspace card with an interactive, keyboard-accessible disclosure.
- Clicking it opens All repositories and the available repository destinations; selection updates the issue scope, clears search, closes the menu and mobile navigation.
- Current repository appears beneath the workspace name. Escape and focus leaving the control close the menu.
- PASS: production build and all 13 browser tests, including pointer, Enter/Escape keyboard interaction, repository filtering and mobile selection.
- Browser tests used isolated databases; application data preserved.

# Logout and navigation fixes — 27 October 2026

- Added a labeled Logout button in the header, visible on desktop and mobile, using the existing session-revoking endpoint.
- Unified logout handling, disabled repeated clicks during sign-out, surfaced errors, and cleared account-specific UI state after successful logout.
- Fixed sidebar clipping at short viewport heights/browser zoom with independent vertical scrolling and non-shrinking navigation sections.
- Kept the account footer inside the sidebar width; repository selection and navigation links close the mobile drawer even when the route stays the same.
- On narrow screens, removed the header search/avatar to keep Logout reachable; issue-board search remains available.
- PASS: production build and all 12 browser tests. Verified every primary navigation link, repository filters, short-height sidebar scrolling, desktop/mobile logout, and revoked wallet access. Visually inspected the short-height screenshot.
- Existing application data preserved; browser tests used isolated databases.

# Project startup — 27 October 2026

- Started the existing Docker Compose MySQL and MongoDB containers; both are healthy.
- Started frontend at http://127.0.0.1:5173/ and backend at http://127.0.0.1:3001/.
- Verified frontend HTTP 200 and API health: MySQL and MongoDB connected.
- npm run verify passed with zero accounting discrepancies. Existing data preserved (15 users, 4 repositories, 30 issues, 41 pledges, 20 PRs).
# Login origin fix — 27 October 2026

- User reported the sign-in error "Cross-origin mutations are forbidden" on http://127.0.0.1:5173.
- Reproduced: dev-proxy login returned403; direct API login returned200.
- Root cause: Vite's string proxy shorthand sets changeOrigin:true, rewriting Host to127.0.0.1:3001 while the browser Origin remains127.0.0.1:5173.
- Fixed vite.config.js to use an explicit proxy object with changeOrigin:false. The backend same-origin guard was preserved.
- Added tests/vite-proxy.config.js and an additional Playwright webServer so the actual development proxy is tested against an isolated API/database.
- Added a browser regression covering ADMIN sign-in, authenticated profile, rejection of an attacker Origin, logout and subsequent401 through the dev proxy.
- Live verification: same-origin dev login now200; foreign-origin request still403.
- PASS: all11 browser tests, including the new development-proxy sign-in/security regression; no failed tests.
- Current total:57 automated cases (9 unit +37 integration +11 browser); unchanged suites retain their previous passing results.
- The existing dev server reloaded vite.config.js automatically. Refresh the browser page and retry sign-in; no data reset or credentials change is required.

# Current status — complete

Updated 27 October 2026. The full local application requested by the user is implemented. This section supersedes all historical documentation-only boundaries and incomplete checklists below.

## Completed work

- [x] Extend PRD.md with frontend, authentication, REST endpoints, DTOs, UI routes, acceptance criteria, API tests, implementation decisions, and actual project paths.
- [x] Implement responsive React frontend: overview, searchable/filterable issue board, detailed workflows, wallets, leaderboards, reputation, and administration.
- [x] Implement authenticated Express API, server-derived identity, role/repository authorization, signed HttpOnly sessions, logout revocation, same-origin mutation checks, input validation and named errors.
- [x] Implement MySQL schema, 25 named public procedure adapters, transaction dispatcher, financial/workflow helpers, functions, views, audit/immutability/ledger triggers and automatic expiry events.
- [x] Implement four MongoDB collections, validators/indexes, eight aggregation pipelines, durable outbox and idempotent majority-write delivery.
- [x] Seed and verify all 28 original table counts, including 15 users, 4 repositories, 30 issues, 40 pledges and 20 PRs.
- [x] Verify financial conservation, largest-remainder payout splitting, partial refunds, dispute freeze/rulings, review revisions and concurrent operations.
- [x] Complete README.md with setup, demo credentials, role switching, jobs, testing, configuration and source structure.
- [x] Install final routines/index into the main demo database, preserve its records, and enable both minute jobs.
- [x] Run build, unit, integration, browser, documentation and live-system checks.

## Verification results

| Check | Result |
|---|---|
| npm test | PASS: 9 unit tests |
| npm run test:integration | PASS: 37 real MySQL/MongoDB/API/concurrency tests in an isolated database |
| npm run test:e2e | PASS: 10 headless Edge browser tests, including desktop/mobile, failure recovery, administration, and pledge → claim → PR → three approvals → merge → payout |
| npm run build | PASS: production frontend bundle |
| npm run test:docs | PASS: 18 headings, 28 matching dictionaries/ER/schema entities, 27 Given/When/Then FRs, 75 documented SQL objects, all references/table widths, valid JSON examples, no prohibited vague language |
| npm run verify | PASS: MySQL and MongoDB healthy, built frontend responds, all reconciliation deltas zero |
| SQL objects | 28 InnoDB tables, 5 views, 39 procedures/functions, 34 triggers, 2 enabled events |
| MongoDB seed corpus | 30 bodies, 10 comments, 6 snippets, 6 commit logs |
| Original S0 financial totals | Verified 1460.01 pledged = 1090.01 held + 320.00 released + 50.00 refunded; 6000.00 supply = 4909.99 wallets + 1090.01 held |
| Current live totals after automatic expiry | Verified 1460.01 pledged = 1080.01 held + 320.00 released + 60.00 refunded; 6000.00 supply = 4919.99 wallets + 1080.01 held |
| Dependency versions | All 11 exact dependency pins agree with package-lock.json; npm install reported zero vulnerabilities |

56 automated test cases passed. The PRD contains 67 formal acceptance cases; those IDs are specification cases, not a claim that every manual performance/forced-deadlock exercise has been executed. The 100-request performance targets and forced-deadlock exercises remain manual acceptance checks, as stated in README.md.

## Running application

- Frontend: http://127.0.0.1:5173
- Built frontend and API: http://127.0.0.1:3001
- Health endpoint: http://127.0.0.1:3001/api/health
- Current development launcher: npm run dev; restart with that command if the local processes have stopped.
- Demo password: BountyDemo!2026 for seeded accounts.
- Contributor/backer: user_06@demo.invalid (Riya Sen).
- Maintainers: user_02@demo.invalid through user_05@demo.invalid.
- Administrator: user_01@demo.invalid (Nina Shah).
- Issue 28 belongs to nova/docs and requires three distinct maintainer approvals; the README and browser test demonstrate the full flow.
- Main database name: bountyboard. Test databases use a timestamped bountyboard_test_ namespace and are cleaned up without touching main data.

## Operational decisions and preservation

- MySQL owns all financial/workflow authority; MongoDB owns content; all money remains INR DECIMAL(12,2).
- Procedure signatures use actor_id, request_key, payload_json and OUT result_json. The API derives actor identity from the session.
- READ COMMITTED transactions explicitly lock issue/escrow/workflow rows and all demo wallets in ascending ID; largest-remainder allocation uses integer paise.
- Ledger insertion alone updates cached balances. Audit and append-only histories are protected by triggers and runtime grants.
- Seeding refuses a nonempty users table. Repeating a demo uses a new named database rather than deleting existing user data.
- Setup recompiles routines and leaves events disabled; seeding or node scripts/jobs.js enable resumes automatic expiry.
- Docker initially interrupted MySQL's first empty initialization. The incomplete original volume was preserved, and a fresh mysql_data_v1 volume was initialized successfully.
- No deployment or external payments were attempted. No unrelated repository or database data was changed.

## Resume instructions

The requested implementation is complete. For follow-up changes, read PRD.md, README.md, this current checkpoint, and the source. Run npm run verify before assuming the local server is still active. Preserve main records, keep progress.md current, and use isolated test databases for mutations in automated checks.

# Historical checkpoints

The content below records prior phases and intermediate verification. Its former incomplete statuses and documentation-only restrictions are historical and are superseded by the current completion checkpoint above.

# Progress

## Task

Create `PRD.md` for the Collaborative Bug & Feature Request Platform with Bounty Payouts, following the attached request and approved plan. Maintain this file at the user's additional request. Produce specifications only, with no implementation SQL or application code.

## Status

- [x] Read the attached requirements and approved plan.
- [x] Confirm the workspace has no existing project files or repository instructions.
- [x] Record the added requirement to maintain `progress.md`.
- [x] Complete the domain model, accounting rules, and state machines.
- [x] Complete functional requirements and stored routine catalog.
- [x] Complete reporting, MongoDB, and concurrency specifications.
- [x] Complete seed data, demo, tests, and traceability.
- [x] Validate identifiers, coverage, arithmetic, and prohibited language.
- [x] Append the final self-check and deliver the Markdown files.

## Design checkpoints

- MySQL 8.0/InnoDB owns financial and workflow state; MongoDB 7 owns document content.
- All financial operations use READ COMMITTED and explicit row locks.
- Lock order: issue, escrow, workflow records, wallets in ascending user_id, ledger/audit inserts.
- Disputes preserve the base issue status and freeze financial operations.
- Percent allocation uses integer paise and the largest-remainder method.
- Partial milestone releases are preserved; only unreleased pledge funds are refundable.
- Every added policy will be recorded in section 18 of PRD.md.
- PRD sections 1–6 are drafted, including 28 relational entities, seven state-machine tables, the ER diagram, and BR-01 through BR-42.
- Merge freezes the net funded pool; FIFO release_funding attribution supports exact partial refunds.
- A final PR rejection reopens the issue and cancels its claim; a review change-request alone does not reject the PR.
- The milestone exception to whole-issue completion-before-payment is explicit in section 1.
- Sections 7–12 now include FR-01 through FR-20, procedure/function/event/trigger contracts, Q-01 through Q-11, M-01 through M-08, C-01 through C-10, and measurable NFRs.
- PR share_revision invalidates old approvals deterministically after contributor-share edits.
- Seed, demo, tests, decision log, and final validation are complete.
- All 18 sections are drafted: 57 tests (31 negative), 18 demo steps, and all 11 traceability rows.
- First validation pass: 28 dictionary entities match all 28 ER entities; all 66 routine/trigger/event/function names resolve; four JSON examples parse; all Markdown tables have consistent column counts; all 20 FRs have G/W/T criteria; no prohibited vague expressions were found.
- Corrected individual seed-wallet balances by recomputing all 40 pledges and all payout/refund recipients. Total wallet balance remains 4909.99; escrow 1090.01; supply 6000.00.
- Final semantic corrections include current-share-revision review eligibility, explicit error precedence, fresh locked-time checks, complete freeze action definitions, conditional release replay, full lock-order references, and all deliberate denormalization notes.

## Final validation results

| Check | Result |
|---|---|
| Required headings | PASS: all 18, in the required order |
| Domain coverage | PASS: 28 dictionaries, 28 matching ER entities, all 28 exact seed counts |
| Requirements and traceability | PASS: 42 BRs, 20 FRs with explicit Given/When/Then, 11 feature/core traceability rows |
| Database object references | PASS: all 66 procedure/function/event/trigger names resolve |
| Reports and content pipelines | PASS: Q-01–Q-11 and M-01–M-08 resolve; four example JSON documents parse |
| Workflow coverage | PASS: 41 transition rows have actors and guards; ten concurrency scenarios |
| Demo and test coverage | PASS: 18 demo steps, 57 tests, 31 negative test cases |
| Markdown and language | PASS: consistent table widths; no prohibited vague expressions |
| Seed arithmetic | PASS: 1460.01 pledged = 1090.01 held + 320.00 released + 50.00 refunded |
| Supply reconciliation | PASS: 6000.00 issuance = 4909.99 wallet balances + 1090.01 escrow |
| Historical row counts | PASS: 236 operations, 52 journals, 108 ledger entries, 314 audit entries |
| Rounding | PASS: stages 200.00/300.00/500.01; final 70/30 payout 350.01/150.00; equal split 10.01 gives 5.01/5.00 |
| Completed demo arithmetic | PASS: 1470.02 pledged = 1140.01 released + 110.01 refunded + 220.00 held; 6100.00 supply = 5880.00 wallets + 220.00 held |

Validation was performed against the Markdown specification with read-only parsing and independent integer-paise calculations. Database integration tests are specified for future implementation and were not executed because this task produces documentation only.

## Deliverables

- `E:\Ali\DBMS\PRD.md`: complete specification with the final seven-item PASS checklist.
- `E:\Ali\DBMS\progress.md`: this completed progress and validation checkpoint.
- No implementation files or database changes were created. No work remains for the requested documentation task.

## Resume instructions

The documentation task is complete. For a later revision, read this file and `PRD.md`, record the requested changes here, and rerun the relevant document and arithmetic checks. Do not create implementation artifacts without a new implementation request. The original request is at `C:\Users\patha\.codex\attachments\cadad6f5-3b11-4199-a984-a9d93da8ad5c\Pasted text.txt`.

# Application implementation — current task

The user authorized updating the PRD and implementing the frontend, backend API, and complete application. This supersedes the documentation-only delivery boundary above. Preserve the original financial/database requirements.

## Current status
- [x] Inspect original specification and available runtimes.
- [x] Scaffold React/Vite frontend, Express backend, local database containers, and package scripts.
- [ ] Update frontend/API requirements and implementation decisions in PRD.md.
- [x] Implement MySQL schema, transactions, procedures, views, triggers, functions, and expiry events.
- [x] Implement MongoDB validators, pipelines, and outbox delivery.
- [x] Implement authenticated REST API and role checks.
- [x] Implement responsive application pages and workflow forms.
- [x] Seed and reconcile the required demo dataset.
- [ ] Run unit, database integration, frontend build, and browser tests.
- [ ] Document run commands and final verification/limitations.

## Environment
Node v24.14.1 and npm 11.11.0 are installed. Docker 29.4.0 / Compose 5.1.1 is installed; its engine was initially stopped, and Docker Desktop was started in the background. Dependencies are installed. MySQL 8.0.46 and MongoDB 7 containers are healthy. Main frontend/API were started on ports 5173/3001. A fresh mysql_data_v1 project volume was used after Docker interrupted initialization of the first empty volume; no user data was deleted.

## Resume point
Inspect the checklist above, package.json, and the source directories. Continue implementation without resetting user data or changing the fixed MySQL/MongoDB/INR requirements. Update this section at each checkpoint.

## Verification checkpoint — 27 October 2026

- Frontend production build passes; 9 unit tests pass; all 33 real database/API/concurrency integration tests pass.
- All 28 S0 counts and all accounting totals match the original specification, including 314 audit rows and 236 operations.
- First browser run passed 7/9 tests. Corrected decorative avatar accessibility; the full workflow test now obtains all three reviews required by issue 28's repository. Browser suite rerun is in progress.
- PRD now includes FR-21 through FR-27, frontend routes, REST endpoints, authentication, validation and response conventions. Remaining documentation alignment: actual file paths, added helper contracts, exact installed versions and seed display names.
- Remaining verification: browser suite, final rerun after adding explicit ordered workflow locks, main-database routine refresh, final reconciliation, and run instructions check.



