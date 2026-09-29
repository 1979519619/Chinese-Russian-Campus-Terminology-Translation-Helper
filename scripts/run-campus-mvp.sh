#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RUNTIME_ROOT="${CAMPUS_MVP_RUNTIME_ROOT:-}"
VENV_PATH="${CAMPUS_MVP_VENV_PATH:-}"
LISTEN_ADDRESS="${CAMPUS_MVP_HOST:-}"
PORT="${CAMPUS_MVP_PORT:-}"
OPEN_BROWSER=0
CONFIG_PATH="$REPOSITORY_ROOT/.campus-mvp.local.json"

while (($#)); do
    case "$1" in
        --runtime-root) RUNTIME_ROOT="$2"; shift 2 ;;
        --venv-path) VENV_PATH="$2"; shift 2 ;;
        --host) LISTEN_ADDRESS="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --open-browser) OPEN_BROWSER=1; shift ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done

read_config() {
    local key="$1"
    [[ -f "$CONFIG_PATH" ]] || return 0
    python3 - "$CONFIG_PATH" "$key" <<'PY'
import json, sys
try:
    value = json.load(open(sys.argv[1], encoding="utf-8")).get(sys.argv[2], "")
    print(value)
except (OSError, ValueError):
    pass
PY
}

[[ -n "$RUNTIME_ROOT" ]] || RUNTIME_ROOT="$(read_config runtimeRoot)"
[[ -n "$RUNTIME_ROOT" ]] || RUNTIME_ROOT="$HOME/CampusMVP/runtime"
[[ -n "$VENV_PATH" ]] || VENV_PATH="$(read_config venvPath)"
[[ -n "$VENV_PATH" ]] || VENV_PATH="$RUNTIME_ROOT/.venv"
[[ -n "$LISTEN_ADDRESS" ]] || LISTEN_ADDRESS="$(read_config listenAddress)"
[[ -n "$LISTEN_ADDRESS" ]] || LISTEN_ADDRESS="127.0.0.1"
[[ -n "$PORT" ]] || PORT="$(read_config port)"
[[ -n "$PORT" ]] || PORT="5000"

RUNTIME_ROOT="$(readlink -m "$RUNTIME_ROOT")"
VENV_PATH="$(readlink -m "$VENV_PATH")"
PYTHON_PATH="$VENV_PATH/bin/python"
DATA_PATH="$RUNTIME_ROOT/data"
CACHE_PATH="$RUNTIME_ROOT/cache"
CONFIG_ROOT="$RUNTIME_ROOT/config"
TEMPORARY_PATH="$RUNTIME_ROOT/tmp"
ARGOS_PACKAGES_PATH="$DATA_PATH/argos-translate/packages"

if [[ ! -x "$PYTHON_PATH" ]]; then
    echo "Project Python was not found: $PYTHON_PATH" >&2
    echo "Run ./scripts/setup-campus-mvp.sh first." >&2
    exit 1
fi
if [[ ! -d "$ARGOS_PACKAGES_PATH" ]]; then
    echo "Argos model directory was not found: $ARGOS_PACKAGES_PATH" >&2
    exit 1
fi
mkdir -p "$CACHE_PATH" "$CONFIG_ROOT" "$TEMPORARY_PATH"

export XDG_DATA_HOME="$DATA_PATH"
export XDG_CACHE_HOME="$CACHE_PATH"
export XDG_CONFIG_HOME="$CONFIG_ROOT"
export ARGOS_PACKAGES_DIR="$ARGOS_PACKAGES_PATH"
export TMPDIR="$TEMPORARY_PATH"
export PYTHONIOENCODING=utf-8

cd -- "$REPOSITORY_ROOT"
if ((OPEN_BROWSER)); then
    "$PYTHON_PATH" - "http://${LISTEN_ADDRESS}:${PORT}/health" "http://${LISTEN_ADDRESS}:${PORT}" <<'PY' &
import json, sys, time, urllib.request, webbrowser
health_url, page_url = sys.argv[1:]
for _ in range(120):
    try:
        with urllib.request.urlopen(health_url, timeout=2) as response:
            if json.load(response).get("status") == "ok":
                webbrowser.open(page_url)
                break
    except Exception:
        time.sleep(0.5)
PY
fi

exec "$PYTHON_PATH" -m libretranslate.main \
    --host "$LISTEN_ADDRESS" \
    --port "$PORT" \
    --load-only zh,en,ru
