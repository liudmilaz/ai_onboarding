#!/usr/bin/env python3
"""Provision Metabase: admin user, database connection, dashboards, permissions.

Idempotent. Cards, dashboards, collections and groups are matched by name and
reused, so re-running never duplicates anything. Uses only the standard library
so it can run on a bare host.
"""
import json
import os
import time
import urllib.error
import urllib.request

BASE = "http://localhost:3000"

# Credentials come from .env, exported by start.sh. No literals here: a missing
# variable should fail loudly rather than fall back to something committed.
EMAIL = os.environ["METABASE_EMAIL"]
PASSWORD = os.environ["METABASE_PASSWORD"]
PG_USER = os.environ["POSTGRES_USER"]
PG_PASSWORD = os.environ["POSTGRES_PASSWORD"]
PG_DB = os.environ["POSTGRES_DB"]

DB_NAME = "Invented Software (analytics)"
MARTS = "analytics_marts"
READONLY_GROUP = "Analysts (read-only)"


def call(path, data=None, method=None, session=None):
    url = f"{BASE}{path}"
    body = json.dumps(data).encode() if data is not None else None
    # `data is not None`, not truthiness: an empty dict is a legitimate JSON
    # body. Using `if data` sent POST-only endpoints (sync_schema) as GET with
    # a body attached, which Metabase 404s. That was masked because Metabase
    # auto-syncs a newly created database - it only bit on re-runs.
    req = urllib.request.Request(
        url, data=body, method=method or ("POST" if data is not None else "GET"))
    req.add_header("Content-Type", "application/json")
    if session:
        req.add_header("X-Metabase-Session", session)
    with urllib.request.urlopen(req, timeout=60) as resp:
        raw = resp.read().decode()
        return json.loads(raw) if raw else {}


def wait_for_health(timeout=300):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if call("/api/health").get("status") == "ok":
                return True
        except Exception:
            pass
        time.sleep(5)
    raise SystemExit("Metabase did not become healthy in time")


def get_session():
    """Run first-time setup, or log in if it already happened.

    Gate on has-user-setup, NOT on the presence of setup-token: Metabase keeps
    returning a setup-token after setup has completed, and posting to /api/setup
    with it then fails 403.
    """
    props = call("/api/session/properties")
    if not props.get("has-user-setup"):
        res = call("/api/setup", {
            "token": props.get("setup-token"),
            "user": {
                "first_name": "Invented", "last_name": "Analyst",
                "email": EMAIL, "password": PASSWORD, "site_name": "Invented Software",
            },
            "prefs": {"site_name": "Invented Software", "allow_tracking": False},
        })
        return res["id"] if isinstance(res, dict) and "id" in res else res
    return call("/api/session", {"username": EMAIL, "password": PASSWORD})["id"]


def ensure_database(session):
    details = {
        "host": "postgres", "port": 5432, "dbname": PG_DB,
        "user": PG_USER, "password": PG_PASSWORD, "ssl": False,
        "schema-filters-type": "all",
    }
    for db in call("/api/database", session=session).get("data", []):
        if db["name"] == DB_NAME:
            # Push credentials on every run. Returning early here meant that
            # after a password rotation Metabase kept the stale password and
            # every card broke, while provisioning still printed success.
            call(f"/api/database/{db['id']}",
                 {"engine": "postgres", "name": DB_NAME, "details": details},
                 method="PUT", session=session)
            return db["id"]
    db = call("/api/database", {
        "engine": "postgres",
        "name": DB_NAME,
        "details": {
            "host": "postgres", "port": 5432, "dbname": PG_DB,
            "user": PG_USER, "password": PG_PASSWORD, "ssl": False,
            "schema-filters-type": "all",
        },
        "is_full_sync": True,
    }, session=session)
    return db["id"]


def sync_and_wait(session, db_id, tries=24):
    """Trigger one sync, then poll until the tables we query are visible.

    Two things this gets right that the obvious version does not:
      - sync_schema is called ONCE. Calling it on every poll restarts the sync
        before it can finish, so it never completes and the wait always expires.
      - a freshly registered database 404s on sync_schema for a few seconds, so
        the initial trigger is retried until it takes.
    """
    needed = {"mart_mrr_monthly", "mart_unit_economics", "fct_subscription_month"}

    for _ in range(6):                       # get the sync started
        try:
            call(f"/api/database/{db_id}/sync_schema", {}, session=session)
            break
        except urllib.error.HTTPError as exc:
            if exc.code != 404:
                raise
            time.sleep(5)

    for _ in range(tries):                   # then only observe
        try:
            meta = call(f"/api/database/{db_id}/metadata", session=session)
            present = {t["name"] for t in meta.get("tables", [])}
            if needed <= present:
                print(f"  schema synced ({len(present)} tables)", flush=True)
                return
        except urllib.error.HTTPError:
            pass
        time.sleep(5)
    raise SystemExit(f"marts never appeared in Metabase; expected {sorted(needed)}")


def remove_sample_content(session):
    """Drop Metabase's bundled H2 demo database and its ~27 example questions."""
    for db in call("/api/database", session=session).get("data", []):
        if db.get("engine") == "h2" and db.get("is_sample"):
            call(f"/api/database/{db['id']}", method="DELETE", session=session)
            print(f"  removed sample database (id {db['id']})", flush=True)


def existing_by_name(session, path, name, collection_id="__any__"):
    """Find an item by name, scoped to a collection unless told otherwise.

    Scoping matters: unscoped, this matched a trainee's own saved question with
    the same name and the provisioner then overwrote or archived it. Only
    objects inside the collection this script owns are fair game.
    """
    items = call(path, session=session)
    rows = items.get("data", items) if isinstance(items, dict) else items
    for it in rows:
        if it.get("name") != name or it.get("archived"):
            continue
        if collection_id != "__any__" and it.get("collection_id") != collection_id:
            continue
        return it["id"]
    return None


def upsert_card(session, db_id, name, sql, display, viz, collection_id):
    """Create the card, or UPDATE an existing one with the same name.

    Updating matters: matching by name alone and skipping would leave a card
    pinned to whatever SQL it was first created with. When the models renamed
    month_start to date_month, five reused cards kept querying a column that no
    longer existed and failed silently on the dashboard while provisioning
    still reported success. The definition in this file is the source of truth.
    """
    body = {
        "name": name,
        "dataset_query": {"type": "native", "native": {"query": sql}, "database": db_id},
        "display": display,
        "visualization_settings": viz or {},
        "collection_id": collection_id,
    }
    card_id = existing_by_name(session, "/api/card", name, collection_id)
    if card_id is None:
        return call("/api/card", body, session=session)["id"], "created"
    call(f"/api/card/{card_id}", body, method="PUT", session=session)
    return card_id, "updated"


def ts(dim, metric):
    """visualization_settings for a simple time series."""
    return {"graph.dimensions": [dim], "graph.metrics": [metric]}


# ---------------------------------------------------------------- dashboards
# Each card is (name, sql, display, viz, (col, row, width, height)).
# The grid is 12 columns wide.

EXECUTIVE = [
    ("MRR by month", f"""
        select date_month, mrr_eur from {MARTS}.mart_mrr_monthly order by date_month
    """, "line", ts("date_month", "mrr_eur"), (0, 0, 8, 4)),

    ("Exit ARR", f"""
        select arr_eur from {MARTS}.mart_mrr_monthly order by date_month desc limit 1
    """, "scalar", {}, (8, 0, 4, 4)),

    ("Net Revenue Retention", f"""
        select date_month, net_revenue_retention_pct
        from {MARTS}.mart_revenue_movement
        where starting_mrr_eur > 0 order by date_month
    """, "line", ts("date_month", "net_revenue_retention_pct"), (0, 4, 6, 4)),

    ("Gross margin %", f"""
        select date_month, gross_margin_pct
        from {MARTS}.mart_gross_margin_monthly order by date_month
    """, "line", ts("date_month", "gross_margin_pct"), (6, 4, 6, 4)),

    ("Logo churn %", f"""
        select date_month, logo_churn_pct from {MARTS}.mart_churn_monthly
        where merchants_at_start > 0 order by date_month
    """, "line", ts("date_month", "logo_churn_pct"), (0, 8, 6, 4)),

    ("Net burn by month", f"""
        select date_month, net_burn_eur from {MARTS}.mart_burn_monthly order by date_month
    """, "bar", ts("date_month", "net_burn_eur"), (6, 8, 6, 4)),

    ("LTV : CAC (blended)", f"""
        select ltv_to_blended_cac_ratio from {MARTS}.mart_unit_economics
    """, "scalar", {}, (0, 12, 4, 3)),

    ("Runway (months, latest)", f"""
        select runway_months from {MARTS}.mart_burn_monthly
        where runway_months is not null order by date_month desc limit 1
    """, "scalar", {}, (4, 12, 4, 3)),

    ("Unit economics scorecard", f"""
        select arpa_eur, gross_margin_pct, ltv_eur, cac_eur, blended_cac_eur,
               cac_payback_months, ltv_to_cac_ratio, ltv_to_blended_cac_ratio
        from {MARTS}.mart_unit_economics
    """, "table", {}, (8, 12, 4, 3)),
]

# Drill-downs. These query the FACT joined to its DIMENSIONS - the whole point
# of the star. None of them needed a new dbt model.
OPERATIONAL = [
    ("MRR by market", f"""
        select k.country_name, round(sum(f.mrr_eur), 2) as mrr_eur
        from {MARTS}.fct_subscription_month f
        join {MARTS}.dim_market k on f.country_code = k.country_code
        where f.date_month = (select max(date_month) from {MARTS}.fct_subscription_month)
        group by 1 order by 2 desc
    """, "bar", ts("country_name", "mrr_eur"), (0, 0, 6, 4)),

    ("MRR by business type", f"""
        select m.business_type, round(sum(f.mrr_eur), 2) as mrr_eur
        from {MARTS}.fct_subscription_month f
        join {MARTS}.dim_merchant m on f.merchant_id = m.merchant_id
        where f.date_month = (select max(date_month) from {MARTS}.fct_subscription_month)
        group by 1 order by 2 desc
    """, "bar", ts("business_type", "mrr_eur"), (6, 0, 6, 4)),

    ("MRR by plan", f"""
        select p.product_name, round(sum(f.mrr_eur), 2) as mrr_eur,
               count(*) as subscriptions
        from {MARTS}.fct_subscription_month f
        join {MARTS}.dim_product p on f.plan_sku = p.sku
        where f.date_month = (select max(date_month) from {MARTS}.fct_subscription_month)
        group by 1 order by 2 desc
    """, "bar", ts("product_name", "mrr_eur"), (0, 4, 6, 4)),

    ("Acquisition spend by channel", f"""
        select channel, round(sum(spend_eur), 2) as spend_eur
        from {MARTS}.fct_acquisition_spend group by 1 order by 2 desc
    """, "bar", ts("channel", "spend_eur"), (6, 4, 6, 4)),

    ("MRR waterfall", f"""
        select date_month, starting_mrr_eur, new_mrr_eur, expansion_mrr_eur,
               contraction_mrr_eur, churned_mrr_eur, ending_mrr_eur,
               gross_revenue_churn_pct, net_revenue_retention_pct
        from {MARTS}.mart_revenue_movement
        where starting_mrr_eur > 0 order by date_month desc
    """, "table", {}, (0, 8, 12, 5)),

    ("CAC by month (NULL where no signups)", f"""
        select date_month, acquisition_spend_eur, new_merchants, cac_eur,
               unattributed_spend_eur
        from {MARTS}.mart_cac_monthly
        where has_spend_data order by date_month
    """, "table", {}, (0, 13, 6, 5)),

    ("Operating cost by category", f"""
        select cost_category, round(sum(amount_eur), 2) as amount_eur
        from {MARTS}.fct_operating_cost group by 1 order by 2 desc
    """, "bar", ts("cost_category", "amount_eur"), (6, 13, 6, 5)),

    ("Churned merchants", f"""
        select m.merchant_name, m.business_type, k.country_name,
               m.signup_date, m.churn_date
        from {MARTS}.dim_merchant m
        join {MARTS}.dim_market k on m.country_code = k.country_code
        where m.is_churned order by m.churn_date desc
    """, "table", {}, (0, 18, 6, 5)),

    ("Ledger vs P&L divergence", f"""
        select date_month, net_cash_flow_eur, recorded_cash_change_eur,
               ledger_vs_pnl_gap_eur
        from {MARTS}.mart_burn_monthly
        where ledger_vs_pnl_gap_eur is not null order by date_month
    """, "line", ts("date_month", "ledger_vs_pnl_gap_eur"), (6, 18, 6, 5)),
]

DASHBOARDS = [
    ("Invented Software — Executive Dashboard",
     "MRR/ARR, retention, margin, churn and burn. One widget per business question.",
     EXECUTIVE),
    ("Invented Software — Operational Reports",
     "Drill-downs by market, business type, plan and channel, queried from the star schema.",
     OPERATIONAL),
]


def ensure_collection(session, name):
    cid = existing_by_name(session, "/api/collection", name)
    if cid is None:
        cid = call("/api/collection", {"name": name, "description":
                   "Invented Software analytics. Provisioned by scripts/provision_metabase.py."},
                   session=session)["id"]
        print(f"  collection created: {name}", flush=True)
    return cid


def build_dashboard(session, db_id, collection_id, name, description, cards):
    dash_id = existing_by_name(session, "/api/dashboard", name, collection_id)
    if dash_id is None:
        dash_id = call("/api/dashboard", {
            "name": name, "description": description, "collection_id": collection_id,
        }, session=session)["id"]

    dashcards = []
    for i, (card_name, sql, display, viz, (col, row, w, h)) in enumerate(cards):
        card_id, _ = upsert_card(session, db_id, card_name, sql.strip(),
                                 display, viz, collection_id)
        dashcards.append({
            "id": -(i + 1), "card_id": card_id,
            "row": row, "col": col, "size_x": w, "size_y": h,
            "parameter_mappings": [], "visualization_settings": {},
        })
    call(f"/api/dashboard/{dash_id}", {"dashcards": dashcards}, method="PUT", session=session)
    print(f"  dashboard: {name} ({len(cards)} cards)", flush=True)
    return dash_id


def archive_orphaned_cards(session, defined_names, collection_id):
    """Archive cards this script no longer defines, WITHIN its own collection.

    Without this a card dropped from a definition lingers forever, and if the
    models moved underneath it, it lingers broken. But the sweep must be scoped:
    unscoped it walked every card in the instance and deleted anything it did
    not recognise, including a trainee's own saved questions.
    """
    for card in call("/api/card", session=session):
        if card.get("archived") or card["name"] in defined_names:
            continue
        if card.get("collection_id") != collection_id:
            continue          # not ours - leave it alone
        call(f"/api/card/{card['id']}", {"archived": True}, method="PUT", session=session)
        print(f"  archived orphaned card: {card['name']}", flush=True)


def configure_permissions(session, db_id):
    """Create a read-only analyst group with view-only data access.

    Best effort: the permissions graph shape moves between Metabase versions,
    so a failure here is reported rather than fatal - the dashboards are still
    correct without it.
    """
    try:
        groups = call("/api/permissions/group", session=session)
        gid = next((g["id"] for g in groups if g["name"] == READONLY_GROUP), None)
        if gid is None:
            gid = call("/api/permissions/group", {"name": READONLY_GROUP}, session=session)["id"]
            print(f"  group created: {READONLY_GROUP}", flush=True)

        graph = call("/api/permissions/graph", session=session)
        groups_graph = graph.get("groups", {})
        groups_graph.setdefault(str(gid), {})[str(db_id)] = {
            "view-data": "unrestricted",
            "create-queries": "query-builder",   # no raw SQL for this group
        }
        call("/api/permissions/graph",
             {"revision": graph.get("revision"), "groups": groups_graph},
             method="PUT", session=session)
        print("  permissions: read-only group may query but not write SQL", flush=True)
    except Exception as exc:  # noqa: BLE001 - non-fatal by design
        print(f"  permissions step skipped ({type(exc).__name__}: {exc})", flush=True)


def main():
    print("waiting for Metabase ...", flush=True)
    wait_for_health()
    session = get_session()
    print("session established", flush=True)

    db_id = ensure_database(session)
    print(f"database id {db_id}; syncing schema ...", flush=True)
    sync_and_wait(session, db_id)
    remove_sample_content(session)

    collection_id = ensure_collection(session, "Invented Software")

    ids = []
    for name, description, cards in DASHBOARDS:
        ids.append(build_dashboard(session, db_id, collection_id, name, description, cards))

    archive_orphaned_cards(
        session, {c[0] for _, _, cards in DASHBOARDS for c in cards}, collection_id)
    configure_permissions(session, db_id)

    print("")
    for (name, _, _), dash_id in zip(DASHBOARDS, ids):
        print(f"{name}: {BASE}/dashboard/{dash_id}")
    print(f"Login: {EMAIL}  (password is in .env)")


if __name__ == "__main__":
    main()
