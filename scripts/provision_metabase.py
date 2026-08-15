#!/usr/bin/env python3
"""Provision Metabase from scratch: admin user, database connection, cards, dashboard.

Idempotent-ish: if setup has already run, it logs in with the known credentials
instead. Uses only the standard library so it can run on a bare host.
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


def call(path, data=None, method=None, session=None):
    url = f"{BASE}{path}"
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, method=method or ("POST" if data else "GET"))
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
        token = props.get("setup-token")
        res = call("/api/setup", {
            "token": token,
            "user": {
                "first_name": "Invented", "last_name": "Analyst",
                "email": EMAIL, "password": PASSWORD, "site_name": "Invented Software",
            },
            "prefs": {"site_name": "Invented Software", "allow_tracking": False},
        })
        return res["id"] if isinstance(res, dict) and "id" in res else res
    return call("/api/session", {"username": EMAIL, "password": PASSWORD})["id"]


def ensure_database(session):
    for db in call("/api/database", session=session).get("data", []):
        if db["name"] == DB_NAME:
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


def native_card(session, db_id, name, sql, display, viz=None):
    return call("/api/card", {
        "name": name,
        "dataset_query": {
            "type": "native",
            "native": {"query": sql},
            "database": db_id,
        },
        "display": display,
        "visualization_settings": viz or {},
    }, session=session)


CARDS = [
    ("MRR by month", f"""
        select month_start, mrr_eur
        from {MARTS}.mart_mrr_monthly
        order by month_start
    """, "line", {"graph.dimensions": ["month_start"], "graph.metrics": ["mrr_eur"]}),

    ("Exit ARR", f"""
        select arr_eur
        from {MARTS}.mart_mrr_monthly
        order by month_start desc
        limit 1
    """, "scalar", {}),

    ("Active merchants by month", f"""
        select month_start, active_merchants
        from {MARTS}.mart_mrr_monthly
        order by month_start
    """, "bar", {"graph.dimensions": ["month_start"], "graph.metrics": ["active_merchants"]}),

    ("Gross margin %", f"""
        select month_start, gross_margin_pct
        from {MARTS}.mart_gross_margin_monthly
        order by month_start
    """, "line", {"graph.dimensions": ["month_start"], "graph.metrics": ["gross_margin_pct"]}),

    ("Logo churn %", f"""
        select month_start, logo_churn_pct
        from {MARTS}.mart_churn_monthly
        where merchants_at_start > 0
        order by month_start
    """, "line", {"graph.dimensions": ["month_start"], "graph.metrics": ["logo_churn_pct"]}),
]

LAYOUT = [(0, 0, 6, 4), (6, 0, 6, 4), (0, 4, 6, 4), (6, 4, 6, 4), (0, 8, 12, 4)]


DASH_NAME = "Invented Software — Executive Dashboard"


def sync_and_wait(session, db_id, tries=10):
    """Ask Metabase to sync, then poll until the marts are actually visible.

    A freshly registered database 404s on sync_schema for a few seconds, and a
    202 only means the sync was queued - not that tables exist yet. Poll for the
    tables we are about to query rather than sleeping a fixed interval.
    """
    needed = {"mart_mrr_monthly", "mart_gross_margin_monthly", "mart_churn_monthly"}
    for attempt in range(tries):
        try:
            call(f"/api/database/{db_id}/sync_schema", {}, session=session)
        except urllib.error.HTTPError as exc:
            if exc.code != 404:
                raise
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
    """Drop Metabase's bundled H2 demo database.

    It ships ~27 example questions about Doohickeys and Gizmos, which clutter
    the question list and make it ambiguous which cards are actually ours.
    """
    for db in call("/api/database", session=session).get("data", []):
        if db.get("engine") == "h2" and db.get("is_sample"):
            call(f"/api/database/{db['id']}", method="DELETE", session=session)
            print(f"  removed sample database (id {db['id']})", flush=True)


def existing_by_name(session, path, name):
    items = call(path, session=session)
    rows = items.get("data", items) if isinstance(items, dict) else items
    for it in rows:
        if it.get("name") == name and not it.get("archived"):
            return it["id"]
    return None


def main():
    print("waiting for Metabase ...", flush=True)
    wait_for_health()
    session = get_session()
    print("session established", flush=True)

    db_id = ensure_database(session)
    print(f"database id {db_id}; syncing schema ...", flush=True)
    sync_and_wait(session, db_id)
    remove_sample_content(session)

    dash_id = existing_by_name(session, "/api/dashboard", DASH_NAME)
    if dash_id is None:
        dash_id = call("/api/dashboard", {
            "name": DASH_NAME,
            "description": "MRR/ARR, gross margin and logo churn from the dbt marts.",
        }, session=session)["id"]

    dashcards = []
    for i, (name, sql, display, viz) in enumerate(CARDS):
        card_id = existing_by_name(session, "/api/card", name)
        if card_id is None:
            card_id = native_card(session, db_id, name, sql.strip(), display, viz)["id"]
            print(f"  card created: {name}", flush=True)
        else:
            print(f"  card reused:  {name}", flush=True)
        x, y, w, h = LAYOUT[i]
        dashcards.append({
            "id": -(i + 1), "card_id": card_id,
            "row": y, "col": x, "size_x": w, "size_y": h,
            "parameter_mappings": [], "visualization_settings": {},
        })

    call(f"/api/dashboard/{dash_id}", {"dashcards": dashcards}, method="PUT", session=session)
    print(f"\nDashboard ready: {BASE}/dashboard/{dash_id}")
    print(f"Login: {EMAIL}  (password is in .env)")


if __name__ == "__main__":
    main()
