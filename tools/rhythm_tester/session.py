"""Tap measurements and local trial exports, independent of the Qt event loop.

Signed error is corrected tap time minus the nearest reference time. A positive
presentation offset delays the displayed timeline and reference judgement
relative to processed audio. Input correction then moves only the tap earlier.
Neither changes the music or reference times. Window occupancy is a usability measurement, not beat
inference accuracy. Blind trials deliberately have no reference assignment.
"""
from __future__ import annotations

import csv
from datetime import datetime, timezone
import io
import json
import math
from pathlib import Path
import tempfile
from typing import Any
from uuid import uuid4

import numpy as np


class TapJudge:
    def __init__(self, times, window_ms: float = 90):
        values = np.asarray(times, dtype=float).reshape(-1)
        if not np.isfinite(values).all() or np.any(values < 0):
            raise ValueError("Reference times must be finite and nonnegative")
        if not math.isfinite(window_ms) or window_ms <= 0:
            raise ValueError("Window must be finite and positive")
        self.times = np.unique(values)
        self.window_ms = float(window_ms)
        # Limit both sides by the shorter adjacent interval, leaving a gap
        # between windows even at a tempo boundary or in a dense onset plan.
        half = np.full(len(self.times), self.window_ms / 1000)
        if len(self.times) > 1:
            gaps = np.diff(self.times) * .45
            half[:-1] = np.minimum(half[:-1], gaps)
            half[1:] = np.minimum(half[1:], gaps)
        self.starts = np.maximum(0, self.times - half)
        self.ends = self.times + half
        self.events: list[dict[str, Any]] = []
        self._consumed: set[int] = set()

    def reset(self):
        self.events.clear()
        self._consumed.clear()

    def tap(self, raw_sec: float, key: str, compensation_ms: float = 0,
            blind: bool = False, source: str = "keyboard",
            presentation_offset_ms: float = 0) -> dict[str, Any]:
        if not all(math.isfinite(value) for value in (raw_sec, compensation_ms, presentation_offset_ms)):
            raise ValueError("Tap time and compensation must be finite")
        raw = float(raw_sec)
        presented = raw - float(presentation_offset_ms) / 1000
        corrected = presented - float(compensation_ms) / 1000
        event = {
            "judgement": "recorded" if blind else "outside",
            "raw_audio_sec": raw,
            "presentation_audio_sec": presented,
            "corrected_audio_sec": corrected,
            "compensation_ms": float(compensation_ms),
            "presentation_offset_ms": float(presentation_offset_ms),
            "target_index": None, "target_sec": None, "error_ms": None,
            "key": str(key), "source": str(source), "blind": bool(blind),
        }
        if not blind and len(self.times):
            index = int(np.searchsorted(self.times, corrected))
            if index == len(self.times):
                index -= 1
            elif index > 0 and corrected - self.times[index-1] <= self.times[index] - corrected:
                index -= 1
            target = float(self.times[index])
            error = (corrected - target) * 1000
            # Equality at a boundary counts. The epsilon only absorbs floating
            # arithmetic noise, not a visible extension of the input window.
            inside = self.starts[index] - 1e-12 <= corrected <= self.ends[index] + 1e-12
            if inside:
                judgement = "duplicate" if index in self._consumed else "hit"
                self._consumed.add(index)
            else:
                judgement = "early" if error < 0 else "late"
            event.update(judgement=judgement, target_index=index,
                         target_sec=target, error_ms=float(error))
        self.events.append(event)
        return dict(event)

    def stats(self) -> dict[str, Any]:
        judged = [e for e in self.events if not e["blind"]]
        errors = [e["error_ms"] for e in judged
                  if e["error_ms"] is not None and e["judgement"] != "duplicate"]
        hit_count = sum(e["judgement"] == "hit" for e in judged)
        return {
            "tap_count": len(self.events), "hit_count": hit_count,
            "match_rate": 100 * hit_count / len(judged) if judged else None,
            "mean_error": float(np.mean(errors)) if errors else None,
            "median_abs_error": float(np.median(np.abs(errors))) if errors else None,
            "duplicate_count": sum(e["judgement"] == "duplicate" for e in judged),
        }


def _json_default(value):
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, (np.ndarray, np.generic)):
        return value.tolist()
    raise TypeError(f"Not JSON serializable: {type(value).__name__}")


def _copy_json(value):
    return json.loads(json.dumps(value, default=_json_default, ensure_ascii=False, allow_nan=False))


def _atomic_write(path: Path, content: str):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="",
                                         dir=path.parent, prefix=path.name+".",
                                         suffix=".tmp", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(content)
        temporary.replace(path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


class SessionLog:
    """One application session, retaining every segment through repeated exports.

    Metadata belongs to the moment the trial starts. The UI starts a new trial
    after seeking, changing references/settings, loading a track, or retrying.
    Re-export updates the same two session files without discarding prior trials.
    """
    def __init__(self, results_dir: Path | str):
        self.results_dir = Path(results_dir).expanduser().resolve()
        now = datetime.now(timezone.utc)
        self.created_utc = now.isoformat()
        self.session_id = now.strftime("%Y%m%dT%H%M%S") + "_" + uuid4().hex[:10]
        self.trials: list[dict[str, Any]] = []

    @property
    def trial_count(self) -> int:
        return len(self.trials)

    @property
    def total_taps(self) -> int:
        return sum(len(trial["events"]) for trial in self.trials)

    def start_trial(self, metadata: dict) -> str:
        trial_id = f"{self.session_id}:{len(self.trials)+1}"
        self.trials.append({"trial_id": trial_id, "metadata": _copy_json(metadata), "events": []})
        return trial_id

    def append(self, event: dict):
        if not self.trials:
            raise RuntimeError("Start a trial before recording taps")
        self.trials[-1]["events"].append(_copy_json(event))

    def export(self) -> tuple[Path, Path]:
        if not self.trials:
            raise ValueError("There are no trials to export")
        payload = {
            "schema_version": 2, "session_id": self.session_id,
            "created_utc": self.created_utc,
            "exported_utc": datetime.now(timezone.utc).isoformat(),
            "time_unit": "seconds (audio PCM timeline); error and compensation in milliseconds",
            "compensation_semantics": "presentation_audio_sec=raw_audio_sec-presentation_offset_ms/1000; corrected_audio_sec=presentation_audio_sec-compensation_ms/1000",
            "statistics_semantics": {
                "match_rate": "hits / all nonblind taps, including duplicates; not algorithm accuracy",
                "error_statistics": "all nearest-reference errors except duplicates; blind taps excluded",
                "one_target_credit": "one credit per reference time shared by J, K and SPACE",
            },
            "trial_count": self.trial_count, "total_taps": self.total_taps,
            "trials": self.trials,
        }
        metadata_fields = ["cue_id", "title", "reason", "mode", "layer", "phase",
                           "window_ms", "compensation_ms", "presentation_offset_ms", "click_enabled", "reduced_motion",
                           "start_audio_sec", "start_presentation_sec", "trim_sec", "midi_path", "midi_sha256",
                           "audio_path", "audio_sha256"]
        event_fields = ["key", "source", "judgement", "raw_audio_sec", "presentation_audio_sec", "corrected_audio_sec",
                        "target_index", "target_sec", "error_ms", "blind"]
        columns = ["session_id", "trial_id", "trial_index", "tap_index", *metadata_fields,
                   *event_fields, "algorithm_metadata_json"]
        output = io.StringIO(newline="")
        writer = csv.DictWriter(output, fieldnames=columns)
        writer.writeheader()
        for trial_index, trial in enumerate(self.trials, 1):
            metadata = trial["metadata"]
            for tap_index, event in enumerate(trial["events"], 1):
                row = {field: metadata.get(field) for field in metadata_fields}
                row.update({field: event.get(field) for field in event_fields})
                row.update(session_id=self.session_id, trial_id=trial["trial_id"],
                           trial_index=trial_index, tap_index=tap_index,
                           algorithm_metadata_json=json.dumps(metadata.get("algorithm_metadata", {}),
                                                              ensure_ascii=False, allow_nan=False))
                # Event compensation is authoritative for each individual tap.
                row["compensation_ms"] = event.get("compensation_ms", metadata.get("compensation_ms"))
                row["presentation_offset_ms"] = event.get("presentation_offset_ms", metadata.get("presentation_offset_ms", 0))
                writer.writerow(row)
        self.results_dir.mkdir(parents=True, exist_ok=True)
        json_path = self.results_dir / f"session_{self.session_id}.json"
        csv_path = json_path.with_suffix(".csv")
        _atomic_write(json_path, json.dumps(payload, ensure_ascii=False, indent=2, allow_nan=False) + "\n")
        _atomic_write(csv_path, output.getvalue())
        return json_path, csv_path
