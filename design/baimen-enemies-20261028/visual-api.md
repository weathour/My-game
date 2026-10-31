# Frozen W3 enemy visual API v1
Directory: res://assets/enemies/baimen/<visual_id>/
portrait.png = transparent full-body standing illustration, shown uncropped in codex.
manifest.json example:
{
 "version":1,"visual_id":"E01","status":"final",
 "body_height_px":80,"anchor_px":[96,176],
 "clips":{
  "idle":{"file":"idle.png","frame_size":[192,192],"frames":4,"fps":6},
  "move":{"file":"move.png","frame_size":[192,192],"frames":8,"fps":10},
  "attack":{"file":"attack.png","frame_size":[192,192],"frames":4,"fps":10},
  "special":{"file":"special.png","frame_size":[192,192],"frames":4,"fps":8},
  "hit":{"file":"hit.png","frame_size":[192,192],"frames":2,"fps":12}
 },
 "provenance":"res://design/baimen-enemies-20261028/characters/E01/export-manifest.json"
}
All clips horizontal, same frame size+anchor and single body calibration across poses.
Frame counts/canvas size can vary per identity; renderer does not assume 192 or 4/8.
status final is necessary but not sufficient for asset acceptance. Producer keeps source PNG,
Aseprite, prompts/hash manifest. Final audit fails every missing required slot/clip/portrait.
Optional explicit "reuse_visual_id":"E01" for L00/D01 only; no silent identity collapse.
D03/D05 have their own object sprites; clips can use repeated frames if behavior does not move.
Runtime reads enemy.state / attack / action_serial, uses director.elapsed battle clock (pause exact).
No death sheet required: true death uses .30s dissolve; cancellation removes cleanly without hit/reward.
New release VFX remain separately authored; threat boundaries always actual simulation geometry.

Optional per-clip windup_frame (default0) and contact_frame (default1), zero-based.
Tell freezes preparation frame; enemy_release starts at contact_frame; remaining action frames finish
on battle clock then recovery returns to idle/move. Active charge may hold final contact pose while
runtime moves body. Metadata may override frame count, fps and anchors. Root initial plan is20 source
frames per identity(4 each), E192/body80, heavy256/body128, Boss384/512 body192-240; measurements govern.
42 manifest visual slots =39 principal + D01 reusable manifest + D03/D05 original objects.
L00 catalog uses visual_id E01 directly; D01 manifest reuse_visual_id E01. True new suites41.

Optional faces_left:boolean(default false) on measurements→runtime manifest records source-facing orientation. Use this if source frames face left; renderer mirrors against actual locked aim.

Action clip routing: top-level action_clips maps actual action_id→clip key (e.g. swipe:attack, charge:special, slam:slam). The renderer uses same lookup during tell and release; major is never an animation selector. Default melee/shot/fan/hook/slam→attack; charge/pot/pulse/summon/anchor/command/heal/collaboration→special. Clips can include extra named clips beyond five required baseline ones; exporter and audit process all clips. B15/B18 may have24+ poses.

Optional two-beat routing uses `action_clips` keys such as `slam@0` and `slam@1`.
The suffix is the locked descriptor's `attack_step % 2`; tell and release resolve the
same key before falling back to the plain `action_id`. This is an animation route,
not a second attack scheduler.

Non-targetable collaboration bodies read their parent's real tell/state/aim. The
parent's `enemy_release` also reaches its living presentation children. M03_WAR maps
`collaboration` to `attack`; M04_WAR maps it to `special`. Children remain non-targetable
and do not acquire damage, rewards or independent AI from this adapter.

`enemy_hazard_release` carries the final locked `geometry` at the actual delayed hit,
with phase `active`. Raster impact effects use that event rather than predicting the
end of a warning in wall time. Source cancellation emits no impact and cancels owned
presentation effects; battle end clears all effects. Persistent hazard drawings read
the simulation arrays, so removing an area removes its visual immediately.

Codex and gallery fitting use the union of actual alpha bounds over every frame of
every clip, including extra clips. A single scale is kept across all poses of one
codex identity; gallery pages share one scale across their identities. No pose is
individually stretched. Battle bodies keep the catalog world-height calibration.

`validate_final()` is a source-production test only: it checks each per-ID provenance
record's output hashes, including editable Aseprite files. Normal gameplay never calls
it. Runtime ships the resource manifests and PNG imports; `design/` and editable files
are excluded from the PCK. The root manifest is a summary, not this per-ID hash API.
