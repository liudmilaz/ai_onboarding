# System Operation Manual

**Phase 6 deliverable.** How to run, refresh, troubleshoot and recover the
Invented Software analytics platform.

---

## 1. Prerequisites

| Requirement | Check | If missing |
|---|---|---|
| Docker CLI | `docker --version` | `brew install docker` |
| Compose | `docker compose version` | `brew install docker-compose` |
| Colima | `colima version` | `brew install colima` |
| Python 3.9+ | `python3 --version` | ships with macOS |

Docker Desktop is deliberately **not** used: it requires a paid licence for
business use, which conflicts with the open-source-only constraint. Colima is
Apache-2.0.

## 2. Running

```bash
./start.sh             # start or resume, rebuild models, refresh dashboards
./start.sh --clean     # destroy containers and volumes first (cold-start proof)
./start.sh --refresh   # reload CSVs and rebuild, leaving containers running
./start.sh --help
```

Everything lands at <http://localhost:3000>:

| Dashboard | URL |
|---|---|
| Executive | <http://localhost:3000/dashboard/2> |
| Operational | <http://localhost:3000/dashboard/3> |

The login is in `.env`. That file is generated on first run with random
passwords, is `chmod 600`, and is gitignored — it is never committed.

**Every run is logged** to `logs/run-<timestamp>.log`, tee'd so a run stays
watchable while remaining auditable.

### Measured timings

| Operation | Time | Requirement |
|---|---|---|
| Cold start (`--clean`) | 261 s | — |
| Data refresh (`--refresh`) | **53 s** | under 60 s ✅ |
| `dbt build` (warm) | ~3 s | — |
| Dashboard load, warm | **1.2–2.9 s** | under 3 s ✅ |
| Dashboard load, cold cache | ~8.6 s | ⚠️ exceeds on first load only |

## 3. Refreshing data

Replace the CSVs in `saas/`, then:

```bash
./start.sh --refresh
```

Three things happen in order, and each is a gate:

1. **Schema contract check** (`scripts/validate_csv_schema.py`). Nothing touches
   the database until the CSVs match `db/schema_contract.json` on column names,
   **order**, types and nullability.
2. **Transactional reload** (`db/refresh.sql`). `TRUNCATE … CASCADE` then `COPY`,
   wrapped in a transaction — a failure rolls back and leaves the previous data
   intact. A partial reload would be worse than none, because the models would
   build cleanly on half a dataset.
3. **Rebuild and re-provision.** `dbt build` (102 tests) then Metabase.

### Why the schema contract exists

`COPY` maps columns by **position**, not by name. Swapping two same-typed
columns loads without any error and silently corrupts every downstream number.
The contract catches exactly that:

```
raw_markets  column ORDER changed: expected [country_code, country_name, region, …]
                                   got      [country_code, region, country_name, …]
```

If a schema change is **intended**, accept it explicitly:

```bash
python3 scripts/validate_csv_schema.py --generate
git add db/schema_contract.json && git commit -m "Accept new source schema"
```

## 4. Troubleshooting

`start.sh` traps errors and reports the failing step, line, command, log path and
a targeted hint. Start there. The failure modes actually encountered:

| Symptom | Cause | Fix |
|---|---|---|
| Auth error right after deleting `.env` | Postgres bakes the password in at initdb; a regenerated `.env` does not match an existing volume | `./start.sh --clean`, or restore the old `.env`. `start.sh` now detects this and says so |
| `DATA QUALITY GATE FAILED: …` | Row counts or referential integrity are wrong after a load | The message names the failing check; inspect with `db/validate.sql` |
| `MALFORMED CSV … wrong field count` | A truncated or over-long row | Fix the source file; the line number is reported |
| `colima start` hangs silently, no output | Defaulted to QEMU, which is not installed | `colima start --vm-type vz --cpu 4 --memory 8 --disk 60` |
| `unknown shorthand flag: 'd' in -d` | Homebrew installed the Compose plugin only for the installing user | `mkdir -p ~/.docker/cli-plugins && ln -sf $(which docker-compose) ~/.docker/cli-plugins/docker-compose` — `start.sh` also auto-detects |
| Colima VM missing after reboot | The VM does not survive reboot, and is **per-user** | `colima start --vm-type vz`; a working VM on another account does not help |
| `could not translate host name "postgres"` | dbt runs on the host, not in the compose network | Profile must use `localhost:5433`, the published port |
| Metabase 403 on `/api/setup` | Setup already ran; a `setup-token` is still returned afterwards | Handled — provisioning gates on `has-user-setup` |
| Dashboard card shows an error | Card SQL is stale relative to the models | Re-run `./start.sh`; provisioning **updates** cards to match code |
| `SCHEMA CONTRACT BREACHED` | A CSV changed shape | Intended? `--generate`. Unintended? Fix the source |

### Health checks

```bash
docker compose ps                                     # both should be healthy
curl -s localhost:3000/api/health                     # {"status":"ok"}
docker compose exec -T postgres pg_isready -U analytics -d invented_software
docker compose logs --tail=50 postgres metabase
```

### Verifying the data is right

```bash
cd dbt && ../.venv/bin/dbt test --profiles-dir profiles
```

`assert_known_kpi_values` pins MRR to €1,138 / €1,641 / €1,510 and blended gross
margin to 84.9%, the figures in `HANDOFF.md` §4. **If it fails, the models
drifted — the data did not.** `assert_source_integrity` checks row counts,
currency consistency, date ordering and status/churn agreement.

## 5. Backup and recovery

The database holds nothing that is not reproducible from `saas/` plus this
repository, so the recovery procedure is simply a clean rebuild:

```bash
./start.sh --clean
```

Metabase application state (dashboards, cards, users, permissions) lives in the
`metabase` database inside the same Postgres volume, and is fully reconstructed
by `scripts/provision_metabase.py` on every run. **Nothing configured by hand in
the Metabase UI will survive a `--clean`** — if you want it permanent, add it to
the provisioning script.

To back up the volume anyway:

```bash
docker compose exec -T postgres pg_dumpall -U analytics > backup.sql
```

## 6. Capacity

Measured against the executive dashboard, each simulated user fetching the
dashboard then all nine cards:

| Concurrent users | Total | Errors |
|---|---|---|
| 1 | 4.05 s | 0 |
| 5 | 6.79 s | 0 |
| 10 | 12.78 s | 0 |
| 20 | 22.94 s | 0 |

Degradation is graceful and roughly linear; Metabase stayed healthy throughout.
The dataset is ~3,200 fact rows, so the database is never the constraint —
Metabase's query pipeline is.

## 7. Security notes

- Credentials are generated per-checkout and never committed. `.env` is
  gitignored and `chmod 600`.
- A read-only **Analysts** group exists with query-builder access but no native
  SQL rights.
- Both services bind to **`127.0.0.1` explicitly** in `docker-compose.yml`.
  Docker's default `"5433:5432"` form binds `0.0.0.0`, which would put the
  database on the LAN; the loopback prefix is what makes this note true.
- This is a **local training deployment**. Before anything resembling production:
  put Postgres behind a network boundary, enable TLS on Metabase, rotate the
  generated credentials into a secret manager, and replace the single shared
  admin account with per-user SSO.
