#!/usr/bin/env python3
"""Select dense music windows for repeatable combat-mix pressure fixtures."""
import concurrent.futures
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = Path(__file__).with_name("dense-music-test-windows.json")
WINDOW = 10


def measure(path):
    result = subprocess.run(
        ["ffmpeg", "-nostdin", "-v", "error", "-threads", "1", "-filter_threads", "1",
         "-i", str(path), "-af",
         "asetnsamples=n=48000:p=0,astats=metadata=1:reset=1,ametadata=mode=print:key=lavfi.astats.Overall.RMS_level:file=-",
         "-f", "null", "-"], capture_output=True, text=True, check=True)
    rows = []
    current_time = 0.0
    for line in result.stdout.splitlines():
        found = re.search(r"pts_time:([0-9.]+)", line)
        if found:
            current_time = float(found.group(1))
        if line.startswith("lavfi.astats.Overall.RMS_level="):
            level = float(line.split("=", 1)[1])
            rows.append((current_time, 10 ** (level / 10) if math.isfinite(level) else 0.0))
    assert len(rows) > WINDOW, (path, result.stdout[:400])
    averages = [sum(power for _, power in rows[i:i + WINDOW]) / WINDOW
                for i in range(len(rows) - WINDOW + 1)]
    best = max(range(len(averages)), key=averages.__getitem__)
    with path.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    return {"cue_id":path.stem, "path":str(path.relative_to(ROOT)), "sha256":digest,
            "start_seconds":rows[best][0], "window_seconds":WINDOW,
            "mean_rms_dbfs":10 * math.log10(averages[best]), "one_second_bins":len(rows)}


def main():
    paths = sorted((ROOT / "assets/music/midi_test").glob("*.ogg"))
    assert len(paths) == 12
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        rows = list(executor.map(measure, paths))
    report = {"status":"PASS", "method":"maximum mean decoded PCM power across ten consecutive one-second stereo bins",
              "scope":"repeatable dense-music fixtures; not an audibility or subjective-listening result", "items":rows}
    OUTPUT.write_text(json.dumps(report, indent=2) + "\n")
    print("DENSE_MUSIC_WINDOWS_OK songs=%d" % len(rows))
    for row in rows:
        print("%s start=%.1f mean_rms_dbfs=%.2f" % (row["cue_id"], row["start_seconds"], row["mean_rms_dbfs"]))


if __name__ == "__main__":
    main()
