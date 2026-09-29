#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RUNTIME_ROOT="${CAMPUS_MVP_RUNTIME_ROOT:-$HOME/CampusMVP/runtime}"
VENV_PATH="${CAMPUS_MVP_VENV_PATH:-}"
PYTHON_EXECUTABLE="${CAMPUS_MVP_PYTHON:-}"
PORT="${CAMPUS_MVP_PORT:-5000}"
VALIDATE_ONLY=0
MINIMUM_RUNTIME_FREE_KIB=$((2 * 1024 * 1024))

usage() {
    cat <<'EOF'
Usage: setup-campus-mvp.sh [options]
  --runtime-root PATH  Model, cache and temporary-data root
  --venv-path PATH     Python virtual environment path
  --python PATH        Python 3.10, 3.11 or 3.12 executable
  --port NUMBER        Default service port (default: 5000)
  --validate-only      Run storage and Python preflight without writing
EOF
}

while (($#)); do
    case "$1" in
        --runtime-root) RUNTIME_ROOT="$2"; shift 2 ;;
        --venv-path) VENV_PATH="$2"; shift 2 ;;
        --python) PYTHON_EXECUTABLE="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --validate-only) VALIDATE_ONLY=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

resolve_python() {
    local candidates=()
    local candidate
    if [[ -n "$PYTHON_EXECUTABLE" ]]; then
        candidates+=("$PYTHON_EXECUTABLE")
    else
        for candidate in python3.12 python3.11 python3.10 python3; do
            if command -v "$candidate" >/dev/null 2>&1; then
                candidates+=("$(command -v "$candidate")")
            fi
        done
    fi

    for candidate in "${candidates[@]}"; do
        if "$candidate" -c 'import platform,sys; raise SystemExit(0 if (3,10) <= sys.version_info[:2] <= (3,12) and platform.machine().lower() in {"x86_64","amd64"} else 1)' 2>/dev/null; then
            readlink -f "$candidate"
            return 0
        fi
    done
    echo "A 64-bit Python version from 3.10 through 3.12 is required." >&2
    return 1
}

nearest_existing_path() {
    local candidate="$1"
    while [[ ! -e "$candidate" ]]; do
        candidate="$(dirname -- "$candidate")"
    done
    printf '%s\n' "$candidate"
}

BASE_PYTHON="$(resolve_python)"
RUNTIME_ROOT="$(readlink -m "$RUNTIME_ROOT")"
if [[ -z "$VENV_PATH" ]]; then
    VENV_PATH="$RUNTIME_ROOT/.venv"
fi
VENV_PATH="$(readlink -m "$VENV_PATH")"

RUNTIME_EXISTING="$(nearest_existing_path "$RUNTIME_ROOT")"
VENV_EXISTING="$(nearest_existing_path "$VENV_PATH")"
RUNTIME_FREE_KIB="$(df -Pk "$RUNTIME_EXISTING" | awk 'NR==2 {print $4}')"
VENV_FREE_KIB="$(df -Pk "$VENV_EXISTING" | awk 'NR==2 {print $4}')"
if ((RUNTIME_FREE_KIB < MINIMUM_RUNTIME_FREE_KIB)); then
    echo "Runtime filesystem has less than 2 GiB free: $RUNTIME_ROOT" >&2
    exit 1
fi
if ((VENV_FREE_KIB < 1024 * 1024)); then
    echo "Virtual-environment filesystem has less than 1 GiB free: $VENV_PATH" >&2
    exit 1
fi

"$BASE_PYTHON" - "$REPOSITORY_ROOT" "$BASE_PYTHON" "$RUNTIME_ROOT" "$VENV_PATH" "$PORT" "$RUNTIME_FREE_KIB" "$VALIDATE_ONLY" <<'PY'
import json, sys
repo, python, runtime, venv, port, free_kib, validate = sys.argv[1:]
print(json.dumps({
    "repository": repo,
    "python": python,
    "runtimeRoot": runtime,
    "runtimeFreeGiB": round(int(free_kib) / 1024 / 1024, 2),
    "venvPath": venv,
    "port": int(port),
    "estimatedFinalGiB": 1.0,
    "validateOnly": validate == "1",
}, indent=2))
PY
if ((VALIDATE_ONLY)); then
    echo "SETUP_PREFLIGHT_PASS"
    exit 0
fi

DATA_PATH="$RUNTIME_ROOT/data"
CACHE_PATH="$RUNTIME_ROOT/cache"
CONFIG_ROOT="$RUNTIME_ROOT/config"
TEMPORARY_PATH="$RUNTIME_ROOT/tmp"
PIP_CACHE_PATH="$CACHE_PATH/pip"
ARGOS_PACKAGES_PATH="$DATA_PATH/argos-translate/packages"
mkdir -p "$DATA_PATH" "$CACHE_PATH" "$CONFIG_ROOT" "$TEMPORARY_PATH" "$PIP_CACHE_PATH"

export XDG_DATA_HOME="$DATA_PATH"
export XDG_CACHE_HOME="$CACHE_PATH"
export XDG_CONFIG_HOME="$CONFIG_ROOT"
export ARGOS_PACKAGES_DIR="$ARGOS_PACKAGES_PATH"
export PIP_CACHE_DIR="$PIP_CACHE_PATH"
export TMPDIR="$TEMPORARY_PATH"
export PYTHONIOENCODING=utf-8

VENV_PYTHON="$VENV_PATH/bin/python"
VENV_NEEDS_REBUILD=0
if [[ ! -x "$VENV_PYTHON" ]]; then
    VENV_NEEDS_REBUILD=1
elif ! "$VENV_PYTHON" -m pip --version >/dev/null 2>&1; then
    VENV_NEEDS_REBUILD=1
fi
if ((VENV_NEEDS_REBUILD)); then
    VENV_ARGUMENTS=()
    if [[ -d "$VENV_PATH" ]]; then
        echo "Repairing incomplete Python virtual environment at $VENV_PATH"
        VENV_ARGUMENTS+=(--clear)
    else
        echo "Creating Python virtual environment at $VENV_PATH"
    fi
    if ! "$BASE_PYTHON" -m venv "${VENV_ARGUMENTS[@]}" "$VENV_PATH"; then
        PYTHON_MINOR="$($BASE_PYTHON -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
        echo "The Python venv module is unavailable." >&2
        echo "Install it with: sudo apt update && sudo apt install -y python${PYTHON_MINOR}-venv" >&2
        exit 1
    fi
fi

echo "Installing locked Python dependencies"
"$VENV_PYTHON" -m pip install --upgrade 'pip==26.2.1' 'setuptools==84.0.0' 'wheel==0.45.1'
"$VENV_PYTHON" -m pip install --no-deps -r "$REPOSITORY_ROOT/requirements-mvp-lock.txt"
"$VENV_PYTHON" -m pip check

echo "Installing the pinned campus translation model set"
"$VENV_PYTHON" "$SCRIPT_DIR/install-campus-models.py"

echo "Running the dependency-free glossary tests"
"$VENV_PYTHON" "$REPOSITORY_ROOT/libretranslate/tests/test_campus_glossary.py"

SOURCE_COMMIT="unknown"
if command -v git >/dev/null 2>&1; then
    SOURCE_COMMIT="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD 2>/dev/null || printf unknown)"
fi
"$VENV_PYTHON" - "$REPOSITORY_ROOT/.campus-mvp.local.json" "$RUNTIME_ROOT" "$VENV_PATH" "$PORT" "$SOURCE_COMMIT" <<'PY'
import json, pathlib, sys
path, runtime, venv, port, commit = sys.argv[1:]
payload = {
    "runtimeRoot": runtime,
    "venvPath": venv,
    "listenAddress": "127.0.0.1",
    "port": int(port),
    "pythonVersion": "3.10-3.12",
    "modelVersion": "1.9",
    "sourceCommit": commit,
}
pathlib.Path(path).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

echo "SETUP_PASS"
echo "Start the service with: ./scripts/start-campus-mvp-linux.sh"
