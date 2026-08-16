#!/usr/bin/env bash
# Invented Software analytics platform.
#
#   ./start.sh             start (or resume) the stack and rebuild the models
#   ./start.sh --clean     destroy containers and volumes first - proves a cold start
#   ./start.sh --refresh   reload the CSVs and rebuild, leaving containers running
#   ./start.sh --help      this message
#
# Postgres holds the data, dbt builds the models, Metabase serves the dashboards.
# Every run is logged to logs/run-<timestamp>.log.
set -Eeuo pipefail
cd "$(dirname "$0")"

MODE=start
for arg in "$@"; do
    case "$arg" in
        --clean)   MODE=clean ;;
        --refresh) MODE=refresh ;;
        --help|-h) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
    esac
done

# --- logging -----------------------------------------------------------------
mkdir -p logs
LOG="logs/run-$(date +%Y%m%d-%H%M%S).log"
# Everything below goes to the terminal AND the log. Tee rather than redirect so
# a run stays watchable while remaining auditable afterwards.
exec > >(tee -a "$LOG") 2>&1
START_TS=$(date +%s)

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }
fail() { printf '\n\033[1;31m!! %s\033[0m\n' "$1" >&2; exit 1; }

# --- error handling ----------------------------------------------------------
# Without this a failure 200 lines into a build shows only the last command's
# stderr, with no indication of which step died.
on_error() {
    local exit_code=$? line=$1 cmd=$2
    printf '\n\033[1;31m!! FAILED\033[0m at line %s (exit %s)\n' "$line" "$exit_code" >&2
    printf '   command: %s\n' "$cmd" >&2
    printf '   step:    %s\n' "${CURRENT_STEP:-unknown}" >&2
    printf '   log:     %s\n' "$LOG" >&2
    case "${CURRENT_STEP:-}" in
        "container runtime") printf '   hint:    is Colima running? try: colima start --vm-type vz\n' >&2 ;;
        "schema contract")   printf '   hint:    a CSV changed shape. If intended: python3 scripts/validate_csv_schema.py --generate\n' >&2 ;;
        "data quality")      printf '   hint:    the raw load is bad; inspect with db/validate.sql\n' >&2 ;;
        "dbt build")         printf '   hint:    see dbt/target/run_results.json for the failing node\n' >&2 ;;
        "metabase")          printf '   hint:    is Metabase healthy? curl -s localhost:3000/api/health\n' >&2 ;;
    esac
    exit "$exit_code"
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR
step() { CURRENT_STEP="$1"; say "$2"; }

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
    step credentials "Generating .env with fresh random passwords"
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
    # A generated .env is only valid against a fresh volume. Postgres bakes the
    # password in at initdb time, so a pre-existing volume still holds the old
    # one and every later step fails with an opaque auth error.
    if docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q '^invented_software_pgdata$'; then
        fail "Generated a new .env but volume invented_software_pgdata already exists with the previous password.
   Either restore the old .env, or discard the data:  ./start.sh --clean"
    fi
fi

# Export for dbt's env_var() and the provisioning script. Compose reads .env
# from the project directory on its own.
set -a
# shellcheck disable=SC1091
source .env
set +a

# --- schema contract ---------------------------------------------------------
# Runs before anything touches the database. COPY maps columns by POSITION, so a
# reordering of two same-typed columns would load without error and silently
# corrupt every downstream number. This is the gate that catches that.
step "schema contract" "Validating CSV schema contract"
python3 scripts/validate_csv_schema.py --check

# --- python environment ------------------------------------------------------
if [[ ! -x .venv/bin/dbt ]]; then
    step python "Creating Python environment and installing dbt"
    python3 -m venv .venv
    .venv/bin/pip install --quiet --upgrade pip
    .venv/bin/pip install --quiet dbt-postgres
fi

# --- container runtime -------------------------------------------------------
step "container runtime" "Checking container runtime"
command -v docker >/dev/null || fail "docker not found"
if ! docker info >/dev/null 2>&1; then
    # Colima's VM is per-user and does not survive a reboot. On Apple Silicon
    # the vz driver must be named explicitly - the default falls back to QEMU,
    # which is not installed here, and then hangs silently rather than erroring.
    say "Starting Colima"
    colima start --vm-type vz --cpu 4 --memory 8 --disk 60
fi

if [[ $MODE == clean ]]; then
    step clean "Clean state: destroying containers and volumes"
    compose down -v --remove-orphans || true
    rm -rf dbt/target dbt/logs
fi

# --- services ----------------------------------------------------------------
step services "Starting Postgres and Metabase"
compose up -d postgres metabase

step services "Waiting for Postgres"
# Bounded: an unbounded `until` loop hangs forever on a crash-looping Postgres,
# and because the failure lives in a loop CONDITION the ERR trap never fires -
# so the script would sit silent rather than printing the log path and hints.
for attempt in $(seq 1 60); do
    if compose exec -T postgres pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
        break
    fi
    if [[ $attempt -eq 60 ]]; then
        compose logs --tail=30 postgres || true
        fail "Postgres did not become ready within 120s (logs above, full log: $LOG)"
    fi
    sleep 2
done

# --- data --------------------------------------------------------------------
if [[ $MODE == refresh ]]; then
    # Reload inside a transaction so a failure leaves the previous data intact.
    step refresh "Reloading raw data from CSVs"
    compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -v ON_ERROR_STOP=1 -q -f /db/refresh.sql
fi

step "data quality" "Validating loaded data"
compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    -v ON_ERROR_STOP=1 -f /db/validate.sql

# --- models ------------------------------------------------------------------
step "dbt build" "Building dbt models"
(cd dbt && ../.venv/bin/dbt build --profiles-dir profiles)

# --- dashboards --------------------------------------------------------------
step metabase "Provisioning Metabase"
.venv/bin/python scripts/provision_metabase.py

ELAPSED=$(( $(date +%s) - START_TS ))
say "Ready in ${ELAPSED}s - dashboards at http://localhost:3000"
printf '    log: %s\n' "$LOG"
