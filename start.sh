#!/usr/bin/env bash
# Bring the Invented Software analytics platform up from cold.
#
#   ./start.sh           start (or resume) the stack and rebuild the models
#   ./start.sh --clean   destroy volumes first, so the run proves a cold start
#
# Postgres holds the data, dbt builds the models, Metabase serves the dashboard.
set -euo pipefail
cd "$(dirname "$0")"

CLEAN=0
for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }
fail() { printf '\n\033[1;31m!! %s\033[0m\n' "$1" >&2; exit 1; }

# Compose ships either as a `docker compose` CLI plugin or as a standalone
# `docker-compose` binary. Homebrew installs the plugin under the Homebrew
# prefix, which the Docker CLI only searches for the user who installed it -
# so on a second account the plugin is invisible and the standalone binary is
# the working path. Detect rather than assume.
compose() {
    if docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose "$@"
    else
        fail "neither 'docker compose' nor 'docker-compose' is available"
    fi
}

# --- credentials -------------------------------------------------------------
# .env is gitignored and never committed. It is generated here with random
# passwords on first run, so the repository carries no credential literals and
# two checkouts never share a password. See .env.example for the variables.
if [[ ! -f .env ]]; then
    say "Generating .env with fresh random passwords"
    # openssl rather than `tr </dev/urandom | head`: head closes the pipe early,
    # tr takes SIGPIPE, and under `set -o pipefail` that aborts the script.
    # Metabase rejects admin passwords without upper, lower, digit and symbol.
    pg_pw="$(openssl rand -hex 16)"
    mb_pw="Mb$(openssl rand -hex 12)1!"
    cat > .env <<EOF
POSTGRES_USER=analytics
POSTGRES_PASSWORD=${pg_pw}
POSTGRES_DB=invented_software

METABASE_EMAIL=analyst@invented.software
METABASE_PASSWORD=${mb_pw}
EOF
    chmod 600 .env
    printf '    credentials written to .env (chmod 600, gitignored)\n'
fi

# Export for dbt's env_var() and the provisioning script. Compose reads .env
# from the project directory on its own.
set -a
# shellcheck disable=SC1091
source .env
set +a

# --- python environment ------------------------------------------------------
if [[ ! -x .venv/bin/dbt ]]; then
    say "Creating Python environment and installing dbt"
    python3 -m venv .venv
    .venv/bin/pip install --quiet --upgrade pip
    .venv/bin/pip install --quiet dbt-postgres
fi

# --- container runtime -------------------------------------------------------
command -v docker >/dev/null || fail "docker not found"
if ! docker info >/dev/null 2>&1; then
    # Colima's VM is per-user and does not survive a reboot. On Apple Silicon
    # the vz driver must be named explicitly - the default falls back to QEMU,
    # which is not installed here, and then hangs silently rather than erroring.
    say "Starting Colima"
    colima start --vm-type vz --cpu 4 --memory 8 --disk 60
fi

if [[ $CLEAN -eq 1 ]]; then
    say "Clean state: destroying containers and volumes"
    compose down -v --remove-orphans || true
    rm -rf dbt/target dbt/logs
fi

# --- services ----------------------------------------------------------------
say "Starting Postgres and Metabase"
compose up -d postgres metabase

say "Waiting for Postgres"
until compose exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
    sleep 2
done

# --- data quality gate -------------------------------------------------------
# Runs against the raw schema before any modelling, so a bad load fails here
# rather than surfacing as a wrong number on the dashboard.
say "Validating loaded data"
compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    -v ON_ERROR_STOP=1 -f /db/validate.sql

# --- models ------------------------------------------------------------------
say "Building dbt models"
(cd dbt && ../.venv/bin/dbt build --profiles-dir profiles)

# --- dashboard ---------------------------------------------------------------
say "Provisioning Metabase"
.venv/bin/python scripts/provision_metabase.py

say "Ready - dashboard at http://localhost:3000"
