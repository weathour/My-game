# Roadmap

This roadmap tracks project direction, not a promise of release dates.

## Now: stabilize prototype foundation

- Keep the current survivor-like combat loop playable.
- Stabilize save/load and continue-game behavior.
- Keep the local achievement system independent from Steam APIs.
- Maintain display settings: window/fullscreen and 16:9 window sizing.
- Keep docs synchronized with implemented systems.
- Protect the current UI modal/card/hover components with smoke tests.

## Next: content and systems depth

- Rebuild elite reward identity.
- Deepen build/card choices beyond the current 三相荡阵 / 万向锋路 / 血盾回路 / 三相终式 set so roles feel less interchangeable.
- Improve Boss pressure, readability, and phase identity.
- Add clearer achievement categories once progression goals settle.
- Add more automated checks for settings, achievements, save serialization, hero-trait persistence, and theme unlock persistence.

## Later: release preparation

- Replace placeholder/non-commercial media.
- Finalize asset licensing and third-party notices.
- Add export presets and release checklist automation.
- Integrate GodotSteam behind `AchievementService` adapter.
- Add Steam achievement API names matching local achievement IDs.
