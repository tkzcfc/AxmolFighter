# F2 — Code quality review

Plan: `.omo/plans/offline-playtest-qa.md` Final Verification Wave F2.

**VERDICT: APPROVE**

## Kit source of truth

Kit source is tree → leaf → `skill_attack` via `offlineKit` / `offlineKitRows` / `playerLoadout`. `SkillPool` is the loaded runtime pool, not the kit source. `AttackRole` is not used to pick the offline hero kit. Spawn gate (`RoleSpawn.cpp:200-207`): non-Town and `toCharacterClass(roleId) != kUnknown` (101–104) → `playerLoadout(offlineKit)`; else `loadSkill` monster path. Not keyed on `playerSlot` or `roleType==1`.

## Grep / rules

| Check | Result |
| --- | --- |
| Client `Source/**` 黑月 / heiyue / `E:\` | 0 matches |
| `sim/` `unordered_map` / `unordered_set` | 0 matches |
| Generated `.motion` / `pack-avatar` in this plan | none |
| DebugDraw presentation-only | `WorldPresenter.cpp:180-183` `if (!m_enabled) return`; `m_enabled=false` default |
| Fighter empty kit | `offlineKit` logs `No profession skill tree for occupation {}`; panel `kNoProfessionTree` |
| G2 `check_rules.ps1` | EXIT=0 |

## Panel / Cast

`BattleDebugPanel.cpp` lists `key slot leaf skill pool` after F8 checkbox. Overflow Cast calls `skill::presetSkill(world, player, row.poolSlot)` only. No new keyboard bindings. No FairyGUI skill bar.
