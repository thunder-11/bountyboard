# Bountyboard

A complete local bug and feature bounty application: **React frontend, Express REST API, MySQL 8.0/InnoDB, and MongoDB 7**. Backers pledge INR from internal wallets; contributors claim issues and submit reviewed PRs; maintainers release ordered milestones; administrators resolve disputes. There is no external payment gateway or platform fee.

## Run locally

Prerequisites: Node.js 22 or later, npm, Docker Desktop running with Linux containers, and free local ports **5173, 3001, 3308, 27019**.

Run these commands from the project directory:

```powershell
npm ci
docker compose up -d --wait
npm run db:setup
npm run db:seed
npm run dev
```

Open **[http://127.0.0.1:5173](http://127.0.0.1:5173)**. The API is at **[http://127.0.0.1:3001/api/health](http://127.0.0.1:3001/api/health)**. Setup creates `.env` from `.env.example` when absent. Existing `.env` settings are preserved. The frontend proxies `/api` to Express with changeOrigin:false, preserving the browser-facing Host header for the API origin check; cookies remain same-origin.

The seed command refuses to run when users already exist. It never resets existing data. To repeat the demonstration from a clean checkpoint, choose unused `MYSQL_DATABASE` and `MONGO_DATABASE` names in `.env`, stop the application, then run setup, seed, and dev again. Previous databases and Docker volumes are preserved.

### Demo accounts

All 15 seeded accounts use **`BountyDemo!2026`**. The sign-in picker is visible when `DEMO_MODE=true`.

| Account | Email | Roles |
|---|---|---|
| Nina Shah | user_01@demo.invalid | ADMIN |
| Maya Patel | user_02@demo.invalid | MAINTAINER of all four repositories |
| Arjun Rao | user_03@demo.invalid | MAINTAINER of all four repositories |
| Leena Das | user_04@demo.invalid | MAINTAINER of all four repositories |
| Owen Park | user_05@demo.invalid | MAINTAINER of all four repositories |
| Riya Sen | user_06@demo.invalid | CONTRIBUTOR + BACKER |
| Dev Mehta | user_07@demo.invalid | CONTRIBUTOR |
| Alex Chen | user_08@demo.invalid | CONTRIBUTOR |
| Sam Reed | user_09@demo.invalid | CONTRIBUTOR |
| Zoya Ali | user_10@demo.invalid | BACKER + CONTRIBUTOR |
| Priya Nair through Noah Kim | user_11@demo.invalid through user_15@demo.invalid | BACKER |

Sign out at the bottom of the sidebar to switch roles. Roles combine but ADMIN does not inherit maintainer powers.

## What is implemented

- Responsive overview, searchable/filterable issue board, repository scopes, issue workspaces, wallet ledger, reputation history, leaderboards, and administration.
- User/password sign-in, signed HttpOnly sessions, logout revocation, role and repository authorization, same-origin mutation checks, and login throttling.
- Exclusive seven-day claims; timely PR submission; current-revision approvals and change requests; rejection and merge workflows.
- INR pledges with a ₹10 minimum, once-only deadline extension, voluntary pre-claim withdrawal, automatic expiry refunds, and maintainer closure.
- Percent-based contributor splits and ordered milestones with deterministic largest-remainder allocation in paise.
- Dispute freeze and ADMIN resume/refund rulings, including overdue deadline processing and reputation deductions.
- Append-only journals, ledger, releases, payouts, refunds, reviews, reputation and audit logs; automatic lifecycle triggers; reconciliation reports.
- Four MongoDB collections with validators/indexes, durable MySQL outbox, idempotent majority-write delivery, safe Markdown rendering, threaded comments, code snippets, commits, and eight aggregation pipelines.
- Docker setup, deterministic seed verification, unit tests, isolated database/API/concurrency tests, and desktop/mobile browser tests.

## Quick workflow walkthrough

1. Sign in as **Riya Sen**. Open overview, wallet, and leaderboards. The initial wallet balance is ₹140.00.
2. Open **issue 28**, back it with ₹10.01, claim it, and submit a PR with Riya at 100%.
3. Sign in as **Maya Patel**, open issue 28's Pull requests tab, and approve with a comment.
4. Repeat approval as **Arjun Rao** and **Leena Das**. Issue 28 belongs to `nova/docs`, which requires **three distinct approvals**.
5. As a maintainer, merge the PR, then use the final milestone's **Resolve** control and confirm **Resolve & pay**.
6. Return to Riya's wallet. The ₹10.01 pledge has been earned back through a recorded payout. Issue 28 is RESOLVED.
7. Open **issue 1** as a maintainer to demonstrate the preconfigured 20/30/50 milestones and 70/30 contributor allocation.
8. Open **issue 7** as Nina Shah to inspect and rule on its frozen dispute. Use Administration → Verify accounting after financial changes.

Seeded repositories require 1, 2, 1, and 3 approvals respectively: `acme/parser`, `orbit/ui`, `atlas/core`, `nova/docs`. PR contributors cannot review or merge their own work, even when they also hold MAINTAINER.

## Accounting and concurrency

All money is stored as DECIMAL(12,2), accepted as decimal strings, and allocated using integer-paise arithmetic. No balance update is trusted from the browser.

The public stored procedures use `(actor_id, request_key, payload_json, OUT result_json)`. The API derives actor_id from the authenticated session. Procedures own READ COMMITTED transactions, serialize each issue with explicit row locks, lock workflow records in a fixed order, and lock wallets in ascending user ID. At this demo scale all wallets are locked for financial operations, trading some concurrency for a simple global lock-order guarantee. Successful request keys replay the committed result; changed payloads are rejected. Deadlock/timeout retries are bounded to three attempts.

Ledger insertion updates cached wallet/escrow balances through a trigger, inside the same transaction. Each financial commit checks:

```text
issue pledges = held escrow + releases + refunds
wallet balance = sum of its signed ledger entries
each journal's signed entries = 0
each release = sum of payouts = sum of originating pledge funding
wallet balances + held escrow = authorized issuance
```

The exactly verified seed checkpoint contains **15 users, 4 repositories, 30 issues, 40 pledges, 20 PRs**, 52 journals, 108 ledger entries, 314 audit rows, and 236 operation records. Its totals are:

```text
₹1,460.01 pledged = ₹1,090.01 held + ₹320.00 released + ₹50.00 refunded
₹6,000.00 issuance = ₹4,909.99 wallets + ₹1,090.01 held
```

Minute events advance due issue 25 and claim 23 after seeding, so their statuses and history counts subsequently change. The five headline entity counts remain unchanged until users create new records. To keep S0 stationary for a presentation, set `ENABLE_JOBS=false` before seeding or run:

```powershell
node scripts/jobs.js disable
node scripts/jobs.js status
node scripts/jobs.js enable
```

Setup creates events disabled; seeding enables them when `ENABLE_JOBS=true`. Running setup again recompiles routines and disables the events; use `jobs.js enable` afterwards to resume automatic expiry. ADMIN can also run due jobs from the UI.

## Verification

```powershell
npm test
npm run test:integration
npm run build
npm run test:e2e
npm run verify
npm run test:docs
```

Unit tests check money validation, allocation, passwords, sessions, and content limits. Integration tests provision an isolated `bountyboard_test_<timestamp>` MySQL database and matching MongoDB database, seed and verify them, then test real API/SQL/MongoDB behavior and concurrent operations. Browser tests also provision their own database, run the built frontend at port 3111, and run the real development proxy at port 5111. They verify login/logout and origin rejection through both serving paths.

The current automated suites contain **9 unit, 37 integration, and 11 browser tests**. `npm run verify` checks the running main application's API/frontend, InnoDB engines, SQL objects, MongoDB counts, and all accounting deltas without changing its business data. The PRD's 100-request performance targets and forced-deadlock exercises remain manual acceptance checks; they are not represented as measured performance guarantees.

On Windows, browser tests use installed Microsoft Edge in headless mode. On other platforms, install Playwright Chromium with `npx playwright install chromium`. To use installed Chrome on Windows, set `PLAYWRIGHT_CHANNEL=chrome`. Test screenshots, traces, and the HTML report are written to ignored `test-results/` and `playwright-report/` directories. Only the test namespace created by that invocation is removed during cleanup; the main database is preserved.

For a local build without Vite's dev server:

```powershell
npm run build
npm start
```

Open [http://127.0.0.1:3001](http://127.0.0.1:3001). `npm start` serves both the built frontend and API. Production hosting is outside this mini project's scope. Production mode additionally requires HTTPS and a private session secret; demo credentials are for local use.

## API conventions

Authentication uses `bounty_session`, an HttpOnly SameSite=Strict cookie. Sessions expire after eight hours and are revoked on sign-out; restarting the server invalidates in-memory sessions. No token is stored in localStorage. Financial endpoints require a UUID `Idempotency-Key` header; clients must reuse that key when retrying the same intended action.

Success: `{ "data": ... }`. Failure: `{ "error": { "code": "E_FUNDS", "message": "...", "retryable": false }, "request_key": "..." }`. IDs and monetary values are strings. Monetary input uses `"10.01"`, not a JSON number. Only native MySQL deadlocks/timeouts are automatically retried.

The complete endpoint list, DTOs, permissions, functional requirements and UI routes are in **PRD.md section 7**. The eight content pipeline endpoints are `/api/content/pipelines/M-01` through `M-08`; parameters are `issue_id`, `root_comment_id`, `token`, `from`, and `to` according to the pipeline. Audit, reconciliation and outbox routes are ADMIN-only.

## Project structure

| Path | Responsibility |
|---|---|
| `src/` | React pages, workflow dialogs, API client, responsive styling |
| `server/app.js` | Authenticated REST endpoints, validation, permission-facing responses |
| `server/auth.js` | scrypt passwords, session signing/validation/revocation |
| `server/db.js` | MySQL pool, procedure invocation/retry, MongoDB client |
| `server/content.js` | Collection validators/indexes, outbox worker, eight aggregations |
| `server/reports.js` | Leaderboards, health metrics, consistent report snapshots |
| `server/money.js`, `server/errors.js`, `server/config.js` | Exact arithmetic helpers, named errors, environment configuration |
| `server/index.js` | HTTP server and worker lifecycle |
| `db/schema.sql`, `db/views.sql`, `db/routines.sql` | 28 tables, relational reports, transactional workflow logic |
| `db/errors.sql`, `db/public-routines.sql`, `db/triggers.sql`, `db/events.sql` | Generated SQL error mappings, public adapters, audit/ledger/immutability triggers, minute jobs |
| `scripts/generate-db.js` | Reproducible generation of the four derived SQL files |
| `scripts/setup.js`, `scripts/seed.js`, `scripts/jobs.js` | Schema installation, exact S0 fixture, event controls |
| `scripts/dev.js`, `scripts/test-database.js`, `scripts/verify.js`, `scripts/validate-docs.js` | Local services, isolated test provisioning/cleanup, and read-only running-system verification |
| `tests/`, `tests/vite-proxy.config.js`, `playwright.config.js` | Unit, integration, and browser verification |
| `compose.yaml`, `.env.example`, `package.json`, `package-lock.json`, `vite.config.js`, `index.html`, `.gitignore` | Local infrastructure, configuration, dependencies, build entrypoints |
| `PRD.md`, `progress.md`, `README.md` | Specification, work checkpoints, run instructions |

Generated SQL is committed as readable deliverables and regenerated on setup. Financial operations run inside MySQL procedures; MongoDB content cannot authorize payouts. The worker uses majority writes and idempotent event IDs; an outage leaves intent pending rather than discarding it.
