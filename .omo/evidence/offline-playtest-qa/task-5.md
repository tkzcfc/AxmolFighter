# Task 5 — offline spawnPlayer 101-104 uses playerLoadout from profession tree

Plan: `.omo/plans/offline-playtest-qa.md` todo 5. Commit: Y | Client `feat(sim): load offline heroes from profession skill tree`.

## Spawn gate (cited)

`RoleSpawn.cpp:200-207` — non-Town only:

- `toCharacterClass(params.roleId) != kUnknown` (role ids **101–104**) → `loadSkill(world, entity, playerLoadout(offlineKit(occupation)))` **before** RoleTree `definitionKey` / `enter`.
- else → existing `loadSkill(world, entity)` (`monsterLoadout(aiId)`).
- Gate is **not** `playerSlot` and **not** `roleType==1`. `ScenarioHarness.cpp:72-76` `roleId=0` + `playerSlot=0` stays on monster kit (`role.lua` id 0 is `roleType=1`).

`offlineKit(CharacterClass)` (`Skill.h:44`, `SkillLoadout.cpp:87-175`):

- professionType in `{1,2,3,4}` matching occupation; prefer `treeType==1`.
- no tree (fighter / occupation 3): `MG_LOG_W` English `No profession skill tree for occupation {}`, empty vector — never `monsterLoadout`, never invent leaves.
- leafIds[1..10] → Attack/Sprint/Dodge/Crazy/A/B/C/EA/EB/SUA; leftover + leafBuffId → SUB/SUC/Break/Anger; leafRubId with rock → SA/SB/SC else SAP/SBP/SCP.
- Mage 40110 → skill **980120** has no `skill_rock` row → SAP (`"M"`), not dropped.

## Tests (`TestsHeadless/tests/PlayerKitTest.cpp`)

Parent re-ran `pwsh TestsHeadless/run_headless_tests.ps1 -Filter "*PlayerKit*"`:

```
[W] No profession skill tree for occupation 3
[doctest] test cases:  6 |  6 passed | 0 failed | 254 skipped
[doctest] assertions: 42 | 42 passed | 0 failed |
[doctest] Status: SUCCESS!
```

| case | result |
| --- | --- |
| mage 104 slot `"A"` configId **980000** not 82010 | pass |
| `eventSlot(CTR_ATKA)=="A"` and action **10100** | pass |
| role 0 + playerSlot 0 matches `monsterLoadout(aiId)` | pass |
| monster 261 + isAi keeps AI skill ids + AiAgent | pass |
| `offlineKit(kFighter)` empty | pass (warning logged) |
| swordman Attack 920000; ranger Attack 930030 (leaf 20010) | pass |

Worker G1 full: 260 cases / 246087 assertions / 0 failed (includes *Determinism* + *PlayerKit*). G2 `check_rules.ps1` EXIT=0 (parent re-ran).

## Autotest (parent-executed)

- cwd: `AxmolFighter-Client/Content`
- exe: `build/bin/AxmolFighter-Client/RelWithDebInfo/AxmolFighter-Client.exe`
- flags: `--offline-room=20002 --offline-role=mage --autotest-frames=300`
- EXIT=0
- `world hash 300 8c9e2797208ff29b` (changed vs pre-kit `bc37c5a5d6618b1e` as expected)
- stderr/stdout: **no** `MotionPlayer::play: motion not found '0'` and **no** lilimu `'0'`
- Youli once-log still fires (catalog): `38`, `30`, `1004`, `18`, `52`, `50`, `54` on `tx_youli_zidongsheji.motion` — once each, not a flood. `1004`/`52`/`50`/`54` are extra mismatch names vs the original owner list.

## Files (Client, uncommitted until git-master path-limited commit)

- `Source/mugen/sim/skill/Skill.h`
- `Source/mugen/sim/skill/SkillLoadout.cpp`
- `Source/mugen/sim/spawn/RoleSpawn.cpp`
- `TestsHeadless/tests/PlayerKitTest.cpp`

Must NOT: generate `.motion`, pack `avatar.bin`, add a `0` clip, mark mugen-rewrite F3, push, fold 200+ unrelated staged Client paths.
