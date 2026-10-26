# Exclusive baseline and bounded CPU diagnosis

2026-10-25; editor engine Godot 4.6.2; CPU Intel Core i5-14600K. The first formal headless run and X11 run were sequential during an exclusive project Godot window. X11 used `DISPLAY=:0 --display-driver x11 --audio-driver Dummy`, Vulkan 1.4.312 / Forward Mobile, NVIDIA GeForce RTX 5080. Headless reported no video adapter; its `mobile` rendering-method setting is not evidence of GPU rendering. No software-rendering claim is made.

## Preserved baseline

| First cycle, 360 process frames | Headless | X11 / Dummy audio |
| --- | ---: | ---: |
| Actual wall interval average | 101.38 ms | 108.77 ms |
| p95 | 219.58 ms | 232.33 ms |
| p99 | 563.09 ms | 557.81 ms |
| Maximum | 612.86 ms | 598.35 ms |
| Peak enemies / hostile bullets / sampled player bullets | 48 / 2036 / 52 | 49 / 2035 / 1 |
| Save validation, session total | 2346.79 ms | 2468.73 ms |
| JSON serialization, session total | 1037.83 ms | 1110.90 ms |
| Payload build, session total | 288.27 ms | 287.32 ms |
| Primary / backup file commit totals | 77.15 / 70.89 ms | 76.07 / 72.02 ms |

The two output JSON/log pairs are `real-main-headless.*` and `real-main-x11.*`. Both performed ten scene entries/exits. All twenty node/orphan snapshots were 12/0. All ten headless resource snapshots were 738. X11 resources alternated between 738 and 740 after only two process frames; its strict final-three-resource-equality assertion failed. That failure is retained; it must not be reported as a fully passed stability test or silently replaced by a wider threshold. Subsequent results include both the original two-frame observation and a thirty-frame settlement observation.

These baseline snapshots did not yet capture physics-step or wave state, so timing cannot establish equal physics work between backends or later versions. They demonstrate that the selected dense workload is far above a 16.7ms frame budget on this machine. The player was invulnerable and attacks were injected through existing APIs; this is neither a balance test nor a twenty-wave completion claim.

## Diagnostic workload validity and physics costs

`real-main-x11-diagnostic.*` repeats the long first-cycle workload with added scopes and authoritative wave observations. It measured **1715 physics steps across 360 process frames**, with survival time 6.989→35.688 seconds. Wave state remained `wave=1`, `phase=combat`; `spawn_remaining` stayed positive (53.011→24.312 seconds). Ordinary natural spawning never reached its timer. Flybys are authored only for waves 8/14/19. Existing shadow-tree seed/young-tree summons remain enabled, explaining that the actual enemy population can exceed the forty normal requests plus two elites and final Boss. These are controlled initial conditions with live authored summons, not a static count of exactly 43 enemies.

| Inclusive diagnostic scope | Total | Total / physics steps | Peak single scope |
| --- | ---: | ---: | ---: |
| Hostile projectile simulation | 13215.28 ms | 7.71 ms | 24.00 ms |
| Hostile renderer synchronization | 20.66 ms | 0.012 ms | 14.62 ms |
| Eligible enemy batch | 6086.20 ms | 3.55 ms | 11.32 ms |
| Individual enemy ticks | 4353.06 ms | 2.54 ms | 36.22 ms |
| Player projectile collision | 114.03 ms | 0.067 ms | 5.26 ms |
| Player projectile motion / render | 0.63 / 5.70 ms | — | 0.019 / 0.169 ms |

Scopes overlap: the main physics scope contains batch scopes, while individual enemy/player-node callbacks run separately. Do not add all rows to a main scope or treat a local CPU total as FPS. Hostile per-bullet renderer-transform writes occur inside simulation, not the final renderer-sync scope. A process-frame counter can aggregate several physics steps; `batched_enemy_projectiles` peak 16323 is processed tick work, not 16323 simultaneously live bullets. The actual hostile bullet peak was 2035.

The same diagnostic reported 578 queued and 578 completed damage jobs; oldest/completed waiting age peaked around 1.315 seconds. Queue age uses wall time, so save stalls and frame catch-up are visible. The fixture stayed running and unpaused.

## Save candidate measurement

Diagnostic finite-value traversal consumed 1639.89ms of 2210.71ms total validation (~74%). A `/tmp` microprobe then retained the real diagnostic player/44-enemy snapshot and repeated one original projectile to 2000 entries, yielding 3,857,626 serialized characters. This synthetic capacity fixture is separate from whole-game occurrence frequency.

Five sequential repetitions (`save-finite-scalar-skip-profile.log`) measured the original finite traversal at 161.66–198.67ms. Checking finite scalar children directly, and only constructing a diagnostic path/recursing for containers or nonfinite floats, took 58.86–72.30ms. INF/NAN nested error paths matched. No validation rule was bypassed. Sorted JSON serialization took 96.02–118.34ms versus 93.07–108.40ms without key sorting; parsing both strings yielded equal values. The unsorted candidate's benefit is smaller and must not be overstated. The original writer was already compact and serialized once for both atomic commits.

The save owner implemented both local candidates and passed the five affected save smokes plus headless parsing. His same-payload before/after evidence records median finite traversal 187.9→57.2ms and validation 243.2→108.0ms. Interleaved sorted/unsorted serialization measured 117.9→113.3ms; the larger cross-process change is not attributed to sorting. See sibling `../state/save-validation-before.log`, `save-validation-after.log` and `save-pair-interleaved.log`. File flush/rename safety and public `save_run` validation remain intact. No worker thread or trusted-payload bypass was introduced.

## Hostile projectile capacity microprofile

`enemy-bullet-stage-profile.log` uses 2000 live bullets for fifty fixed 1/60s simulation steps against a stationary target. It does not use process-frame timing or naturally vary the step count. Original production code measured 17.36ms/step (straight), 18.78ms (danmaku), and 18.77ms (bloom), including per-bullet renderer-transform updates. A copied `/tmp` version with per-stage timers added 35–41% overhead; its substage proportions are diagnostic hints, not independent production CPU budgets. Motion, lifetime/relevance preparation, renderer-transform calls, target-hit checks, and merchant/split handling all contribute; there was no single giant polygon-rebuild loop in this path.

The first bounded runtime candidate cached wave-object lookup within a physics frame and scene identity. Its fixed-step A/B became slower: straight 16.54→18.70ms/step, danmaku 19.54→20.17, bloom 18.43→18.99 (`enemy-bullet-context-ab.log`). **That wave cache was removed.** Merchant phase/health/position and scene/wave lookup remain live per bullet; no extra cache layer survives.

The final local change prepares target geometry once within a normal bullet tick, retains the direct helper's default preparation, and keys geometry by physics frame plus target identity. Merchant and reflected gameplay branches invalidate the target snapshot before later bullets. The extended existing context smoke passed target movement/resize callbacks, cross-frame reuse, target changes, merchant death and its target-moving callback, scene replacement/free and the reflected branch. Batch/rework/renderer-lifecycle smokes also passed; no additional smoke name was added.

`enemy-bullet-context-paired.log` alternates before/after order in five in-process pairs, resetting the same 2000 danmaku bullets before every fifty-fixed-step sample. Before: 7.270/8.267/7.895/8.204/9.566ms per step; after: 7.212/8.359/6.824/7.807/9.242. Four pairs improved and one regressed; paired median reduction was about 3.4%, with substantial variation. This is modest local evidence, not a whole-frame FPS claim. The patch and probe source are retained beside the logs. Player projectile collisions remain checked every effective step; the old 380-query skip is not restored.

## Final ten-cycle results

`real-main-final-headless.*` and `real-main-final-x11.*` both completed with empty failure lists and strict stable resource results. Every thirty-frame-settled exit reports 12 nodes / 0 orphans / 738 resources. X11's separate two-frame snapshots report 740 in cycle3 and 742 in cycle6, each settling to 738 by frame30. This directly explains the initial two-frame strict failure without relaxing the equality requirement. The exact transient resource owner was not attributed, so it is not labelled an audio or renderer leak.

| Final first long cycle | Headless | X11 / Dummy |
| --- | ---: | ---: |
| Actual physics steps / process frames | 1483 / 360 | 1460 / 360 |
| Survival time start→end | 1.595→26.309s | 2.283→26.518s |
| Final ordinary spawn timer | 33.691s | 33.482s |
| Wave / phase throughout | 1 / combat | 1 / combat |
| Wall avg / p95 / p99 / max | 88.43 / 205.94 / 442.26 / 458.26ms | 83.35 / 213.86 / 413.22 / 609.71ms |
| Sampled entity peaks: enemies / hostile / player bullets | 48 / 2034 / 80 | 48 / 2035 / 47 |
| Finite / full validation session totals | 611.85 / 1186.87ms | 629.99 / 1192.87ms |
| Total save / peak single save scope | 2525.04 / 244.04ms | 2532.37 / 258.05ms |

The final X11 JSON confirms Dummy audio and the actual NVIDIA adapter; the startup log records Vulkan 1.4.312. Ordinary timed spawns remain suppressed by the controlled sixty-second timer throughout each long cycle; live summons and Boss pattern changes continue. Source-defined wave1 duration is sixty seconds and flybys occur only at waves8/14/19, so these observations do not cross a natural next wave. Entity peaks are process samples plus post-injection player-bullet samples, not an instrumented maximum of every intra-step transition.

The final long X11 cycle spent 13.124s in hostile simulation across 1460 physics steps (~8.99ms/step), 4.478s in enemy batch and 3.406s in individual enemy ticks. Hostile simulation still dominates; no further cache layers or framework rewrite were added. Final oldest/completed damage age reaches ~1.26 seconds (X11) and ~1.30 seconds (headless), while unpaused. Save spikes and repeated physics catch-up are visible in full wall-frame timings. The maximum 609.71ms frame is not reduced to a GPU or disk diagnosis by these scopes.

Across ten final entries, initial workload construction peaked at 72.79ms (headless) / 71.28ms (X11), queued-spawn drain wall time at 490.22 / 729.08ms, and synchronous scene destruction at 63.11 / 62.91ms. These are intentionally separate from steady battle frames. The long sampled cycles queued/completed 588/588 damage jobs (headless) and 584/584 (X11); this does not assert that every short cycle ended with no unsampled pending work.

All twenty final node/orphan/resource snapshots settle exactly, but static allocation is not completely flat: headless cycle1→10 rises 306,016 bytes; X11 cycle1→2 rises 2,333,080 bytes and cycle2→10 another 185,808 bytes. These ten repetitions establish settlement of counted objects; longer memory profiling remains necessary before claiming a general allocation plateau.

The dedicated player-capacity fixture (`player-projectile-capacity-profile.*`) appends 1800 effective bullets without initializing their renderer. Static allocation increases 1,449,516 bytes; no historical-path storage exists. One fixed motion/collision step costs 3.89–4.05ms for 1799 misses plus one hit, or 46.51–47.26ms when all 1800 hit the same target. The latter queues one merged job containing 1800 hits. It is a deliberately congested fixture, separate from formal encounter frequency and not a many-target/piercing worst-case upper bound.

The dense full-scene workload still exceeds 16.7ms and remains a measured target-machine/high-density release risk. Earlier/later process-frame averages have different physics work and live populations and cannot be divided to claim a pure FPS improvement. No enemies were removed, no collision or telegraph step was skipped, and public save validation remains active. The parent owns the final full gate and isolated PCK verification; runtime source is frozen after these results.
