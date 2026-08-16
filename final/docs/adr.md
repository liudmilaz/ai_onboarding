# Architecture Decision Records

**Phase 2 deliverable.** One record per significant technology decision.
ADRs are immutable: when a decision changes, a new record supersedes the old one
so the reasoning chain stays visible. Consequences include the bad ones — a
record listing only benefits is marketing, not a decision log.

---

## System architecture

```
saas/*.csv
     │  db/init/03_load.sql   (COPY, on first container boot)
     ▼
┌─────────────────────────────────────────┐
│ Postgres 16          container: postgres│
│                                          │
│  raw.*                  landing zone     │
│  analytics_staging.*    type + FX + units│
│  analytics_intermediate.*  spine         │
│  analytics_marts.*      star + KPIs      │
└─────────────────────────────────────────┘
     ▲                        │
     │ dbt (host, .venv)      │ port 5433 published
     │ profiles.yml           ▼
     │                  ┌──────────────────────────┐
     └──────────────────│ Metabase   container      │
        service name    │ 2 dashboards, 18 cards    │
        postgres:5432   │ read-only analyst group   │
                        └──────────────────────────┘
                                   │ :3000
                                   ▼
                                 browser
```

Both containers are declared in `docker-compose.yml` with healthchecks gating
startup order. `start.sh` orchestrates: Colima → containers → data quality gate →
`dbt build` → Metabase provisioning.

---

## ADR-001: PostgreSQL as the analytical database

**Status:** Accepted (2026-08-15). Supersedes nothing. Amended by ADR-006.

**Context.** `Requirements.md` mandates an open-source, locally deployed,
containerized stack. Candidates: PostgreSQL, MySQL, SQLite, DuckDB. The dataset
is tiny — 160 merchants, 117 subscriptions, a 3,200-row fact table — so
performance is not a differentiator at any realistic scale.

**Decision.** PostgreSQL 16 (Alpine image), in Docker Compose.

**Consequences.**
- Universal ecosystem support: dbt, Metabase and every BI tool speak Postgres
  first. Metabase has no first-class DuckDB driver, which alone rules DuckDB out
  as the serving layer.
- Real client/server concurrency. A file-based engine is single-writer, which
  breaks the moment a scheduler and a person touch it together.
- **Postgres is a row-store built for transactions.** For analytical scans a
  columnar engine is genuinely better. Choosing it here is a choice for
  ecosystem and realism, not for analytical performance — claiming otherwise
  would be false.
- Requires a load step (`COPY`) that a CSV-native engine would not.

---

## ADR-002: Metabase as the BI platform

**Status:** Accepted (2026-08-15)

**Context.** Shortlist: Metabase, Lightdash, Apache Superset, Grafana. All open
source and self-hostable. The build ran under a three-hour budget on a heavily
throttled connection.

Lightdash is the more interesting fit for a dbt-centric project: it is
dbt-native, so model descriptions and tests written in Phase 4 flow into its
semantic layer rather than being re-expressed. But it requires a Node stack plus
the dbt project mounted, and its setup is click-through. Metabase is a single
container and exposes an HTTP API for provisioning.

**Skill/plugin/MCP availability** was checked per `Requirements.md`:
`ListPlugins` returned empty and the org catalogue had no match for any
candidate. No tool on the shortlist had Claude Code skill support, so that
criterion did not discriminate.

**Decision.** Metabase v0.50.21, provisioned entirely by
`scripts/provision_metabase.py`.

**Consequences.**
- The whole BI layer rebuilds from clean in 261 s with zero clicks: admin user,
  database connection, two dashboards, 18 cards, a collection and a permissions
  group.
- **Cards are native SQL, so dbt metadata does not reach the BI layer.** Model
  descriptions and tests are re-expressed by hand. This is the real, ongoing
  cost of not choosing Lightdash.
- The API is under-documented and cost roughly 40 minutes across three defects
  (see ADR-005).
- Revisit if the semantic layer becomes important or drill-downs outgrow native
  SQL.

---

## ADR-003: Docker Compose with Colima as the container runtime

**Status:** Accepted (2026-08-15)

**Context.** Containerization is mandated twice — as an architecture constraint
and as a learning objective. Docker Desktop requires a paid licence for business
use, conflicting with the open-source-only constraint.

**Decision.** Colima (Apache-2.0) providing the Docker daemon, with the standard
Docker CLI and Compose.

**Consequences.**
- Reproducible, version-pinned services; `docker compose down -v` gives a
  genuine clean-state reset, which is how every verification claim here was
  established.
- **Three environment traps, each of which cost real time:**
  - Colima needs `--vm-type vz` on Apple Silicon. The default falls back to
    QEMU, which is not installed, and then **hangs silently** rather than
    erroring — the worst possible failure mode.
  - The Colima VM and its image cache are **per-user**. A second account on the
    same Mac starts from zero even when another account has a working VM.
  - Homebrew installs the Compose CLI plugin only for the installing user. On
    another account `docker compose` fails with `unknown shorthand flag: 'd'`.
    `start.sh` detects plugin vs standalone binary rather than assuming.
- The VM does not survive reboot: `colima start` is needed each session.
- Ironic but worth stating: containers exist to eliminate "works on my machine",
  and getting the container runtime installed is the part that is not
  containerized.

---

## ADR-004: Kimball star schema for the mart layer

**Status:** Accepted (2026-08-16). Supersedes the flat per-metric marts.

**Context.** The first build used the common dbt pattern: one wide
pre-aggregated table per metric (`mart_mrr_monthly`, `mart_churn_monthly`).
That is a *reporting* architecture, not a *dimensional* one, and it is rigid —
`mart_mrr_monthly` can answer "MRR by month" and nothing else. Phase 5 requires
operational drill-downs, which pre-aggregated tables structurally cannot serve.

**Decision.** A conformed star: `dim_date`, `dim_merchant`, `dim_product`,
`dim_market`; facts `fct_subscription_month`, `fct_acquisition_spend`,
`fct_operating_cost`, `fct_cash_balance`. `channel` and `cost_category` remain
degenerate dimensions. Every fact declares its grain and additivity class in its
header.

**Consequences.**
- **All nine operational drill-downs required zero new dbt models.** MRR by
  market, by business type, by plan, spend by channel — each is a join from fact
  to dimension. That is the entire justification, and it paid off immediately.
- Kimball's **additivity** framework names the dataset's worst trap precisely:
  `mrr_eur` is semi-additive (never sum across time), `spend_eur` is fully
  additive, `cash_balance_eur` is semi-additive (last() only). A non-additive
  stock stored alongside additive flows in one column is a **grain violation** —
  which is exactly what `cash_balance_eom` is, and why separating it makes the
  16× error structurally impossible rather than merely documented.
- **At this scale Kimball buys nothing in performance.** 3,200 fact rows. The
  entire case is modelling discipline, drill-down capability, and using the
  vocabulary a BI architect is expected to work in.
- More models to maintain: 25 versus 12.

---

## ADR-005: Provisioning is code, and reuse means update

**Status:** Accepted (2026-08-16)

**Context.** Metabase state (dashboards, cards, permissions) is mutable server
state. Configured by hand it cannot be reviewed, versioned, or rebuilt.

**Decision.** `scripts/provision_metabase.py` is the single source of truth.
Everything is matched by name and **updated** to match the definition in code.

**Consequences.**
- The BI layer is reviewable in a pull request and reproducible from nothing.
- Three defects were found only by **executing every card** rather than trusting
  provisioning's own success output. All three are the same class of bug —
  something reported success while being wrong:
  - `sync_schema` was called on every poll iteration, restarting the sync before
    it could finish, so the wait always expired.
  - Cards matched by name were **skipped**, keeping the SQL they were first
    created with. When the star renamed `month_start` to `date_month`, five
    cards silently failed on the dashboard while provisioning reported success.
  - A card dropped from a definition lingered in the question list, broken.
    Orphans are now archived.
- Verification must therefore run the cards, not just count them. `18/18
  returning data` is the only claim worth making.
- A later review found three more of the same class, all invisible to a passing
  run: `call()` chose its HTTP method on the *truthiness* of the body, so
  `sync_schema` went out as GET and 404'd - masked entirely because Metabase
  auto-syncs a newly created database, so it only failed on re-runs;
  `archive_orphaned_cards` swept the whole instance rather than its own
  collection, so a trainee's saved question would be archived; and
  `ensure_database` returned early without pushing credentials, so a password
  rotation broke every card while provisioning printed success. All three are
  fixed and scoped to the provisioned collection.

---

## ADR-006: Consolidate on Postgres; withdraw the DuckDB target

**Status:** Accepted (2026-08-15). Amends ADR-001.

**Context.** When the Colima image download stalled on a throttled connection, a
DuckDB target was added so work could continue without containers. It read the
CSVs directly via `external_location` and rebuilt in 6 s. Both targets ran the
same models, differing only in one Jinja conditional for the series generator.

It was appealing — fast local loop, realistic deployment target. But it was a
workaround for a network problem, not a design goal.

**Decision.** Remove DuckDB. Postgres is the only target.

**Consequences.**
- One code path. No `target.type` conditional, no risk of the two silently
  diverging, no ambiguity about which is "real."
- Matches the mandated architecture rather than quietly failing it.
- Measurement that informed this: with containers already running, `dbt build`
  takes **1.39 s on Postgres** versus ~1.3 s on DuckDB. The DuckDB advantage was
  never build speed — it was avoiding infrastructure entirely. The 210 s figure
  was cold start, not model build.
- **Lost: the ability to work when Docker is broken.** On the day this was
  decided, that situation was real. Accepted deliberately.
- Also removed the static HTML dashboard generator, which depended on
  `warehouse.duckdb`. Metabase is the BI layer.

---

## ADR-007: Credentials are generated, never committed

**Status:** Accepted (2026-08-15)

**Context.** The first working stack hard-coded `analytics/analytics` and a
Metabase admin password across four files. Both were invented during
development — neither came from the project, and no external service sits behind
them — but the pattern is what gets copied into the next repository.

**Decision.** `start.sh` generates `.env` with `openssl rand` on first run
(chmod 600, gitignored). `docker-compose.yml` uses `${VAR:?}`, `profiles.yml`
uses `env_var()` with no default, and the provisioning script reads
`os.environ`. `.env.example` documents the variables.

**Consequences.**
- No secret literals in the repository; a missing variable fails loudly instead
  of falling back to a committed value.
- Two checkouts never share a password.
- History mattered: the credentials existed in seven local commits. Squashing to
  a single commit before the first push meant they never reached GitHub —
  changing only the working tree would have been cosmetic.
- The first implementation used `tr -dc … </dev/urandom | head -c 32`, which
  dies of SIGPIPE under `set -o pipefail`. `openssl rand -hex` needs no pipe.
