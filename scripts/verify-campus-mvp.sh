#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RUNTIME_ROOT="${CAMPUS_MVP_RUNTIME_ROOT:-}"
VENV_PATH="${CAMPUS_MVP_VENV_PATH:-}"
PORT="${CAMPUS_MVP_VERIFY_PORT:-5002}"
OUTPUT_DIRECTORY="${CAMPUS_MVP_VERIFY_OUTPUT:-$REPOSITORY_ROOT/artifacts/verification}"
CONFIG_PATH="$REPOSITORY_ROOT/.campus-mvp.local.json"

while (($#)); do
    case "$1" in
        --runtime-root) RUNTIME_ROOT="$2"; shift 2 ;;
        --venv-path) VENV_PATH="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --output-directory) OUTPUT_DIRECTORY="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done

read_config() {
    local key="$1"
    [[ -f "$CONFIG_PATH" ]] || return 0
    python3 - "$CONFIG_PATH" "$key" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1], encoding="utf-8")).get(sys.argv[2], ""))
except (OSError, ValueError):
    pass
PY
}

[[ -n "$RUNTIME_ROOT" ]] || RUNTIME_ROOT="$(read_config runtimeRoot)"
[[ -n "$RUNTIME_ROOT" ]] || RUNTIME_ROOT="$HOME/CampusMVP/runtime"
[[ -n "$VENV_PATH" ]] || VENV_PATH="$(read_config venvPath)"
[[ -n "$VENV_PATH" ]] || VENV_PATH="$RUNTIME_ROOT/.venv"
RUNTIME_ROOT="$(readlink -m "$RUNTIME_ROOT")"
VENV_PATH="$(readlink -m "$VENV_PATH")"
OUTPUT_DIRECTORY="$(readlink -m "$OUTPUT_DIRECTORY")"

PYTHON_PATH="$VENV_PATH/bin/python"
DATA_PATH="$RUNTIME_ROOT/data"
CACHE_PATH="$RUNTIME_ROOT/cache"
CONFIG_ROOT="$RUNTIME_ROOT/config"
TEMPORARY_PATH="$RUNTIME_ROOT/tmp"
ARGOS_PACKAGES_PATH="$DATA_PATH/argos-translate/packages"
if [[ ! -x "$PYTHON_PATH" ]]; then
    echo "Project Python was not found: $PYTHON_PATH" >&2
    exit 1
fi
if [[ ! -d "$ARGOS_PACKAGES_PATH" ]]; then
    echo "Argos model directory was not found: $ARGOS_PACKAGES_PATH" >&2
    exit 1
fi
mkdir -p "$CACHE_PATH" "$CONFIG_ROOT" "$TEMPORARY_PATH" "$OUTPUT_DIRECTORY"

export XDG_DATA_HOME="$DATA_PATH"
export XDG_CACHE_HOME="$CACHE_PATH"
export XDG_CONFIG_HOME="$CONFIG_ROOT"
export ARGOS_PACKAGES_DIR="$ARGOS_PACKAGES_PATH"
export TMPDIR="$TEMPORARY_PATH"
export PYTHONIOENCODING=utf-8
export PYTHONPATH="$REPOSITORY_ROOT${PYTHONPATH:+:$PYTHONPATH}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORT_PATH="$OUTPUT_DIRECTORY/campus-mvp-$TIMESTAMP.json"
STDOUT_PATH="$OUTPUT_DIRECTORY/server-$TIMESTAMP.stdout.log"
STDERR_PATH="$OUTPUT_DIRECTORY/server-$TIMESTAMP.stderr.log"
SUMMARY_PATH="$OUTPUT_DIRECTORY/verification-$TIMESTAMP.json"
BASE_URL="http://127.0.0.1:$PORT"
PRIVACY_SENTINEL="CAMPUS_PRIVACY_SENTINEL_$($PYTHON_PATH -c 'import uuid; print(uuid.uuid4().hex)')"
SERVER_PID=""

cleanup() {
    if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

echo "Checking locked Python dependencies"
"$PYTHON_PATH" -m pip check
echo "Checking the exact Argos model set"
"$PYTHON_PATH" "$SCRIPT_DIR/install-campus-models.py" --check-only
echo "Running the 30-test glossary suite"
"$PYTHON_PATH" "$REPOSITORY_ROOT/libretranslate/tests/test_campus_glossary.py"

echo "Starting an isolated verification server at $BASE_URL"
cd -- "$REPOSITORY_ROOT"
"$PYTHON_PATH" -m libretranslate.main \
    --host 127.0.0.1 \
    --port "$PORT" \
    --load-only zh,en,ru \
    >"$STDOUT_PATH" 2>"$STDERR_PATH" &
SERVER_PID=$!

"$PYTHON_PATH" - "$BASE_URL/health" "$SERVER_PID" <<'PY'
import json, os, sys, time, urllib.request
health_url, process_id = sys.argv[1], int(sys.argv[2])
for _ in range(120):
    try:
        os.kill(process_id, 0)
    except OSError as exc:
        raise SystemExit("Verification server exited before becoming healthy") from exc
    try:
        with urllib.request.urlopen(health_url, timeout=2) as response:
            if json.load(response).get("status") == "ok":
                raise SystemExit(0)
    except Exception:
        time.sleep(0.5)
raise SystemExit("Verification server did not become healthy within 60 seconds")
PY

echo "Running the 40-term model-backed evaluation"
"$PYTHON_PATH" "$SCRIPT_DIR/evaluate-campus-glossary.py" \
    --base-url "$BASE_URL" \
    --output "$REPORT_PATH" >/dev/null

"$PYTHON_PATH" - "$BASE_URL/translate" "$PRIVACY_SENTINEL" <<'PY'
import json, sys, urllib.request
url, sentinel = sys.argv[1:]
payload = json.dumps({
    "q": sentinel,
    "source": "en",
    "target": "ru",
    "format": "text",
    "use_glossary": False,
}).encode("utf-8")
request = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"}, method="POST")
with urllib.request.urlopen(request, timeout=60) as response:
    response.read()
PY

"$PYTHON_PATH" - "$REPORT_PATH" <<'PY'
import json, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["termCount"] == 40
assert report["passedCount"] == 40
assert report["adoptionRatePercent"] == 100
assert report["ordinaryTextRegression"]["identical"] is True
assert len(report["comparisons"]) == 3
PY

cleanup
SERVER_PID=""
if grep -Fq -- "$PRIVACY_SENTINEL" "$STDOUT_PATH" "$STDERR_PATH"; then
    echo "Privacy check failed: request text appeared in server logs." >&2
    exit 1
fi

"$PYTHON_PATH" - "$SUMMARY_PATH" "$REPOSITORY_ROOT" "$RUNTIME_ROOT" "$VENV_PATH" "$REPORT_PATH" <<'PY'
import datetime, json, pathlib, sys
path, repository, runtime, venv, report = sys.argv[1:]
summary = {
    "status": "PASS",
    "verifiedAt": datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat(),
    "repository": repository,
    "runtimeRoot": runtime,
    "venvPath": venv,
    "dependencyCheck": "PASS",
    "modelSet": "zh-en,en-zh,ru-en,en-ru@1.9",
    "unitTests": "30/30",
    "termAdoption": "40/40",
    "ordinaryTextRegression": "PASS",
    "privacyLogSentinel": "PASS",
    "evaluationReport": report,
}
pathlib.Path(path).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
PY

trap - EXIT INT TERM
echo "VERIFY_PASS"
echo "Summary: $SUMMARY_PATH"
echo "Evaluation: $REPORT_PATH"
