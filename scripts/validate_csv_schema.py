#!/usr/bin/env python3
"""Validate the CSVs in saas/ against a schema contract before they are loaded.

Why this exists: the loader is `COPY`, which fails loudly on a type mismatch but
silently accepts a column ORDER change - it maps by position, not by name. A
refresh that swapped two same-typed columns would load cleanly and corrupt every
downstream number with no error anywhere. This checks names, order, types and
nullability before a single row reaches the database.

    validate_csv_schema.py --check      exit 1 on any breach   (default)
    validate_csv_schema.py --generate   rewrite the contract from the CSVs

Standard library only.
"""
import csv
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAAS = os.path.join(ROOT, "saas")
CONTRACT = os.path.join(ROOT, "db", "schema_contract.json")

DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
INT = re.compile(r"^-?\d+$")
NUM = re.compile(r"^-?\d+(\.\d+)?$")


def classify(values):
    """Narrowest type that fits every non-empty value."""
    vals = [v for v in values if v != ""]
    if not vals:
        return "text"
    if all(DATE.match(v) for v in vals):
        return "date"
    if all(INT.match(v) for v in vals):
        return "integer"
    if all(NUM.match(v) for v in vals):
        return "numeric"
    return "text"


def profile(path):
    with open(path, newline="") as fh:
        rows = list(csv.reader(fh))
    header, body = rows[0], rows[1:]
    cols = []
    for i, name in enumerate(header):
        values = [r[i] for r in body if i < len(r)]
        cols.append({
            "name": name,
            "type": classify(values),
            "nullable": any(v == "" for v in values),
        })
    return {"columns": cols, "row_count": len(body)}


def tables():
    return sorted(f[:-4] for f in os.listdir(SAAS) if f.endswith(".csv"))


def generate():
    contract = {t: profile(os.path.join(SAAS, t + ".csv")) for t in tables()}
    os.makedirs(os.path.dirname(CONTRACT), exist_ok=True)
    with open(CONTRACT, "w") as fh:
        json.dump(contract, fh, indent=2)
        fh.write("\n")
    print(f"wrote contract for {len(contract)} tables -> {os.path.relpath(CONTRACT, ROOT)}")


def check():
    if not os.path.exists(CONTRACT):
        sys.exit(f"no contract at {CONTRACT}; run with --generate first")
    contract = json.load(open(CONTRACT))
    breaches = []

    missing = set(contract) - set(tables())
    for t in sorted(missing):
        breaches.append((t, "table missing entirely"))

    for t in tables():
        if t not in contract:
            breaches.append((t, "table not in contract (new file - regenerate if intended)"))
            continue
        want = contract[t]["columns"]
        got = profile(os.path.join(SAAS, t + ".csv"))["columns"]

        want_names = [c["name"] for c in want]
        got_names = [c["name"] for c in got]

        if got_names != want_names:
            if sorted(got_names) == sorted(want_names):
                # Same columns, different order. COPY maps by position, so this
                # is the dangerous case that would otherwise load cleanly.
                breaches.append((t, f"column ORDER changed: expected {want_names}, got {got_names}"))
            else:
                added = [c for c in got_names if c not in want_names]
                gone = [c for c in want_names if c not in got_names]
                if gone:
                    breaches.append((t, f"columns removed: {gone}"))
                if added:
                    breaches.append((t, f"columns added: {added}"))
            continue

        for w, g in zip(want, got):
            # Widening is a breach: a column contracted as integer arriving as
            # text means the loader will reject it or the models will misread it.
            if w["type"] != g["type"]:
                breaches.append((t, f"{w['name']}: type {w['type']} -> {g['type']}"))
            if g["nullable"] and not w["nullable"]:
                breaches.append((t, f"{w['name']}: nulls appeared in a non-nullable column"))

    width = max((len(t) for t, _ in breaches), default=0)
    if breaches:
        print("SCHEMA CONTRACT BREACHED\n")
        for t, msg in breaches:
            print(f"  {t:<{width}}  {msg}")
        print(f"\n{len(breaches)} breach(es). Refusing to load. If the change is "
              f"intended, re-run with --generate and commit the new contract.")
        sys.exit(1)

    total = sum(profile(os.path.join(SAAS, t + ".csv"))["row_count"] for t in tables())
    print(f"schema contract OK - {len(tables())} tables, {total} rows")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "--check"
    if mode == "--generate":
        generate()
    elif mode == "--check":
        check()
    else:
        sys.exit(f"usage: {sys.argv[0]} [--check|--generate]")
