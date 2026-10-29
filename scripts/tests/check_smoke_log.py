#!/usr/bin/env python3
"""Validate legacy/new smoke reports without hiding intentional save-error tests."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ERROR = re.compile(
    r"SCRIPT ERROR|Parser Error|Parse Error|Invalid call|Failed to load script|"
    r"Failed to instantiate|Compilation failed|^ERROR:"
)
SUCCESS = re.compile(
    r"(?:[A-Za-z0-9_]+_OK|[A-Za-z0-9_]+: (?:OK|PASS)|"
    r"[A-Za-z0-9_]+ PASS(?: (?:checks=[0-9]+ )?failures=0)?)$"
)
# Match the test, exact preceding marker and exact error together. Never
# blanket-ignore ERROR, /proc errors, or arbitrary lines after a fault marker.
FAULTS = {
    "chronicle_combat_smoke": {
        "EXPECTED_FAULT_INJECTION: victory write rejected":
            "ERROR: Could not create directory: '/proc/chronicle-combat-result-read-only'.",
        "EXPECTED_FAULT_INJECTION: selection write rejected":
            "ERROR: Could not create directory: '/proc/chronicle-combat-test-read-only'.",
    },
    "chronicle_ui_smoke": {
        "EXPECTED_FAULT_INJECTION: write to /proc must fail and rollback":
            "ERROR: Could not create directory: '/proc/chronicle-test-read-only'.",
    },
    "chronicle_story_progress_smoke": {
        "EXPECTED_FAULT_INJECTION: first reward claim write rejected":
            "ERROR: Could not create directory: '/proc/chronicle-story-claim-read-only'.",
        "EXPECTED_FAULT_INJECTION: story line write rejected":
            "ERROR: Could not create directory: '/proc/chronicle-story-line-read-only'.",
        "EXPECTED_FAULT_INJECTION: story completion write rejected":
            "ERROR: Could not create directory: '/proc/chronicle-story-line-read-only'.",
    },
    "chronicle_character_campaign_smoke": {
        "EXPECTED_FAULT_INJECTION: post-battle story save rejected":
            "ERROR: Could not create directory: '/proc/character-campaign-story-write-rejected'.",
    },
    "chronicle_story_ui_smoke": {
        "EXPECTED_FAULT_INJECTION: story UI line write rejected":
            "ERROR: Could not create directory: '/proc/chronicle-story-ui-read-only'.",
        "EXPECTED_FAULT_INJECTION: story UI completion write rejected":
            "ERROR: Could not create directory: '/proc/chronicle-story-ui-read-only'.",
    },
}


def validate(name: str, text: str) -> list[str]:
    failures = []
    previous = ""
    success = False
    for raw in text.splitlines():
        line = raw.strip()
        if ERROR.search(line):
            if FAULTS.get(name, {}).get(previous) != line:
                failures.append(line)
        if SUCCESS.fullmatch(line):
            success = True
        elif re.fullmatch(r"[A-Za-z0-9_]+(?: |: )(?:FAIL|FAILED)\b.*", line):
            failures.append(line)
        elif re.search(r"\bfailures=[1-9][0-9]*\b", line):
            failures.append(line)
        previous = line
    if not success:
        failures.append("missing successful smoke result")
    return failures


def main() -> int:
    name = Path(sys.argv[1]).stem
    failures = validate(name, Path(sys.argv[2]).read_text(errors="replace"))
    if failures:
        print(name.upper() + "_LOG_FAILED")
        print("\n".join(failures))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
