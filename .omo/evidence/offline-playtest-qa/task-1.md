# Task 1 evidence — 20002-mage Avatar/MotionPlayer miss catalog

Plan: `.omo/plans/offline-playtest-qa.md` todo 1. Commit: N (evidence only under `.omo/`).

## Commands / paths read

| Path | What |
| --- | --- |
| `.omo/plans/offline-playtest-qa.md` todo 1 (lines 122-129) | Acceptance: every owner-reported name one row; youli = mismatch; lilimu `0` = code-bug |
| `.omo/drafts/offline-playtest-qa.md` Findings (lines 57-78) | GAP-1 / GAP-2 cited chains |
| `AxmolFighter-Client/Content/mugen/motion/effect/tx_youli_zidongsheji.motion` | JSON names `{0,2,4,6,8,10,12,14,16,JN1}` |
| `AxmolFighter-Client/Content/mugen/motion/hero/rw_newzhujue_lilimu.motion` | starts `101`; has `10100`; no `"name": "0"` |
| `AxmolFighter-Client/Source/mugen/avatar/MissingAvatarMotion.cpp:16-28` | once-log `Avatar: motion '{}' not found in '{}'` |
| `AxmolFighter-Client/Source/mugen/avatar/MotionPlayer.cpp:56-60` | `MotionPlayer::play: motion not found '{}' in '{}'` |
| `AxmolFighter-Client/Source/mugen/avatar/AvatarPaths.cpp:22-56` | spine → motion path |
| `AxmolFighter-Client/Source/mugen/sim/effect/Effect.cpp:190` | effect `motionName` from `ActionEffectConfig.action` |
| `AxmolFighter-Config/table/res_spine.lua:380-385` | id 101 → `tx_youli_zidongsheji.skel` |
| `AxmolFighter-Config/table/action_effect.lua:4521/:4543` | id 210 `action=18` |
| `AxmolFighter-Config/table/action_effect.lua:18519/:18541` | id 20120 `action=30` |
| `AxmolFighter-Config/table/action_effect.lua:18761/:18783` | id 20160 `action=38` |
| `AxmolFighter-Config/table/action_effect.lua:303343/:303365` | id 951210 `action=74` |
| `AxmolFighter-Config/table/action_effect.lua:289/:311` | id 8 `action="siwang"` |
| `AxmolFighter-Config/table/action.lua:210238/:210280` | id 900000 `action=0` |
| `AxmolFighter-Client/Source/mugen/sim/spawn/RoleSpawn.cpp:200-201` | `skill::loadSkill` no loadout |
| `AxmolFighter-Client/Source/mugen/sim/skill/SkillLoad.cpp:108-110` | `monsterLoadout(aiId)` |
| `AxmolFighter-Config/table/ai.lua:364,434-452` | id 3 skillIds six × 82010 |
| `AxmolFighter-Config/table/skill.lua:15660-15676` | 82010 actionIds `{900000,900010,900020}` |
| `AxmolFighter-Config/table/role.lua:940-942,1007,1030` | role 104 `aiId={3}` `resSpineId=88104` |
| `AxmolFighter-Client/Source/MainScene.cpp:116-117` | `--offline-role=mage` → 104 |
| `AxmolFighter-Client/Source/ui/views/GameView.cpp:43` | U → AttackA |

## Catalog file

`.omo/evidence/offline-playtest-qa/motion-miss-catalog.md`

Owner-reported names each have one row:

- youli `18,30,38,74,siwang` → verdict **mismatch** (file exists; names `{0,2,4,6,8,10,12,14,16,JN1}`)
- lilimu `0` (MotionPlayer + Avatar) → verdict **code-bug** (monster kit / action 900000 `action=0`); closed by todo 5, not by adding a `0` clip

Once-log from mugen-rewrite todo 45 still holds; catalog does not claim a per-frame flood.

## Verification

Happy path (acceptance QA):

```
rg "siwang" .omo/evidence/offline-playtest-qa/motion-miss-catalog.md
```

Expect: a **mismatch** row naming `tx_youli_zidongsheji.motion`.

Failure: a youli row claiming `missing-file` is a defect.

Product git (must be empty for Client/Config/Tools from this task):

```
git diff --stat
```

Expect: no `AxmolFighter-Client/` / `AxmolFighter-Config/` / `AxmolFighter-Tools/` product files. Evidence only under `.omo/`.

Not done this task: generate `.motion`, pack `avatar.bin`, remap ids, edit product C++/Lua, mark mugen-rewrite F3, root-repo commit.
