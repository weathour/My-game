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
    r"[A-Za-z0-9_]+ PASS)"
    r"(?: [A-Za-z][A-Za-z0-9_]*=[A-Za-z0-9_./:+-]+)*$"
)
SUCCESS_CANDIDATE = re.compile(
    r"(?:[A-Za-z0-9_]+_OK|[A-Za-z0-9_]+: (?:OK|PASS)|[A-Za-z0-9_]+ PASS)(?=$| )"
)
KEY_VALUE = re.compile(r"([A-Za-z][A-Za-z0-9_]*)=([A-Za-z0-9_./:+-]+)\Z")
FAIL_WORD = re.compile(r"(?i)(?:^|[^A-Za-z0-9])(?:FAIL(?:ED)?|ERROR)(?:$|[^A-Za-z0-9])")
# These integration tests must finish their own complete assertion sequence;
# an incidental success line from a loaded subsystem cannot substitute for it.
REQUIRED_SUCCESS = {
    "chronicle_enemy_pack_smoke": "ENEMY_PACK_SMOKE PASS",
    "chronicle_music_pack_smoke": "CHRONICLE_MUSIC_PACK_SMOKE PASS",
    "chronicle_music_playback_smoke": "CHRONICLE_MUSIC_PLAYBACK_SMOKE PASS",
}
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
        expected_faults = FAULTS.get(name, {})
        authorized_fault = expected_faults.get(previous) == line
        if ERROR.search(line) and not authorized_fault:
            failures.append(line)
        if SUCCESS.fullmatch(line):
            fields = {}
            duplicate_field = False
            for token in line.split()[1:]:
                match = KEY_VALUE.fullmatch(token)
                # Prefix tokens (the success marker, including NAME:) are not
                # diagnostic fields. Every trailing token must be key=value.
                if match is None:
                    continue
                key, value = match.groups()
                if key in fields:
                    duplicate_field = True
                fields[key] = value
            bad_annotation = FAIL_WORD.search(line) is not None
            if not duplicate_field and not bad_annotation and fields.get("failures", "0") == "0" and fields.get("checks", "0").isdigit():
                required = REQUIRED_SUCCESS.get(name)
                if required is None or line == required or line.startswith(required + " "):
                    success = True
            else:
                failures.append(line)
        elif SUCCESS_CANDIDATE.match(line):
            # A line that starts like a success result but carries prose,
            # malformed diagnostics, duplicate keys, or a nonzero failure
            # count must not count as a successful smoke result.
            failures.append(line)
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
