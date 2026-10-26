# Runtime correctness and lifecycle benchmark evidence

## Implemented contracts

- Scene cleanup explicitly frees detached enemy and pickup pools, then clears their registries. The cleanup is idempotent. Previously detached pooled nodes survived the main scene's lifetime (`before-contract-probe.log`).
- Enemy activation identity is the metadata key `runtime_enemy_activation_generation`, managed by `enemy_pool_lifecycle.gd`. `apply_enemy_profile()` advances it; normal subsequent activation only ensures it exists. Direct reuse of an inactive pooled enemy advances it. Save hydration does not independently advance it. This is runtime identity, not a persisted field.
- Both deferred damage boundaries capture generation: `player_damage_batcher` and `player_damage_job_queue`. Old generations cannot merge with or damage a replacement. Missing metadata at execution rejects the job. Batcher flush filters dead, pooled and freed targets before consuming gunner event multipliers or creating damage/status/energy work.
- Every effective player projectile checks its actual current physics-step segment. Expiry retains only its clamped final movement segment until collision is resolved. There is no cross-frame path history: checking old segments against current enemy positions would miss enemies that crossed earlier and could hit later arrivals. The 1,800 projectile capacity, candidate cache and MultiMesh renderer remain. The previous 380-query skip budget is removed; `player_projectile_collision_checks` reports actual segment queries, including additional piercing queries.
- Congested low-FPS spawn warnings keep their full 0.94-second reaction duration. Completion emission and enemy creation remain throttled; overflow no longer enters the finished queue immediately. This deliberately retains additional visible warning work rather than changing combat rules.

## Verification

Before-change isolated probes are retained as `.gd.txt` plus logs. They demonstrate stale deferred damage to a reused node, detached pool survival, an untested projectile path under the old 380 budget, and 4 of 40 warnings finishing after 10ms at 25 FPS.

`runtime_lifecycle_contract_smoke.gd` covers activation/profile reuse, missing identity, queue compaction/timestamps, stale batcher entries, dead/pooled/freed gunner targets without side effects, detached enemy/pickup cleanup, idempotence and all 40 warnings completing exactly once after their full duration. Its retained run exercised the warning case at actual measured 13 FPS.

`player_projectile_path_contract_smoke.gd` covers the last of 1,800 effective bullets in the same step, expiry tail, a moving target crossing the first segment and then leaving, a later arrival on an old segment, per-step sine curvature, one-step multi-target piercing, swap removal, no-enemy expiry and visual-only expiry. The moving-target checks compare explicit per-step geometry; they do not simulate a whole game completion.

Relevant existing smoke logs here passed after the final traversal change: projectile query/render, damage resolver/dead target, gunner entry/authored projectile, plant enemy, combat wave/blessing, spawn flow and spawn smoothing. The projectile pool smoke also passed; its pool API did not change. Render smoke is headless instance validation, not visual acceptance. The parent owns the final full gate and graph refresh.

## Instrumentation and performance boundaries

Damage counters retain existing counts and add `completed_damage_jobs` (all dequeued attempts), `resolved_damage_jobs` (live current-life applications), `discarded_stale_damage_jobs`, `damage_queue_oldest_wait_us`, and `damage_queue_completed_wait_us`. Age counters use `performance_counters.record_max`, not addition. Wall-clock queue age includes pause time; interpret it with paused state. Generation and timestamp storage add two integer-array entries per queued job, and one generation entry per batcher target. There is no projectile history allocation.

`battle_lifecycle_benchmark.gd` is an explicit manual script, not an automatic `*_smoke` gate. It refuses to run unless `MY_GAME_BENCHMARK_ISOLATED=1` and `user://` resolves inside `/tmp/`. It creates the actual `main.tscn`, with a fixed seed, 40 normal spawn requests, two authored elites, the final Boss's phase-3 routine, 512 initial hostile projectiles and repeated effective player attacks. The player is invulnerable and the natural spawn timer is held for the controlled workload. This measures a controlled battle, not a 20-wave playthrough or difficulty acceptance.

The script records actual process-frame wall intervals (avg/p95/p99/max), engine process CPU separately, existing main scopes, save/spawn/cleanup timings, entity peaks, queue throughput/age, collision queries and post-exit node/orphan/resource/static-memory counts. The normal mode performs ten entries/exits and checks the final three node/orphan/resource snapshots agree. An engine FPS cap of 120 applies; the report must retain renderer and display details.

`real-main-quick.json` and its log are a two-cycle functional check made during other agents' activity. They establish valid saves and actual scene teardown (both exits: 12 nodes, 0 orphans, 738 resources). Their timing samples are **not exclusive performance measurements** and must not be presented as an FPS improvement. Save calls of roughly 112–198ms motivated additional stage scopes before formal measurement.

The save scopes now separately record `save_payload_build_ms`, `save_payload_validate_ms`, `save_payload_finite_ms` (inside validation), `save_json_serialize_ms`, `save_primary_commit_ms` and `save_backup_commit_ms`, inside the existing `save_run_ms` total. Primary/backup scopes include their atomic temp-file write, flush, close and rename; they are CPU wall durations of synchronous file operations, not GPU timing. The existing paired writer already serialized JSON once and reused that string for both commits. Measurements justified the save owner's finite-scalar fast path and unsorted compact JSON; validation rules and atomic writes remain intact. See `performance-findings.md` and sibling `../state/` evidence. No threading or write-safety change was introduced.

## Final exclusive measurements

Both final ten-cycle runs completed cleanly: `real-main-final-headless.json/.log` and `real-main-final-x11.json/.log`. Each records actual physics steps, wave state, CPU/GPU/display/audio identity and both two-frame and thirty-frame exit snapshots. The thirty-frame node/orphan/resource snapshots are **12/0/738 in every cycle of both runs**. X11 two-frame snapshots still reach 740/742 resources before returning to 738; the original strict failure is retained separately. No stability threshold was widened. Static allocation is not perfectly flat: headless grows ~306KB from cycle1→10; X11 has a first→second-cycle increase ~2.33MB and another ~186KB from cycle2→10. Ten exits establish node/resource settlement, not an exhaustive memory-leak proof.

| First long cycle | Headless | X11 / Dummy |
| --- | ---: | ---: |
| Physics steps / process frames | 1483 / 360 | 1460 / 360 |
| Wall avg / p95 / p99 / max | 88.43 / 205.94 / 442.26 / 458.26 ms | 83.35 / 213.86 / 413.22 / 609.71 ms |
| Sampled enemy / hostile / player bullet peaks | 48 / 2034 / 80 | 48 / 2035 / 47 |

X11 reports Intel i5-14600K, NVIDIA GeForce RTX 5080, Vulkan 1.4.312 / Forward Mobile, X11 and Dummy audio. Headless reports no GPU; its configured renderer name is not evidence of GPU rendering. Both long cycles remain wave1/combat with ordinary spawn timers positive. Player-bullet peaks sample before and after fixture attack injection; instantaneous substep peaks may differ. Frame and scope counters can accumulate several physics updates, so their counts are not simultaneous entity populations.

The dense workload still exceeds a 16.7ms frame budget. Queue completion age reaches ~1.26–1.30 seconds in the long final cycles. Process-frame averages changed alongside physics-step counts and live workloads, so they do not establish a causal FPS gain. The equal-fixed-step projectile microprobe offers only modest local evidence; the slower wave-cache candidate was removed. No full twenty-wave, new-player, balance or subjective render acceptance is claimed.

`player-projectile-capacity-profile.log` isolates 1800 effective player bullets: input storage increases `MEMORY_STATIC` by 1,449,516 bytes without initializing MultiMesh resources, with zero path-history allocation. One fixed motion/collision step costs 3.89–4.05ms for 1799 misses plus one hit, versus 46.51–47.26ms when all 1800 hit one target (merged into one job with 1800 hits). These are bounded fixtures, not production frequency estimates or the worst possible piercing/many-target upper bound. Effective collision checks remain complete.

Probe sources are archived as `.gd.txt`; the final context patch and before-context sources are retained to reconstruct equal-step comparisons without altering production files. The parent owns the final full gate, graph refresh and isolated PCK verification. Runtime and test source edits are frozen for that handoff.
