#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC_PATHS = [
    ROOT / "README.md",
    ROOT / "CHANGELOG.md",
    ROOT / "CONTRIBUTING.md",
    ROOT / "SECURITY.md",
    ROOT / "ROADMAP.md",
    ROOT / "LICENSE.md",
    ROOT / "THIRD_PARTY_NOTICES.md",
    ROOT / "AGENTS.md",
]
DOC_PATHS.extend(sorted((ROOT / "docs").rglob("*.md")))
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
WINDOWS_PATH_RE = re.compile(r"^[A-Za-z]:\\")
STALE_PATH_MARKERS = ["C:\\Users\\Aron", "Desktop\\git", "Documents\\survivor-like"]


def main() -> int:
    failures: list[str] = []
    for path in DOC_PATHS:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        rel_path = path.relative_to(ROOT)
        for line_no, line in enumerate(text.splitlines(), 1):
            for marker in STALE_PATH_MARKERS:
                if marker in line:
                    failures.append(f"{rel_path}:{line_no}: stale path marker: {marker}")
        for match in LINK_RE.finditer(text):
            target = match.group(1).strip()
            line_no = text[: match.start()].count("\n") + 1
            if WINDOWS_PATH_RE.match(target):
                failures.append(f"{rel_path}:{line_no}: Windows absolute path link: {target}")
                continue
            if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target):
                continue
            clean_target = urllib.parse.unquote(target.split("#", 1)[0])
            if not clean_target:
                continue
            resolved = (path.parent / clean_target).resolve()
            try:
                resolved.relative_to(ROOT)
            except ValueError:
                failures.append(f"{rel_path}:{line_no}: link escapes repository: {target}")
                continue
            if not resolved.exists():
                failures.append(f"{rel_path}:{line_no}: missing link target: {target}")
    if failures:
        print("DOC_LINK_CHECK_FAILED")
        print("\n".join(failures))
        return 1
    print("DOC_LINK_CHECK_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
