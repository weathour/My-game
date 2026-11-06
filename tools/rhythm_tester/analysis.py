"""Deterministic MIDI pulse candidates for listening experiments.

This is a tempo-prior/event-salience baseline, not BeatRoot and not a calibrated
perceptual beat detector. All public plan times use the nominal trimmed OGG axis.
"""
from __future__ import annotations

from collections import defaultdict, deque
from dataclasses import dataclass, field
import hashlib
import io
import math
from pathlib import Path
import re
from typing import Any

import mido
import numpy as np

MAX_PULSES = 1_000_000
ALGORITHM_VERSION = "pulse-family-grid-v2"
PHASE_RESOLUTION_QUARTERS = 1 / 32
FAMILY_WEIGHTS = {
    "kick": 1.0, "snare": 0.9, "tom": 0.5, "hat": 0.12,
    "cymbal": 0.18, "percussion": 0.35, "bass": 0.85,
    "guitar": 0.55, "keys": 0.55, "strings": 0.45, "other": 0.4,
}


@dataclass(frozen=True)
class MidiNote:
    quarter: float
    end_quarter: float
    time_sec: float
    end_sec: float
    pitch: int
    velocity: int
    channel: int
    program: int
    track: int
    family: str


@dataclass
class MidiData:
    path: Path
    sha256: str
    ppq: int
    duration_sec: float
    trim_sec: float
    metadata: dict[str, Any]
    notes: tuple[MidiNote, ...] = ()
    tempo_quarters: np.ndarray = field(default_factory=lambda: np.array([0.0]))
    tempo_seconds: np.ndarray = field(default_factory=lambda: np.array([0.0]))
    tempo_us: np.ndarray = field(default_factory=lambda: np.array([500000.0]))
    end_quarter: float = 0.0
    _pulse_cache: Any = field(default=None, init=False, repr=False, compare=False)


@dataclass
class BeatPlan:
    times: np.ndarray
    strengths: np.ndarray
    mode: str
    metadata: dict[str, Any]


def _family(channel: int, program: int, pitch: int) -> str:
    if channel == 9:
        if pitch in (35, 36): return "kick"
        if pitch in (37, 38, 39, 40): return "snare"
        if pitch in (42, 44, 46): return "hat"
        if pitch in (41, 43, 45, 47, 48, 50): return "tom"
        if pitch in (49, 51, 52, 53, 55, 57, 59): return "cymbal"
        return "percussion"
    if 32 <= program <= 39: return "bass"
    if 24 <= program <= 31: return "guitar"
    if 0 <= program <= 23: return "keys"
    if 40 <= program <= 55: return "strings"
    return "other"


def quarters_to_seconds(data: MidiData, quarters: Any) -> np.ndarray:
    """Map untrimmed musical quarter positions to nominal OGG seconds."""
    q = np.asarray(quarters, dtype=float)
    i = np.clip(np.searchsorted(data.tempo_quarters, q, side="right") - 1,
                0, len(data.tempo_quarters) - 1)
    return data.tempo_seconds[i] + (q - data.tempo_quarters[i]) * data.tempo_us[i] / 1e6 - data.trim_sec


def _raw_seconds(q: float, tq: np.ndarray, ts: np.ndarray, tu: np.ndarray) -> float:
    i = max(0, int(np.searchsorted(tq, q, side="right")) - 1)
    return float(ts[i] + (q - tq[i]) * tu[i] / 1e6)


def _quarter_at_seconds(data: MidiData, seconds: float) -> float:
    raw = seconds + data.trim_sec
    i = max(0, int(np.searchsorted(data.tempo_seconds, raw, side="right")) - 1)
    return float(data.tempo_quarters[i] + (raw - data.tempo_seconds[i]) * 1e6 / data.tempo_us[i])


def parse_midi(path: str | Path, trim_override: float | None = None) -> MidiData:
    path = Path(path).expanduser().resolve()
    payload = path.read_bytes()
    try:
        mf = mido.MidiFile(file=io.BytesIO(payload))
    except (OSError, EOFError, ValueError, KeyError, IndexError) as exc:
        raise ValueError(f"Invalid MIDI file: {path.name}: {exc}") from exc
    if mf.type not in (0, 1):
        raise ValueError("Only synchronous MIDI type 0/1 is supported; type 2 has independent timelines")
    if mf.ticks_per_beat <= 0:
        raise ValueError("Only positive PPQ timing is supported (not SMPTE division)")
    events = []
    end_tick = 0
    for track_index, track in enumerate(mf.tracks):
        tick = 0
        for index, msg in enumerate(track):
            if not isinstance(msg.time, int) or msg.time < 0:
                raise ValueError("MIDI delta ticks must be nonnegative integers")
            tick += msg.time
            events.append((tick, track_index, index, msg))
        end_tick = max(end_tick, tick)
    events.sort(key=lambda row: row[:3])
    tempos = {0: 500000}
    meters, trims = [], []
    for tick, _, _, msg in events:
        if msg.type == "set_tempo":
            if msg.tempo <= 0: raise ValueError("MIDI tempo must be positive")
            tempos[tick] = msg.tempo
        elif msg.type == "time_signature":
            meters.append({"tick": tick, "numerator": msg.numerator, "denominator": msg.denominator})
        elif msg.type in ("marker", "text") and "muscriptor:bar_offset=" in msg.text:
            match = re.search(r"muscriptor:bar_offset=([+\-0-9.eE]+)", msg.text)
            if not match: raise ValueError("Malformed muscriptor bar-offset marker")
            try: value = float(match.group(1))
            except ValueError as exc: raise ValueError("Malformed bar-offset number") from exc
            if not math.isfinite(value) or value < 0: raise ValueError("Trim marker must be finite and nonnegative")
            trims.append(value)
    if trim_override is not None:
        trim = float(trim_override)
        if not math.isfinite(trim) or trim < 0: raise ValueError("Trim override must be finite and nonnegative")
        trim_source = "explicit_override"
    else:
        trim = trims[0] if trims else 0.0
        trim_source = "muscriptor:bar_offset" if trims else "absent_assumed_zero_not_audio_calibration"
    if trims and any(not math.isclose(x, trims[0], abs_tol=1e-9) for x in trims):
        raise ValueError("Conflicting bar-offset markers; provide a clean source file")
    ticks = sorted(tempos)
    tq = np.array(ticks, dtype=float) / mf.ticks_per_beat
    tu = np.array([tempos[t] for t in ticks], dtype=float)
    ts = np.zeros(len(ticks))
    if len(ts) > 1: ts[1:] = np.cumsum(np.diff(tq) * tu[:-1] / 1e6)
    end_quarter = end_tick / mf.ticks_per_beat
    raw_duration = _raw_seconds(end_quarter, tq, ts, tu)
    programs = defaultdict(int)
    active = defaultdict(deque)
    pairs = []
    unmatched_off = 0
    for tick, track, _, msg in events:
        if msg.type == "program_change":
            programs[msg.channel] = msg.program
        elif msg.type == "note_on" and msg.velocity > 0:
            active[(track, msg.channel, msg.note)].append((tick, msg.velocity, programs[msg.channel]))
        elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
            key = (track, msg.channel, msg.note)
            if active[key]:
                start, velocity, program = active[key].popleft()
                pairs.append((start, tick, track, msg.channel, msg.note, velocity, program))
            else: unmatched_off += 1
    unclosed = sum(len(queue) for queue in active.values())
    for (track, channel, pitch), queue in active.items():
        for start, velocity, program in queue:
            pairs.append((start, end_tick, track, channel, pitch, velocity, program))
    notes = []
    for start, end, track, channel, pitch, velocity, program in sorted(pairs):
        q, eq = start / mf.ticks_per_beat, end / mf.ticks_per_beat
        notes.append(MidiNote(q, eq, _raw_seconds(q, tq, ts, tu)-trim,
                              _raw_seconds(eq, tq, ts, tu)-trim,
                              pitch, velocity, channel, program, track, _family(channel, program, pitch)))
    metadata = {
        "midi_type": mf.type, "raw_duration_sec": raw_duration, "end_tick": end_tick,
        "trim_source": trim_source, "trim_marker_values": trims,
        "time_signatures": meters, "meter_known": bool(meters),
        "unknown_meter_policy": "no fabricated 4/4 or automatic downbeat labels",
        "tempo_map": [{"tick": t, "quarter": float(q), "time_sec_untrimmed": float(sec), "us_per_quarter": int(u)}
                      for t, q, sec, u in zip(ticks, tq, ts, tu)],
        "note_count": len(notes), "unclosed_notes_closed_at_end": unclosed,
        "unmatched_note_offs": unmatched_off, "timeline": "nominal OGG seconds = integrated MIDI seconds - trim",
        "audio_tail_policy": "MIDI duration excludes any additional rendered release/reverb tail",
        "duration_model": "note-on/off pairing, not sustain-pedal or instrument envelope duration",
        "family_model": "GM program/channel heuristic; bank/soundfont loudness is not inferred",
    }
    return MidiData(path, hashlib.sha256(payload).hexdigest(), mf.ticks_per_beat,
                    max(0.0, raw_duration-trim), trim, metadata, tuple(notes), tq, ts, tu, end_quarter)


def _events(data: MidiData) -> dict[str, tuple[np.ndarray, np.ndarray]]:
    # Same-family simultaneous notes/chords use max, never a vote per note.
    bins: dict[str, dict[int, tuple[float, float]]] = defaultdict(dict)
    for note in data.notes:
        if note.time_sec < 0 or note.time_sec > data.duration_sec: continue
        duration_bonus = 1.0 if note.channel == 9 else 0.8 + 0.2 * min(1.0, note.end_quarter-note.quarter)
        strength = math.sqrt(note.velocity / 127.0) * duration_bonus
        key = round(note.quarter * 192)
        old = bins[note.family].get(key)
        if old is None or strength > old[1]: bins[note.family][key] = (note.quarter, strength)
    result = {}
    for family, rows in bins.items():
        values = sorted(rows.values())
        result[family] = (np.array([r[0] for r in values]), np.array([r[1] for r in values]))
    return result


def _grid(data: MidiData, rate: float, offset: float) -> np.ndarray:
    if data.duration_sec <= 0: return np.empty(0)
    start = max(0.0, _quarter_at_seconds(data, 0.0))
    first = math.ceil((start-offset)*rate-1e-9)
    last = math.floor((data.end_quarter-offset)*rate+1e-9)
    size = max(0, last-first+1)
    if size > MAX_PULSES: raise ValueError("Pulse plan is too large")
    return offset + np.arange(first, last+1, dtype=float) / rate


def _salience(qgrid: np.ndarray, rate: float, events: dict) -> np.ndarray:
    values = np.zeros(len(qgrid))
    if not len(qgrid): return values
    denominator = sum(FAMILY_WEIGHTS[f] for f in events) or 1.0
    sigma = min(0.08, 0.12/rate)
    for family, (q, weights) in events.items():
        indices = np.rint((q-qgrid[0])*rate).astype(np.int64)
        valid = (indices >= 0) & (indices < len(qgrid))
        indices = indices[valid]
        distance = q[valid]-qgrid[indices]
        matched = weights[valid]*np.exp(-0.5*(distance/sigma)**2)
        family_peaks = np.zeros(len(qgrid))
        np.maximum.at(family_peaks, indices, matched)
        values += FAMILY_WEIGHTS[family]*family_peaks/denominator
    return np.clip(values, 0.0, 1.0)


def _observation_support(events: dict) -> tuple[float, float] | None:
    """One candidate-independent observation interval for all metrical layers.

    Erode the observed onset extent by half the longest candidate period (2q)
    at both ends. Thus every scored pulse has an observed complete centered
    cycle, rather than treating an end-of-track padding pulse as evidence.
    """
    if not events: return None
    first = min(float(q[0]) for q, _ in events.values() if len(q))
    last = max(float(q[-1]) for q, _ in events.values() if len(q))
    start, end = first + 1.0, last - 1.0
    return (start, end) if end >= start else None


def _score(data: MidiData, rate: float, offset: float, events: dict) -> dict:
    grid = _grid(data, rate, offset)
    support = _observation_support(events)
    grid = grid[(grid >= support[0]-1e-9) & (grid <= support[1]+1e-9)] if support is not None else np.empty(0)
    strengths = _salience(grid, rate, events)
    if not len(grid): return {"score": 0.0, "alignment": 0.0, "coverage": 0.0, "stability": 0.0, "comfort": 0.0}
    alignment = float(np.mean(strengths))
    coverage = float(np.mean(strengths > 0.2))
    chunks = np.array_split(strengths, max(1, min(16, len(strengths)//8)))
    means = np.array([np.mean(c) for c in chunks])
    stability = max(0.0, 1.0-float(np.std(means))/(alignment+0.05))
    # Median local candidate rate; this is a preference, not a tactus label.
    i = np.clip(np.searchsorted(data.tempo_quarters, grid, side="right")-1, 0, len(data.tempo_us)-1)
    bpm = float(np.median(60e6/data.tempo_us[i]*rate))
    comfort = math.exp(-0.5*(math.log2(max(bpm,1e-9)/110.0)/0.65)**2)
    score = 0.62*alignment + 0.10*coverage + 0.10*stability + 0.18*comfort
    return {"score": score, "alignment": alignment, "coverage": coverage,
            "stability": stability, "comfort": comfort, "median_bpm": bpm}


def _onsets(data: MidiData, layer: float, phase: float) -> BeatPlan:
    notes = [n for n in data.notes if n.channel == 9 and 0 <= n.time_sec <= data.duration_sec]
    source = "drum_note_onsets"
    if not notes:
        notes = [n for n in data.notes if 0 <= n.time_sec <= data.duration_sec]
        source = "all_note_onsets_fallback_no_drums"
    # Strongest-first nonmaximum suppression prevents an earlier weak ornament
    # from deleting a stronger nearby event. This mode remains an onset control.
    candidates = sorted(((n.time_sec, FAMILY_WEIGHTS[n.family]*math.sqrt(n.velocity/127.0))
                         for n in notes), key=lambda x: (-x[1], x[0]))
    selected: dict[int, tuple[float,float]] = {}
    gap = 0.12
    for time, strength in candidates:
        bucket = int(time/gap)
        if any(abs(time-selected[b][0]) < gap for b in (bucket-1,bucket,bucket+1) if b in selected): continue
        selected[bucket] = (time,strength)
    rows = sorted(selected.values())
    return BeatPlan(np.array([r[0] for r in rows]), np.array([r[1] for r in rows]), "onsets",
                    {"method":"strongest-first merged onset comparison, not inferred beat", "onset_source":source,
                     "algorithm_version":"onsets-nms-v1","phase_resolution_quarters":None,
                     "min_gap_sec":gap,"layer_phase_applied":False,"requested_layer":layer,"requested_phase":phase,
                     "modifier_policy":"onset mode keeps observed onset times; layer/phase controls apply only to pulse/quarter"})


def build_plan(data: MidiData, mode: str = "pulse", layer: float = 1.0, phase: float = 0.0) -> BeatPlan:
    if mode not in ("pulse", "quarter", "onsets"): raise ValueError(f"Unknown plan mode: {mode}")
    layer, phase = float(layer), float(phase)
    if layer not in (0.5, 1.0, 2.0) or phase not in (0.0, 0.5):
        raise ValueError("Layer must be0.5/1/2 and phase0/0.5")
    if mode == "onsets": return _onsets(data, layer, phase)
    # All rates see the same absolute quarter resolution. Fraction-of-period
    # scans unfairly gave faster rates access to offsets absent at slower rates.
    key = (ALGORITHM_VERSION, data.notes, data.trim_sec, data.duration_sec,
           data.end_quarter, data.tempo_quarters.tobytes(),
           data.tempo_seconds.tobytes(), data.tempo_us.tobytes(),
           tuple(FAMILY_WEIGHTS.items()))
    cached = data._pulse_cache
    if mode == "pulse" and cached is not None and cached[0] == key:
        events = cached[1]
        candidates = [dict(row) for row in cached[2]]
    else:
        events = _events(data)
        candidates = []
        if mode == "pulse" and events:
            for rate in (0.5, 1.0, 2.0):
                for offset in np.arange(0.0, 1.0/rate, PHASE_RESOLUTION_QUARTERS):
                    offset = float(offset)
                    row = {"rate":rate, "phase":offset*rate,
                           "offset_quarters":offset}
                    row.update(_score(data, rate, offset, events))
                    candidates.append(row)
            candidates.sort(key=lambda r: (-r["score"], abs(math.log2(r["rate"])), r["phase"]))
        if mode == "pulse":
            # Detached rows: a caller editing plan.metadata must not poison the
            # data-intrinsic cache or later layer/phase comparisons.
            data._pulse_cache = (key, events, tuple(dict(row) for row in candidates))
    chosen = candidates[0] if candidates else {"rate":1.0,"phase":0.0,"offset_quarters":0.0}
    rate = chosen["rate"]*layer
    offset = chosen["offset_quarters"]+phase/rate
    grid = _grid(data, rate, offset)
    times = quarters_to_seconds(data, grid)
    valid = (times >= -1e-9) & (times <= data.duration_sec+1e-9)
    strengths = _salience(grid, rate, events)
    metadata = {
        "method":("tempo-prior, capped instrument-family salience, stable whole-file grid candidate"
                  if mode == "pulse" else "MIDI quarter-grid comparison; no perceptual beat inference"),
        "disclaimer":"not full BeatRoot; not identified human tactus; scores uncalibrated, not accuracy/confidence probabilities",
        "algorithm_version":ALGORITHM_VERSION if mode == "pulse" else "quarter-grid-v1",
        "phase_resolution_quarters":PHASE_RESOLUTION_QUARTERS if mode == "pulse" else None,
        "selected_rate":chosen["rate"],"selected_phase":chosen["phase"],
        "effective_rate":rate,"offset_quarters":offset,"requested_layer":layer,"requested_phase":phase,
        "candidate_rankings":candidates,"score_gap":candidates[0]["score"]-candidates[1]["score"] if len(candidates)>1 else None,
        "changed_score_support": mode == "pulse",
        "score_support": {"quarters":list(_observation_support(events)) if _observation_support(events) is not None else None,
                          "edge_guard_quarters":1.0,"policy":"same observed onset span eroded by half the longest candidate period on each side; insufficient span yields zero evidence score"},
        "family_weights":dict(FAMILY_WEIGHTS),"event_families":list(events),
        "family_density_policy":"max per family per pulse; simultaneous same-family chords capped, not note-count voting",
        "meter_known":data.metadata.get("meter_known",False),"downbeats_inferred":False,
        "empty_note_fallback":not bool(events),"timeline":"nominal trimmed OGG seconds",
    }
    return BeatPlan(np.maximum(0.0,times[valid]), strengths[valid], mode, metadata)
