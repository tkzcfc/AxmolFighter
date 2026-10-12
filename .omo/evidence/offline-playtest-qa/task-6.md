# Task 6 — Battle Debug lists bound kit and Cast overflow leaves

Plan: `.omo/plans/offline-playtest-qa.md` todo 6. Commit: Y | Client `feat(ui): list offline skill kit in battle debug`.

## Panel (cited)

`BattleDebugPanel.cpp` — after `ImGui::Checkbox("Collision boxes (F8)", ...)`:

- Resolve local player via `PlayerSlots`: slot 0 if present, else first mapped entity.
- Occupation from `toCharacterClass(identity.roleId)`; rows from `skill::offlineKitRows(occupation)`.
- Empty / no player: English `no profession tree` (`kNoProfessionTree`). Never monster skill 82010.
- Columns: `key  slot  leaf  skill  pool`.
- Overflow (`!hasControlKey` and non-empty `poolSlot`): ImGui `Cast` → `skill::presetSkill(world, player, row.poolSlot)`. No new keyboard bindings. F8 stays out of `m_slotMap`.

Helper `offlineKitRows` / `OfflineKitRow` in `Skill.h` + `SkillLoadout.cpp` (headless-testable; panel calls it).

Mage leftover mapping: Attack=U/`A`, Sprint=Y/`Y`, … SUB=9/`J`, SAP pool `M` (980120, no rock). Anger poolSlot is `P` so SAP keeps `M`. Unused T/H/Q assigned to SAP/SBP/SCP if free.

## Tests (`TestsHeadless/tests/OfflineKitDumpTest.cpp`)

Parent `pwsh TestsHeadless/run_headless_tests.ps1 -Filter "*OfflineKitDump*"`:

```
[doctest] test cases:  2 |  2 passed | 0 failed | 260 skipped
[doctest] assertions: 13 | 13 passed | 0 failed |
[doctest] Status: SUCCESS!
```

| case | result |
| --- | --- |
| mage dump leaf **40010** / skill **980000** / key **U** / Attack / pool `A` / hasControlKey | pass |
| fighter dump empty; `kNoProfessionTree` == `no profession tree`; no skill 82010 | pass |

G1 full: 262 cases / 246100 assertions / 0 failed (includes *Determinism*, *PlayerKit*, *OfflineKitDump*). G2 `check_rules.ps1` EXIT=0. G3 `cmake --build build --config RelWithDebInfo --target AxmolFighter-Client` EXIT=0 (compiled `BattleDebugPanel.cpp`, `SkillLoadout.cpp`).

## Files (Client, path-limited)

- `Source/mugen/sim/skill/Skill.h`
- `Source/mugen/sim/skill/SkillLoadout.cpp`
- `Source/ui/battle/BattleDebugPanel.cpp`
- `TestsHeadless/tests/OfflineKitDumpTest.cpp`

Must NOT: FairyGUI bar; new keys; change todo 5 slot map / RoleSpawn / config.bin; mark mugen-rewrite F3; push; fold 200+ unrelated staged Client paths.
