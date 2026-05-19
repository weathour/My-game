#!/usr/bin/env python3
"""Evaluate dense-combat benchmark evidence for the OMX performance goal."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GODOT = "/home/weathour/.local/bin/godot-4.6.2"


def _load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def _run_benchmark(results: Path) -> None:
    godot_bin = os.environ.get("GODOT_BIN", DEFAULT_GODOT)
    if not Path(godot_bin).exists():
        raise RuntimeError(f"Godot binary not found: {godot_bin}")
    results.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["DENSE_COMBAT_BENCHMARK_RESULTS"] = str(results)
    cmd = [
        godot_bin,
        "--headless",
        "--path",
        str(ROOT),
        "--script",
        "scripts/tests/dense_combat_benchmark_smoke.gd",
    ]
    completed = subprocess.run(cmd, cwd=ROOT, env=env, text=True, capture_output=True)
    (results / "godot_benchmark_stdout.log").write_text(completed.stdout, encoding="utf-8")
    (results / "godot_benchmark_stderr.log").write_text(completed.stderr, encoding="utf-8")
    if completed.returncode != 0:
        raise RuntimeError(f"dense combat benchmark failed with exit {completed.returncode}")


def _metric(data: dict[str, Any], key: str) -> float:
    try:
        return float(data.get("frame_time", {}).get(key, 0.0))
    except (TypeError, ValueError):
        return 0.0


def _counter(data: dict[str, Any], key: str) -> float:
    try:
        return float(data.get("gameplay_counters", {}).get(key, 0.0))
    except (TypeError, ValueError):
        return 0.0


def _improvement(old: float, new: float) -> float:
    if old <= 0.0:
        return 0.0
    return (old - new) / old


def _regression(old: float, new: float) -> float:
    if old <= 0.0:
        return 0.0
    return (new - old) / old


def evaluate(results: Path) -> tuple[bool, list[str]]:
    baseline_path = results / "baseline.json"
    candidate_path = results / "candidate.json"
    # Always refresh the benchmark artifacts so a passing evaluator cannot rely on
    # stale baseline/candidate files from an earlier optimization attempt.
    _run_benchmark(results)
    baseline = _load_json(baseline_path)
    candidate = _load_json(candidate_path)
    failures: list[str] = []

    for required in ["p95_ms", "p99_ms", "max_ms", "avg_ms"]:
        if _metric(baseline, required) <= 0.0:
            failures.append(f"baseline missing positive {required}")
        if _metric(candidate, required) <= 0.0:
            failures.append(f"candidate missing positive {required}")

    p95_gain = _improvement(_metric(baseline, "p95_ms"), _metric(candidate, "p95_ms"))
    p99_gain = _improvement(_metric(baseline, "p99_ms"), _metric(candidate, "p99_ms"))
    max_gain = _improvement(_metric(baseline, "max_ms"), _metric(candidate, "max_ms"))
    if p95_gain < 0.10 and p99_gain < 0.10 and max_gain < 0.15:
        failures.append(
            "candidate did not improve p95/p99 by >=10% or max frame by >=15% "
            f"(p95={p95_gain:.1%}, p99={p99_gain:.1%}, max={max_gain:.1%})"
        )

    avg_regression = _regression(_metric(baseline, "avg_ms"), _metric(candidate, "avg_ms"))
    p99_regression = _regression(_metric(baseline, "p99_ms"), _metric(candidate, "p99_ms"))
    max_regression = _regression(_metric(baseline, "max_ms"), _metric(candidate, "max_ms"))
    if avg_regression > 0.03:
        failures.append(f"candidate avg frame time regressed by {avg_regression:.1%}")
    if p99_regression > 0.05:
        failures.append(f"candidate p99 frame time regressed by {p99_regression:.1%}")
    if max_regression > 0.05:
        failures.append(f"candidate max frame time regressed by {max_regression:.1%}")

    deterministic_keys = [
        "enemy_count",
        "enemy_projectile_count",
        "pickup_count",
        "pooled_reactivations",
        "duplicate_tick_failures",
    ]
    for key in deterministic_keys:
        if _counter(baseline, key) != _counter(candidate, key):
            failures.append(f"gameplay counter {key} changed: {_counter(baseline, key)} -> {_counter(candidate, key)}")

    if _counter(candidate, "duplicate_tick_failures") != 0:
        failures.append("candidate reported duplicate/skipped tick failures")

    cpu_artifact = results / "cpu_core_utilization.txt"
    limitation = candidate.get("cpu_sampling_limitation", "")
    if not cpu_artifact.exists() and not limitation:
        failures.append("missing CPU/core utilization artifact or documented limitation")

    summary = {
        "pass": not failures,
        "p95_gain": p95_gain,
        "p99_gain": p99_gain,
        "max_gain": max_gain,
        "failures": failures,
        "baseline": str(baseline_path),
        "candidate": str(candidate_path),
        "csv": str(results / "dense_combat_summary.csv"),
    }
    _write_csv_summary(results / "dense_combat_summary.csv", baseline, candidate)
    (results / "evaluation_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return not failures, failures


def _write_csv_summary(path: Path, baseline: dict[str, Any], candidate: dict[str, Any]) -> None:
    rows = ["label,avg_ms,p95_ms,p99_ms,max_ms,enemy_count,enemy_projectile_count,pickup_count,projectile_hits"]
    for label, data in [("baseline", baseline), ("candidate", candidate)]:
        rows.append(
            ",".join(
                [
                    label,
                    f"{_metric(data, 'avg_ms'):.6f}",
                    f"{_metric(data, 'p95_ms'):.6f}",
                    f"{_metric(data, 'p99_ms'):.6f}",
                    f"{_metric(data, 'max_ms'):.6f}",
                    f"{_counter(data, 'enemy_count'):.0f}",
                    f"{_counter(data, 'enemy_projectile_count'):.0f}",
                    f"{_counter(data, 'pickup_count'):.0f}",
                    f"{_counter(data, 'projectile_hits'):.0f}",
                ]
            )
        )
    path.write_text("\n".join(rows) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", required=True)
    parser.add_argument("--results", required=True)
    args = parser.parse_args()
    contract = ROOT / args.contract if not Path(args.contract).is_absolute() else Path(args.contract)
    if not contract.exists():
        print(f"missing evaluator contract: {contract}", file=sys.stderr)
        return 2
    results = ROOT / args.results if not Path(args.results).is_absolute() else Path(args.results)
    try:
        passed, failures = evaluate(results)
    except Exception as exc:  # noqa: BLE001 - command-line evaluator should report blocker.
        print(f"DENSE_COMBAT_PERF_EVALUATOR_BLOCKED: {exc}", file=sys.stderr)
        return 2
    if not passed:
        print("DENSE_COMBAT_PERF_EVALUATOR_FAIL")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("DENSE_COMBAT_PERF_EVALUATOR_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
