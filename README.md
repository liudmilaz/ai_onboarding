# AI Onboarding — SaaS Analytics Platform

A training project for data analysts learning AI-assisted development, plus the
platform built from it.

The repository is split so the starting point and the result can be read
separately — and diffed against each other.

| Folder | What it is |
|---|---|
| **[`initial/`](initial/)** | The project exactly as issued: the dataset, the requirements, and the mentoring playbook. Nothing here was written during the build. |
| **[`final/`](final/)** | The working analytics platform built from it — Postgres, dbt and Metabase, containerized. |

---

## `initial/` — the starting point

Six CSVs describing **Invented Software**, a fictional B2B SaaS company selling
business-management software to small merchants across 8 markets. Revenue is
subscription-only: 160 merchants, 117 subscriptions, two years of costs.

| File | Purpose |
|---|---|
| `saas/*.csv` | The dataset — merchants, subscriptions, products, markets, acquisition and operating costs |
| `Requirements.md` | The full project spec: six phases, deliverables, architecture constraints |
| `CLAUDE.md` | The mentoring playbook — how Claude is meant to teach the project |
| `HANDOFF.md` | Setup notes, data conventions, and expected results to check models against |

These files are **preserved unmodified**. The six CSVs are byte-identical to the
ones the platform in `final/` reads, which matters because the dataset contains
two deliberate problems that were solved in the models rather than patched in
the data.

## `final/` — the built platform

```
saas/*.csv → Postgres (raw) → dbt (25 models) → Metabase (2 dashboards, 18 cards)
                    └──────── Docker Compose ────────┘
```

```bash
cd final && ./start.sh
```

Cold start to live dashboards in about four minutes. See
[`final/README.md`](final/README.md) for detail and
[`final/docs/`](final/docs/) for the business requirements, architecture
decision records, database schema, operations manual and AI process report.

All eleven SaaS KPIs are built: MRR, ARR, logo churn, revenue churn, NRR, LTV,
CAC, CAC Payback, LTV:CAC, Gross Margin, Burn Multiple and Cash Runway.

## The two problems left in the data on purpose

Both were found during discovery and resolved as **modelling decisions**, not by
editing the CSVs. They are the most instructive thing in the dataset.

**The cash ledger contradicts the P&L by €85,519.** Recorded cash rises across
2024–25 while revenue minus costs implies a €3,253/month burn. Regression shows
the cash series is a function of *time*, not of the business — monthly change is
linear in `t` at R² = 0.971, correlating +0.985 with the clock and only +0.401
with revenue. Burn is therefore derived from the P&L, with the divergence
exposed per month rather than hidden.

**CAC has no single honest answer.** The last merchant signed up 2024-06-29, yet
€16,856 of acquisition spend is booked across 2025 — money that acquired nobody.
Attributed CAC is €165.73 and blended CAC is €705.20, giving an LTV:CAC of
**5.52 or 1.30** depending on which question you are asking. Both are reported.

## History

The two folders arrive as separate pull requests so the starting point and the
solution stay legible independently.
