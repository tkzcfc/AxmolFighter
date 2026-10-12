# offline-playtest-qa - Work Plan

## TL;DR (For humans)

**Who this is for and what changes for them:** 战斗负责人离线进房后能按键放出职业树上的真实技能，不再触发松手的占位动作；每条剩下的动画缺名警告都能在目录里看到是配置与骨架不一致还是缺文件；碰撞框有开关，默认关闭。

**What you'll get:** 一份动画缺名目录（本轮不改动画、不改动作号）；技能树与叶子表进配置包；四个离线英雄按职业树装配键盘槽；调试面板可看槽位并点击施放溢出技能；攻击/受击/半径框可用快捷键打开。

**Why this approach:** 先把缺名定性，避免凭空造动画。玩家技能走正规养成链（树→叶子→技能），用离线调试槽位表把叶子挂到已有键盘，不引进芯片和推荐表。碰撞覆盖复用已有调试绘制，只补受击框和开关。

**What it will NOT do:** 不生成动画文件、不打动画包、不猜动画名、不改动作号。不把旧改写计划的手玩确认项标完成。不改怪物技能装配、不动输入走路、不推仓。

**Effort:** Large
**Risk:** Medium - 配置模式变化且玩家装配会改变离线房间的世界哈希；拳师职业在源表里没有对应的基础树。
**Decisions to sanity-check:** 缺名本轮只做目录；拳师若导入后仍无职业树则空槽而不借怪物套；擦招若无指令表行则挂到按键槽而不丢。

Your next move: 在工人会话里执行本计划，或先跑高精度评审。Full execution detail follows below.

---

> TL;DR (machine): Large/Medium; catalog misses; import+pack skill_tree/skill_leaf; spawnPlayer 101-104 playerLoadout debug map; DebugDraw damage+F8; F3 mugen-rewrite stays [~].

## Scope
### Affected user and ideal state
**Affected user:** fangcheng（战斗负责人）今天用 RelWithDebInfo 离线进 `20002` 法师，U 键走怪物占位技能，优离特效缺名警告仍在，看不到受击框。做完后他能按键放完职业树技能、按目录理解剩余缺名、用开关看碰撞框。下游执行者按目录修，不凭空造 clip。

| Row | Statement | Reason |
| --- | --- | --- |
| IS-1 | Offline `--offline-room=20002 --offline-role=mage` does not flood unknown motion names; each remaining `(file, name)` miss is a catalog row (config field vs skeleton vs missing file) | Owner asked for diagnosis before any fix |
| IS-2 | Pressing U on mage plays the hero skeleton's real attack clip, not motion `0` on `rw_newzhujue_lilimu.motion` | Current U path is a placeholder skill |
| IS-3 | Every skill the local player's profession tree owns is bound to a keyboard slot or listed as a debug-panel Cast | Requested for skill-feel QA |
| IS-4 | Collision regions (attack, hurt, radius) are visible in battle, behind a switch that defaults off | Requested; must not pollute normal play |
| IS-5 | mugen-rewrite F3 stays `[~]` until fangcheng says okay on M-FINAL.md | Existing F3 contract |
| GAP-1 | `tx_youli_zidongsheji.motion` lists `{0,2,4,6,8,10,12,14,16,JN1}`; config `ActionEffect.action` asks for `18/30/38/74/siwang` | Asset/config name mismatch, not a missing `.motion` file |
| GAP-2 | U → slot A → AI-3 skill `82010` → action `900000` → `action=0`; lilimu.motion has `101+`, no `0` | Offline player uses `monsterLoadout(aiId)` |
| GAP-3 | `playerLoadout()` exists but `spawnPlayer` never calls it; Config has no `skill_tree`/`skill_leaf` | No player kit source in packed tables |
| GAP-4 | `DebugDraw` exists, `m_enabled=false`, not wired to UI; draws radius+attack+moveRange only, skips `ColliderState.damage` | Toggle requested |
| GAP-5 | skill_tree has profession_type `{1,2,4,11,12,21,22,41,42}` and **no** `3`; fighter role 103 has no base tree | Must not silently reuse monster kit or invent leaves |

### Must have
- Evidence catalog at `.omo/evidence/offline-playtest-qa/motion-miss-catalog.md` covering every distinct Avatar once-log name from 20002 mage plus lilimu `0` / `MotionPlayer::play` `0`. Columns: log line, entity kind, config table+id, field value, motion file, names present, verdict `{mismatch, missing-file, code-bug}`.
- Import `skill_tree` and `skill_leaf` through `TableConvert.lua` KIND_SPECS (same flatten/camelCase/default-metatable path as `skill_rock`), add both to `COMBAT_KINDS`, emit `AxmolFighter-Config/table/skill_tree.lua` and `skill_leaf.lua`.
- C++ `SkillTreeConfig` / `SkillLeafConfig` in `SkillTables.h` matching **every** imported Lua field both ways; register `MG_CONFIG_TABLES` with `KeyById`; add `MG_CONFIG_REFS` `skill_leaf.skillId → skill`, `skill_tree.leafIds/leafRubId/leafBuffId → skill_leaf`. Pack `config.bin`. Update `table-kind-mapping.md`.
- `spawnRole` loads `playerLoadout(offlineKit(occupation))` **only** when `toCharacterClass(params.roleId)` is `kSwordman`/`kRanger`/`kFighter`/`kMage` (role ids **101–104**) and `world.setup().mode != Town`. Do **not** key off `playerSlot` alone or `roleType == 1`: `TestsHeadless/support/ScenarioHarness.cpp:72-76` spawns `roleId = 0` with `playerSlot = 0`, and `role.lua` id 0 is `roleType = 1` (`role.lua:70,87`). That dummy must keep `monsterLoadout(aiId)`. Occupations 1/2/4 use the unique `treeType == 1` (or the only) row whose `professionType` matches. Occupation 3: if no packed row has `professionType == 3`, English warning, **empty** player kit (not AI-3), debug panel shows `no profession tree`.
- Debug slot map (same order for trees 1/2/4; leaf_ids UI order):

  | leaf source | EnumSkillSlot | GameView key | ControlKey |
  | --- | --- | --- | --- |
  | leaf_ids[1] | Attack | U | AttackA |
  | leaf_ids[2] | Sprint | Y | AttackM |
  | leaf_ids[3] | Dodge | L | AttackF |
  | leaf_ids[4] | Crazy | K | AttackE |
  | leaf_ids[5] | A | I | AttackB |
  | leaf_ids[6] | B | O | AttackC |
  | leaf_ids[7] | C | J | AttackD |
  | leaf_ids[8] | EA | M | AttackG |
  | leaf_ids[9] | EB | N | AttackH |
  | leaf_ids[10] | SUA | 8 | AttackI |
  | leftover leaf_ids then leaf_buff_id | SUB, SUC, Break, Anger, then remaining Attack* | 9 / 0 / ; / T / H / Q | AttackJ… |
  | leaf_rub_id[i] with matching `SkillRockConfig.skillId` | SA/SB/SC | joy via `commandIndex` | CTR_JOY* |
  | leaf_rub_id[i] **without** rock row | SAP/SBP/SCP | M is already EA; use T/H/Q if those leftover slots are free, else Debug Cast only | AttackN/O/Q |

  `PlayerSkill.m_baseId` is `skill_leaf.skillId`. `m_rockId` is the rock row id when `skillId` matches, else `-1`. `m_crazy` false. Skip leaf ids `<= 0`. Battle Debug lists `key / EnumSkillSlot / leaf id / skill_attack id`. Overflow Cast calls `skill::presetSkill(world, player, slotName)` on the local player from `PlayerSlots`.
- DebugDraw: cyan `collider.damage` rects using the same 2D AABB as `collider.attack` (WorldBox x/z, **not** `DamageBox::drawDebug`). Keep yellow radius, red attack, green moveRange. ImGui checkbox on Battle Debug + F8 in `GameView::onKeyPressed` (handle F8 before `m_slotMap`; F8 is not a ControlKey). Default off. Presentation-only: toggling must not change `world.hash()`.
- Headless tests for kit + DebugDraw hash invariance. G1/G2 green. G4 after table/schema change. 20002 mage autotest EXIT=0; record the **new** hash pair (kit change is expected).
- If a todo edits dirty `LocalBattleMode.cpp`, keep the existing `setFollowEntity(player)` line; do not revert it. Do not put it in a catalog-only or Tools/Config-only commit.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- Do not mark mugen-rewrite F3 `[x]` and do not edit `.omo/plans/mugen-rewrite.md` checkboxes.
- Do not generate `.motion`, pack `avatar.bin`, invent animation names, or remap `action` / `action_effect` ids.
- Do not import `skill_chip`, `skill_recommend`, or a FairyGUI skill bar.
- Do not load job-change trees (`professionType` outside `{1,2,3,4}`).
- Do not change `monsterLoadout`. Do not switch `spawnRole` to the player kit except role ids 101–104 (`toCharacterClass` not unknown). `ScenarioHarness` `roleId = 0` with `playerSlot = 0` stays on `monsterLoadout`.
- Do not invent a fighter tree or copy another profession's leaves onto role 103.
- Do not add a `--debug-draw` / `--collision-debug` CLI flag; F8 + ImGui is enough.
- Do not edit Server / Editor / UI-fgui / heiyue product sources; no push; no git worktree; no root-repo submodule pointer commit.
- Do not retune combat numbers or locomotion (todo 46 stays).
- Do not treat RelWithDebInfo as mugen-rewrite todo-42 evidence (NDEBUG).
- Do not name the reference product, its pinyin/English product name, or `E:\` paths in `AxmolFighter-Client/Source/**` or `AxmolFighter-Server/**` comments or logs. Logs/errors English. Comments Chinese OK.
- Do not mix SkillPool/AttackRole as the kit **source of truth**; kit source is tree→leaf→skill_attack, then existing `playerLoadout`.
- Do not add `std::unordered_map`/`unordered_set` to serialized sim state; do not use float in `core/`/`sim/` except render converters.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: tests-after + doctest in `AxmolFighter-Client/TestsHeadless`.
- Gates (same names as mugen-rewrite, scoped to this plan):
  - G1 `pwsh AxmolFighter-Client/TestsHeadless/run_headless_tests.ps1` exit 0.
  - G2 `pwsh AxmolFighter-Client/TestsHeadless/check_rules.ps1` exit 0.
  - G3 client `axmol build -p win32` exit 0 when Client sources change; re-configure if files were added.
  - G4 `pwsh AxmolFighter-Tools/config_converter/run_config_converter.ps1 --skip-configure` exit 0 after table/schema change.
  - Autotest: cwd `AxmolFighter-Client/Content`, RelWithDebInfo exe `--offline-room=20002 --offline-role=mage --autotest-frames=300` exit 0 and prints `world hash`. Record hash in evidence (may differ from `bc37c5a5d6618b1e`).
- Evidence: `.omo/evidence/offline-playtest-qa/task-<N>.md` plus catalog/autotest logs in the same directory.

## Execution strategy
### Ground rules
- **Work in place.** Submodules. Do **not** use git worktree, `--worktree`, or `--make-pr`. Edits go in current checkout: Client `mugen-rewrite`, Config, Tools, Content as needed.
- Shared registries (`ConfigTables.h`, `ConfigRefs.h`, `SkillTables.h`) are single-writer per todo; do not parallel-edit them.
- Notepad: `.omo/notepads/offline-playtest-qa/{learnings,decisions,issues,problems}.md`. Create if missing. Append after each todo; never overwrite.
- Do not bulk-scan `heiyue/src`. Read `Reference/heiyue-*.md` then only cited Lua lines.
- `deep-low` monthly quota is exhausted; do not route todos to `deep-low` and do not resume `ses_ed9bcab61ffeINHkgnbQdAR3Jq`.

### Parallel execution waves
- **W1 (parallel):** 1 catalog ∥ 2 import Lua ∥ 3 DebugDraw toggle. No shared product files.
- **W2:** 4 structs + register + pack. Blocked by 2.
- **W3:** 5 spawnPlayer kit. Blocked by 4.
- **W4:** 6 debug panel listing + Cast. Blocked by 5. Shares `BattleDebugPanel.cpp` with 3 — wait for 3.
- Then F1–F4 in parallel.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | — | F4 IS-1 | 2, 3 |
| 2 | — | 4 | 1, 3 |
| 3 | — | 6, F4 IS-4 | 1, 2 |
| 4 | 2 | 5 | — |
| 5 | 4 | 6, F4 IS-2/IS-3 | — |
| 6 | 3, 5 | F4 IS-3 | — |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [x] 1. Catalog every 20002-mage Avatar/MotionPlayer miss (youli names + lilimu `0`)
  What to do: Write `.omo/evidence/offline-playtest-qa/motion-miss-catalog.md`. For each distinct once-log name the owner saw (`18,30,38,74,siwang` on `tx_youli_zidongsheji.motion`) plus `MotionPlayer::play` / Avatar `'0'` on `rw_newzhujue_lilimu.motion`, fill: log line, entity kind (effect vs hero), config table+id+field, field value, motion file path, JSON `name` list present, verdict. Youli cluster verdict is **mismatch** (file exists; names `{0,2,4,6,8,10,12,14,16,JN1}`). Lilimu `0` verdict is **code-bug** (spawn uses monster kit / action 900000 `action=0`); closed by todo 5, not by adding a `0` clip. Optionally grep `action_effect.lua` for other `resSpine` 101 actions not in that name set and add rows. Must NOT do: generate `.motion`, pack `avatar.bin`, remap ids, edit product C++/Lua, mark mugen-rewrite F3.
  Closes: GAP-1; proves IS-1 diagnosis half (catalog exists even while misses still log once).
  Parallelization: Wave 1 | Blocked by: none | Blocks: F4 IS-1 | Can parallelize with: 2, 3
  References: `Content/mugen/motion/effect/tx_youli_zidongsheji.motion`; `MissingAvatarMotion.cpp:16-28`; `MotionPlayer.cpp:56-60`; `action_effect.lua` id 20160 `action=38` (~18761); `action.lua` id 900000 `action=0` (~210238); `RoleSpawn.cpp:200-201`; `SkillLoad.cpp:108-110`; `ai.lua` id 3 skill 82010; draft `.omo/drafts/offline-playtest-qa.md` Findings.
  Acceptance criteria: catalog file exists; every owner-reported name has one row; youli rows say mismatch not missing-file; lilimu `0` says code-bug; no product files in `git diff` for Client/Config/Tools.
  QA scenarios: happy: `rg "siwang" .omo/evidence/offline-playtest-qa/motion-miss-catalog.md` hits a mismatch row naming `tx_youli_zidongsheji.motion`. Failure: a row that claims missing-file for youli is a defect. Evidence: `.omo/evidence/offline-playtest-qa/task-1.md`.
  Commit: N | evidence-only under `.omo/`
  Recommended task executor category: writing (evidence markdown, no product code)

- [x] 2. Import `skill_tree` and `skill_leaf` into Config Lua
  What to do: Add KIND_SPECS entries in `AxmolFighter-Tools/config_converter/script/migrate/import/TableConvert.lua` next to `skill_rock` (~171): `skill_tree` source `src/imports/table/skill_tree.lua` out `AxmolFighter-Config/table/skill_tree.lua`; `skill_leaf` source `src/imports/table/skill_leaf.lua` out `AxmolFighter-Config/table/skill_leaf.lua`. Expand `__default_table` metatable (existing convert path). Force sparse `id` from the Lua key where the row omits it (tree id 1 has no `id` field in the sparse row; leaf `0` exists). Snake→camel. Append `'skill_tree'` and `'skill_leaf'` to `COMBAT_KINDS` in `run_table_convert.lua` (~39-60). From `AxmolFighter-Tools/config_converter/script` run: `lua migrate/import/run_table_convert.lua --src D:/work/AxmolFighter/heiyue --axmol D:/work/AxmolFighter --kinds skill_tree,skill_leaf` (or `--combat` if that is the durable way after the list change). Confirm output arrays contain tree ids 1,2,4 and mage `leafIds` `40010..40080,40100,40120`, `leafRubId` `40110`, `leafBuffId` `40090`, `professionType` 4. Tree id 1 must have `id=1` and `professionType=1` after default expansion. Must NOT do: import chip/recommend; edit C++ structs (todo 4); pack `config.bin` (todo 4); edit heiyue sources; invent fighter tree id 3.
  Closes: GAP-3 (source tables present).
  Parallelization: Wave 1 | Blocked by: none | Blocks: 4 | Can parallelize with: 1, 3
  References: `TableConvert.lua:171-180`; `run_table_convert.lua:39-60,194-196`; `heiyue/src/imports/table/skill_tree.lua:13-73,178-213`; `skill_leaf.lua:3251-3283` and `[40010]` ~1347; `config_converter/README.md` import command; Config `AGENTS.md` adding-a-table (packer is todo 4).
  Acceptance criteria: both Config lua files exist and `return` an array; `rg "professionType = 4" AxmolFighter-Config/table/skill_tree.lua` hits; `rg "id = 40010" AxmolFighter-Config/table/skill_leaf.lua` hits `skillId = 980000` (camel); tree id 1 row has numeric `id = 1`; KIND_SPECS and COMBAT_KINDS updated; `lua` convert exit 0.
  QA scenarios: happy: convert `--kinds skill_tree,skill_leaf` exit 0 and files non-empty. Failure: convert of an unknown kind still errors (`unknown kind`). Evidence: `.omo/evidence/offline-playtest-qa/task-2.md` with command output.
  Commit: Y | Tools: `feat(config): import skill_tree and skill_leaf KIND_SPECS` ; Config: `feat(table): add flattened skill_tree and skill_leaf`
  Recommended task executor category: unspecified-high (import pipeline + two new tables, known pattern)

- [x] 3. Wire DebugDraw damage boxes + ImGui checkbox + F8, default off
  What to do: In `DebugDraw::present` (`WorldPresenter.cpp:177-196`) after red `collider.attack` rects, draw `collider.damage` with `ax::Color4F::CYAN` using the same center+pos/size formula (x/z plane). Do **not** call `DamageBox::drawDebug`. Keep yellow radius and green moveRanges. Default `m_enabled=false`. Add `bool enabled() const`. Battle Debug: `ImGui::Checkbox` bound through `LocalBattleMode` to `m_presenter->presenter.debugDraw().setEnabled`. F8 in `GameView::onKeyPressed`: if code is `KEY_F8`, toggle (`pressed==true` only) via a new `LocalBattleMode::toggleCollisionDebug()`; do not insert F8 into `m_slotMap`. Isolate dirty `setFollowEntity(player)` if this todo touches `LocalBattleMode.cpp` — keep the line. Must NOT do: change sim/collision; draw in core/sim; default on; hash-affecting world writes; FairyGUI.
  Closes: GAP-4.
  Parallelization: Wave 1 | Blocked by: none | Blocks: 6 (shared BattleDebugPanel) | Can parallelize with: 1, 2
  References: `WorldPresenter.cpp:171-196`; `WorldPresenter.h:94-115`; `ColliderState` `RoleComponents.h:214-225`; `CollisionSystem.cpp:20-40`; `RoleUpdate.cpp:83-92` `transformBox`; `BattleDebugPanel.cpp:7-24`; `GameView.cpp:88-108,146-149`; `LocalBattleMode.cpp:56-69,135-154`; `DamageBox.h:17-67` unused helper.
  Acceptance criteria: G2 exit 0; G3 client build exit 0; G1 still green (no sim change). Headless test: two worlds same setup/ticks, toggle cannot run headless — instead a unit that constructs nothing in sim. For hash: document that DebugDraw is render-only (`present` reads colliders). Autotest 20002 mage 300 frames EXIT=0 (hash may still be old until todo 5). Checkbox compiles; F8 not mapped as Attack*.
  QA scenarios: happy: code review shows cyan damage loop inside `if (m_enabled)` and F8 toggle does not call `setInput`. Failure: `DebugDraw::present` with `m_enabled==false` still `drawRect` for damage (must `return`/`skip`). Evidence: `.omo/evidence/offline-playtest-qa/task-3.md` plus a RelWithDebInfo screenshot or log line only if an agent-owned display exists; otherwise cite the exact `present` lines.
  Commit: Y | Client: `feat(render): draw hurt boxes and toggle collision debug`
  Recommended task executor category: visual-engineering (overlay + ImGui + hotkey)

- [x] 4. C++ SkillTreeConfig/SkillLeafConfig, register, pack config.bin
  What to do: After todo 2 Lua exists, run `config_converter scaffold <ConfigDir> skill_tree` and `skill_leaf` to list fields. Write full structs in `Source/mugen/conf/tables/SkillTables.h` matching Lua **both ways** (including UI-only: `professionBackground`, `ui`, `nameId`, `descId`, `treeType`, `leafRubPlace`, leaf `icon`/`chipIds`/`videoId`/upgrade fields, `Fixed` for `skillDamageFactor`). Register in `ConfigTables.h` `MG_CONFIG_TABLES` as `X(skill_tree, SkillTreeConfig, KeyById)` and `X(skill_leaf, SkillLeafConfig, KeyById)` plus the header comments. Forward-declare if needed. `ConfigRefs.h`: `X(skill_leaf, skillId, skill)` `X(skill_tree, leafIds, skill_leaf)` `X(skill_tree, leafRubId, skill_leaf)` `X(skill_tree, leafBuffId, skill_leaf)`. Do **not** ref `chipIds` (chip table not imported). Pack: `pwsh AxmolFighter-Tools/config_converter/run_config_converter.ps1 --skip-configure` exit 0; schema hash **must** change (`ConfigFormat.h` `configSchemaHash()` is `schemaHash<ConfigArchive>()`). `Replay.cpp:42` and `DeterminismTest.cpp:27` refuse `.mgrp` whose header `schemaHash` mismatches; after pack, re-record or rewrite the header of `TestsHeadless/data/replays/{copy101_room2010101,defense2071501,arena30002}.mgrp` so G1 Determinism still loads. Do this in todo 4, **before** todo 5 changes spawn — those rooms use `ScenarioHarness` `roleId=0`, so world hashes should stay the same if only the config schema header moves. Headless: `Config::instance().find<SkillTreeConfig>(4)` non-null `professionType==4` and `leafIds.size()>=10`; `find<SkillLeafConfig>(40010)->skillId==980000`. Update `config_converter/docs/table-kind-mapping.md` rows (the doc still says skill_rock pack unwired — do not rewrite unrelated stale rows except add tree/leaf). README config pipeline count if it still says 40 kinds. Must NOT do: player spawn bind (todo 5); import chip; generate motion.
  Closes: GAP-3 (packed kit source).
  Parallelization: Wave 2 | Blocked by: 2 | Blocks: 5 | Can parallelize with: none
  References: Config `AGENTS.md:22-28`; `SkillTables.h` SkillRockConfig:156-169; `ConfigTables.h:122-162`; `ConfigRefs.h:4-17`; `ConfigFormat.h` archive macros; `ReflectedConfig.h` `table<T>()`; `table-kind-mapping.md:47-49`; leaf 40010 `skill_id=980000` already in `skill.lua` id 980000; `Replay.cpp:37-44`; `DeterminismTest.cpp:23-28,55-68`; `ScenarioHarness.cpp:72-76`.
  Acceptance criteria: G4 pack exit 0; G1 including `*Determinism*` and the new `*SkillTree*` case exit 0; G2 exit 0; `find<SkillTreeConfig>(4)` works; no packer field mismatch. Failure case: omitting a Lua field fails pack (do not add converter defaults to hide it). Leaving stale `.mgrp` schemaHash fails Determinism load (`schemaHash mismatch`).
  QA scenarios: happy: pack + `mugen_tests` filter on the new case and `*Determinism*`. Failure: scaffold/packer reports missing field if struct drops `ui`. Evidence: `.omo/evidence/offline-playtest-qa/task-4.md` pack log + schema hash before/after + replay header update.
  Commit: Y | Client: `feat(conf): pack skill_tree and skill_leaf`; Content: config.bin as produced; Tools doc mapping
  Recommended task executor category: unspecified-high (schema + packer, known adding-a-table path)

- [x] 5. Offline spawnPlayer 101-104 uses playerLoadout from profession tree
  What to do: Add `std::vector<PlayerSkill> offlineKit(CharacterClass occupation)` (name can be `playerKitFromTree`) in skill loadout code. Select packed `SkillTreeConfig` where `professionType == (int)occupation` and prefer `treeType == 1` if multiple; skip `professionType` outside 1-4. If none (fighter 103 / occupation 3 today): `MG_LOG_W` English `No profession skill tree for occupation %d`, return empty vector — **never** `monsterLoadout`. Map leaves per Must-have table; `m_baseId = leaf.skillId`; find rock by scanning `table<SkillRockConfig>()` for `skillId == baseId` (mage 980120 has **no** rock row today — rub leaf uses SAP or Debug Cast, do not drop it). `spawnRole`: if `world.setup().mode != Town` and `toCharacterClass(params.roleId)` is not `kUnknown` (role ids 101–104 only), `loadSkill(world, entity, playerLoadout(offlineKit(...)))` **before** the RoleTree `definitionKey` / `enter` (current `RoleSpawn.cpp:200` is already before BT). Else existing `loadSkill(world, entity)` monster path. Do **not** key off `playerSlot` or `roleType==1`. Tests in globbed `TestsHeadless/tests`: (a) role 104 slot `"A"` `getGivenSkill` configId is **980000** not 82010; (b) U-equivalent: `eventSlot(CTR_ATKA)` is `"A"` and that skill's first `ActionConfig.action` is **10100** (exists in `rw_newzhujue_lilimu.motion` as `"name": "10100"`), not `0` / action 900000; (c) `ScenarioHarness::roomWorld` still loads monster kit for roleId 0; a spawned monster/AI still gets ai skill ids; (d) occupation fighter returns empty kit without assert; (e) trees 1 and 2 produce Attack skillIds from leaf_ids[1] (10010→920000, 20010→that leaf's skillId). G1/G2; G3 if needed; autotest 20002 mage 300 EXIT=0, record new hash. Must NOT do: change monster path; load professionType 11+; invent fighter leaves; MotionPlayer once-log (out of scope); mark mugen-rewrite F3.
  Closes: GAP-2, GAP-3, GAP-5; proves IS-2 and most of IS-3.
  Parallelization: Wave 3 | Blocked by: 4 | Blocks: 6 | Can parallelize with: none
  References: `RoleSpawn.cpp:200-222`; `SkillLoad.cpp:12-24,108-110`; `SkillLoadout.cpp:30-85` `slotMap`; `Skill.h:28-46`; `GameDef.h:138-161`; `TypeConversions.cpp:9-44`; `SkillGoldenTest.cpp:55-67`; `SkillInput.cpp:11-16`; `GameView.cpp:43-58`; `LocalBattleMode.cpp:54-57`; `ScenarioHarness.cpp:72-76`; `action.lua` id 980000 `action = 10100` (~295651); `rw_newzhujue_lilimu.motion` name `10100`; SceneFactory slot table `heiyue/src/scene/SceneFactory.lua:2-37`; `heiyue-战斗配置.md:710-728`.
  Acceptance criteria: G1 full exit 0 including `*Determinism*` and `*PlayerKit*`; `*PlayerKit*` fails if 104 Attack is still 82010; G2 0; autotest EXIT=0; stderr of autotest must **not** contain `MotionPlayer::play: motion not found '0' in` `lilimu.motion`. Once-log youli names may still appear (catalog). Fighter empty kit does not assert. Role 0 harness still has a SkillPool from AI, not an empty player kit.
  QA scenarios: happy: 104 `getGivenSkill(pool,"A")` → 980000 and action name `10100`. Failure: calling `offlineKit(kFighter)` returns empty, does not throw, does not load 82010; `roomWorld(30002)` still ticks without requiring a profession tree. Evidence: `.omo/evidence/offline-playtest-qa/task-5.md` + autotest log.
  Commit: Y | Client: `feat(sim): load offline heroes from profession skill tree`
  Recommended task executor category: unspecified-high (spawn + loadout + tests; deep-low quota exhausted)

- [x] 6. Battle Debug lists bound kit and Cast overflow leaves
  What to do: Extend `BattleDebugPanel::render` (after todo 3 checkbox) to list local player skills: key label, EnumSkillSlot name, leaf id, skill_attack id, slot string (`A`/`Y`/`F`/…). Resolve player via `PlayerSlots`. Overflow leaves (not on a ControlKey) get an ImGui `Cast` button that calls `skill::presetSkill(world, player, slot)` or `dealButtonEvent` with a documented event; do not add new keyboard bindings. If kit empty, show `no profession tree`. Must NOT do: FairyGUI skill bar; change slot map from todo 5; edit Server.
  Closes: IS-3 overflow path.
  Parallelization: Wave 4 | Blocked by: 3, 5 | Blocks: F4 | Can parallelize with: none
  References: `BattleDebugPanel.cpp`; `BattleDebugPanel.h`; `Skill.h` `presetSkill`/`dealButtonEvent`/`eventSlot`; `LocalBattleMode::renderDebugPanel`; PlayerSlots singleton.
  Acceptance criteria: G3 build 0; G1/G2 still 0; panel code lists four columns; Cast does not write sim during ImGui except through presetSkill (allowed, debug-only). Headless: if ImGui cannot run, a small helper that formats kit rows is tested, and panel calls it.
  QA scenarios: happy: mage kit dump contains leaf 40010 / skill 980000 / key U. Failure: empty fighter kit shows `no profession tree` not 82010. Evidence: `.omo/evidence/offline-playtest-qa/task-6.md`.
  Commit: Y | Client: `feat(ui): list offline skill kit in battle debug`
  Recommended task executor category: visual-engineering (ImGui debug panel)

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [x] F1. Plan compliance audit
  Re-run each todo's acceptance commands (G1/G2/G4 as applicable, catalog exists, packer green, autotest EXIT=0). Confirm every GAP row has a delivering todo. Confirm mugen-rewrite F3 checkbox is still `[~]`. Recommended task executor category: unspecified-high
- [x] F2. Code quality review
  No SkillPool/AttackRole as kit source of truth; no reference-product names in Client/Server comments; no `.motion` generated; no `unordered_map` in sim state; DebugDraw presentation-only; fighter empty-kit path; `check_rules.ps1` exit 0. Recommended task executor category: unspecified-high
- [x] F3. Real manual QA
  Agent-executed: cwd Content RelWithDebInfo `--offline-room=20002 --offline-role=mage --autotest-frames=300` EXIT=0; log has no lilimu motion `'0'`; youli misses if any are once per name; evidence screenshot or log of Battle Debug kit lines if UI can be dumped, else headless kit dump. This F3 does **not** clear mugen-rewrite F3 / M-FINAL.md. Recommended task executor category: unspecified-high
- [x] F4. Ideal-state fidelity
  1:1 against IS-1…IS-5. Shortfall becomes new `- [ ] N.` rows, never a note. IS-5 is proven by mugen-rewrite.md still showing F3 `[~]`. Recommended task executor category: unspecified-high

## Commit strategy
- Per submodule, conventional commits as on each todo line. No `--no-verify`. No root submodule pointer commit unless the user later asks.
- Do not commit secrets. Do not `git config`.
- Catalog todo commits nothing in product repos.
- First Client commit that already has dirty `LocalBattleMode.cpp` follow-entity: include that line with the collision or spawn todo that edits the file; message may note camera follow was already in the working tree.
- Do not push.

## Success criteria
> One row per IS row. The plan is complete only when every IS row has a delivering todo and a proving QA scenario; F4 checks the delivered behavior against these rows 1:1, and a shortfall becomes new `- [ ] N.` rows, never a note.
| IS | Delivering todo(s) | Proving QA scenario | Evidence |
| --- | --- | --- | --- |
| IS-1 | 1 | catalog has mismatch rows for youli names; autotest does not flood the same line every frame (todo 45 still holds) | `.omo/evidence/offline-playtest-qa/motion-miss-catalog.md`, `task-1.md` |
| IS-2 | 5 | 104 slot A skill 980000; autotest stderr has no lilimu `'0'` | `task-5.md` |
| IS-3 | 5, 6 | kit dump lists tree leaves; overflow Cast helper exists | `task-5.md`, `task-6.md` |
| IS-4 | 3 | damage drawn only when enabled; F8 not a ControlKey | `task-3.md` |
| IS-5 | (guardrail) | `.omo/plans/mugen-rewrite.md` F3 still `[~]` | F1/F4 evidence |
