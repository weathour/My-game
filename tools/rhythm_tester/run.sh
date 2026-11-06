#!/usr/bin/env bash
set -euo pipefail
tool_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$tool_dir/..${PYTHONPATH:+:$PYTHONPATH}"
native_lib="$tool_dir/.native/usr/lib/$(uname -m)-linux-gnu"
if [[ -d "$native_lib" ]]; then
    export LD_LIBRARY_PATH="$native_lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
if [[ -x "$tool_dir/.venv/bin/python" ]] && "$tool_dir/.venv/bin/python" -c 'import PySide6.QtMultimedia, mido, numpy' >/dev/null 2>&1; then
    exec "$tool_dir/.venv/bin/python" -m rhythm_tester "$@"
elif command -v uv >/dev/null 2>&1; then
    exec uv run --project "$tool_dir" python -m rhythm_tester "$@"
else
    echo "Please install uv, then run this launcher again." >&2
    echo "https://docs.astral.sh/uv/getting-started/installation/" >&2
    exit 1
fi
