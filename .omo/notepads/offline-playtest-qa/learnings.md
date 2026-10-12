
## 2026-10-11 Plan: offline-playtest-qa
- Config KIND_SPECS + COMBAT_KINDS is the import path (same as skill_rock).
- C++ structs in SkillTables.h are the packer schema; every Lua field both ways.
- spawnRole player kit is gated on toCharacterClass(roleId) in {101-104}, never playerSlot or roleType==1.
- ScenarioHarness roomWorld uses roleId=0 + playerSlot=0; role.lua id 0 is roleType=1 and must stay on monsterLoadout.
- Mage leaf 40010 → skill 980000 → action 980000 action=10100, present in rw_newzhujue_lilimu.motion.
- Mage rub 40110 → skill 980120 has no skill_rock row; use SAP or Debug Cast, do not drop.
- Fighter professionType 3 has no skill_tree row; empty kit + English warning, never invent leaves or reuse AI-3.
- DebugDraw is presentation-only; F8 + ImGui; no --debug-draw CLI.
- Adding MG_CONFIG_TABLES rows changes configSchemaHash; rewrite TestsHeadless/data/replays/*.mgrp headers in todo 4 before spawn changes.

## 2026-10-11 Todo 1 catalog
- Youli miss is CONFIG/SKELETON name mismatch: `tx_youli_zidongsheji.motion` exists with JSON names `{0,2,4,6,8,10,12,14,16,JN1}`; owner names `{18,30,38,74,siwang}` come from `ActionEffectConfig.action` (`Effect.cpp:190`).
- Representative rows: action_effect id 210 `action=18` (:4521/:4543); id 20120 `action=30` (:18519/:18541); id 20160 `action=38` (:18761/:18783); id 951210 `action=74` (:303343/:303365); id 8 `action="siwang"` (:289/:311).
- `resSpineId=101` effect clusters (1014..1030, 900130.., 901850..) resolve to action `{0,2,4,6,8}` which ARE in the youli name set; optional pass added no extra miss rows.
- Lilimu `'0'` is code-bug: `--offline-role=mage` → role 104 `aiId={3}` → `loadSkill` no loadout → `monsterLoadout` → skill 82010 → action 900000 `action=0`; lilimu.motion starts at 101, has `10100`, no `"name": "0"`.
- Once-log still holds (`MissingAvatarMotion.cpp:21-27` key = file+name); catalog does not claim per-frame flood.
- English log strings: `Avatar: motion '{}' not found in '{}'` (`MissingAvatarMotion.cpp:27`); `MotionPlayer::play: motion not found '{}' in '{}'` (`MotionPlayer.cpp:59`).

## 2026-10-11 Todo 2 import
- `idFromKey = 'id'` overwrites `__default_table.id`. The nil-id fallback never runs once defaults fill `id` (tree 1 default id=1, leaf 0 default id=0).
- Convert wrote 9 tree rows (ids 1,2,4,11,12,21,22,41,42; no 3) and 311 leaf rows. Tree 4 `professionType=4`, leafIds 40010..40080,40100,40120, leafRubId 40110, leafBuffId 40090. Leaf 40010 `skillId=980000`.
- `--kinds nosuch` still errors `unknown kind` (exit 1).
- Re-convert of committed specs (cwd `AxmolFighter-Tools/config_converter/script`) is idempotent: 9 tree + 311 leaf rows, Config tables stay clean vs `25b2c0d`.



## Task 3 (DebugDraw hurt boxes + F8)
- axmol Color4F has no CYAN; use local constant {0,1,1,1}.
- WorldBox from transformBox is world-space min-corner; old red rect double-added entity position. Draw [pos, pos+size] on x/z to match CollisionSystem intersects.
- axmol build -p win32 -c RelWithDebInfo may return 0 without relinking; use cmake --build build --config RelWithDebInfo --target AxmolFighter-Client.
- Autotest 20002 mage 300 hash bc37c5a5d6618b1e unchanged before/after (render-only).


## Task 4 (skill_tree / skill_leaf pack)
- scaffold 对 skillDamageFactor 给出 Fixed | int32_t。readFixed 接受任意 Lua number，结构体用 Fixed，与 SkillRockConfig 一致。
- schemaHash before 735714878451861681 after 15664757811292255776。
- .mgrp schemaHash 是 offset 8 的大端 uint64（MGRP + u32 version 1）。只改这 8 字节，payload 不动。
- G1 全量 254 passed。G2 exit 0。G4 pack exit 0，tree 9 rows，leaf 311 rows，四条 ref dangling=0。

## Todo-5 implementation (2026-10-12)
- offlineKit(CharacterClass) added in Skill.h/SkillLoadout.cpp; RoleSpawn.cpp gate keys on toCharacterClass(roleId)!=kUnknown + mode!=Town.
- Test file TestsHeadless/tests/PlayerKitTest.cpp (auto-globbed). Uses spawnRole + offlineKit + monsterLoadout baseline compare.
- Mage rub leaf 40110->980120 has no skill_rock row -> SAP ("M"); buff 40090->SUB ("J"); sprint 40020 -> "Y".
- AiAgent include needed for monster test: RoleSpawn adds AiAgent component (Components.h via World.h).
- getGivenSkill monster: group0 slot0 -> slotName "A" (ai14 first skill 83040).
- Parent autotest 20002 mage 300: EXIT=0, world hash `8c9e2797208ff29b` (changed vs `bc37c5a5d6618b1e`). No lilimu `'0'`. Youli once-log still fires extra names `1004/52/50/54` (catalog-only this plan).
- Client commit `886e99bd60022490a5737e459bf79f06ea1e3ee6` path-limited four files only: Skill.h, SkillLoadout.cpp, RoleSpawn.cpp, PlayerKitTest.cpp. Those files were not in HEAD before (index had 200+ staged paths from earlier work). Do the same path-limited pattern for todo 6.

## Todo-6 implementation (2026-10-12)
- Helper `offlineKitRows` / `OfflineKitRow` in Skill.h + SkillLoadout.cpp; panel lists after F8 checkbox. Empty kit: English `no profession tree`.
- Mage dump: leaf 40010 / skill 980000 / key U / Attack / pool `A`. SAP 980120 stays pool `M` because Anger uses pool `P`. Unused T/H/Q assigned to SAP/SBP/SCP.
- Overflow Cast: `skill::presetSkill(world, player, poolSlot)` via ImGui PushID. No new keyboard bindings.
- Tests: OfflineKitDumpTest.cpp 2/2. G1 262/262. G2 EXIT=0. G3 RelWithDebInfo EXIT=0.
- Path-limit Client commit to Skill.h, SkillLoadout.cpp, BattleDebugPanel.cpp, OfflineKitDumpTest.cpp. Index still has 200+ unrelated staged paths.

## 2026-10-12 F-wave
- F1–F4 VERDICT APPROVE. Evidence: `.omo/evidence/offline-playtest-qa/F1-plan-compliance.md` … `F4-ideal-state.md`.
- Autotest extra youli names `{1004,52,50,54}` folded into `motion-miss-catalog.md` as the same mismatch class as `{18,30,38,74,siwang}`. Representative rows: action_effect id 121116 `action=1004`; id 10050 `action=52`; id 10049 `action=50`; id 10047 `action=54`.
- No new implementation checkbox. Do not invent clips. mugen-rewrite F3 stays `[~]`.

