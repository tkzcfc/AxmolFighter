# 20002 mage Avatar / MotionPlayer miss catalog

Plan: `.omo/plans/offline-playtest-qa.md` todo 1. Catalog only: no `.motion` generated, no `avatar.bin` pack, no action/effect id remap.

Once-log (mugen-rewrite todo 45) still holds: `findAvatarMotion` keys on `motionFile + '\n' + motionName` and inserts into a process-level set before `MG_LOG_W`. This catalog does **not** claim a per-frame flood.

## Motion files (JSON `name` lists present)

| File | JSON `name` list |
| --- | --- |
| `AxmolFighter-Client/Content/mugen/motion/effect/tx_youli_zidongsheji.motion` | `{0, 2, 4, 6, 8, 10, 12, 14, 16, JN1}` (lines 6, 17, 28, 39, 50, 61, 72, 83, 94, 105) |
| `AxmolFighter-Client/Content/mugen/motion/hero/rw_newzhujue_lilimu.motion` | starts at `101` (line 6); includes `10100` (line 160); **no** `"name": "0"` |

`tx_youli_zidongsheji.motion` is on disk. `AvatarPaths::motionFileFromSpine` (`AvatarPaths.cpp:22-56`) derives it from `res_spine.lua:380-385` id **101** `fileName = "mugen/spine/effect/tx_youli_zidongsheji.skel"` by replacing `mugen/spine/` → `mugen/motion/` and `.skel` → `.motion`.

## Log strings (quoted from code)

| Source | Line | English string |
| --- | --- | --- |
| `MissingAvatarMotion.cpp` | 27 | `Avatar: motion '{}' not found in '{}'` |
| `MotionPlayer.cpp` | 59 | `MotionPlayer::play: motion not found '{}' in '{}'` |

Avatar render path: `Avatar.cpp:243` `findAvatarMotion(*m_motionMap, m_desc.motionFile, motionName)` → once-log warning.
Logic path: `MotionPlayer::play` → error (not once-keyed the same way as Avatar; bind-missing is once at `MotionPlayer.cpp:27-28`).

Effect motion name: `Effect.cpp:190` `motion.motionName = std::holds_alternative<std::string>(row->action) ? std::get<std::string>(row->action) : std::to_string(std::get<int32_t>(row->action));` from `ActionEffectConfig.action`.

Hero attack motion name: `AttackRole.cpp:116-117` same conversion from `ActionConfig.action`.

## Catalog

| log line | entity kind | config table+id+field | field value | motion file path | JSON `name` list present | verdict |
| --- | --- | --- | --- | --- | --- | --- |
| `Avatar: motion '18' not found in 'mugen/motion/effect/tx_youli_zidongsheji.motion'` (`MissingAvatarMotion.cpp:27`) | effect | `action_effect.lua` id **210** field `action` (`action_effect.lua:4521` value, `:4543` id) | `18` | `AxmolFighter-Client/Content/mugen/motion/effect/tx_youli_zidongsheji.motion` | `{0,2,4,6,8,10,12,14,16,JN1}` | **mismatch** |
| `Avatar: motion '30' not found in 'mugen/motion/effect/tx_youli_zidongsheji.motion'` (`MissingAvatarMotion.cpp:27`) | effect | `action_effect.lua` id **20120** field `action` (`action_effect.lua:18519` value, `:18541` id) | `30` | `AxmolFighter-Client/Content/mugen/motion/effect/tx_youli_zidongsheji.motion` | `{0,2,4,6,8,10,12,14,16,JN1}` | **mismatch** |
| `Avatar: motion '38' not found in 'mugen/motion/effect/tx_youli_zidongsheji.motion'` (`MissingAvatarMotion.cpp:27`) | effect | `action_effect.lua` id **20160** field `action` (`action_effect.lua:18761` value, `:18783` id) | `38` | `AxmolFighter-Client/Content/mugen/motion/effect/tx_youli_zidongsheji.motion` | `{0,2,4,6,8,10,12,14,16,JN1}` | **mismatch** |
| `Avatar: motion '74' not found in 'mugen/motion/effect/tx_youli_zidongsheji.motion'` (`MissingAvatarMotion.cpp:27`) | effect | `action_effect.lua` id **951210** field `action` (`action_effect.lua:303343` value, `:303365` id) | `74` | `AxmolFighter-Client/Content/mugen/motion/effect/tx_youli_zidongsheji.motion` | `{0,2,4,6,8,10,12,14,16,JN1}` | **mismatch** |
| `Avatar: motion 'siwang' not found in 'mugen/motion/effect/tx_youli_zidongsheji.motion'` (`MissingAvatarMotion.cpp:27`) | effect | `action_effect.lua` id **8** field `action` (`action_effect.lua:289` value, `:311` id) | `siwang` | `AxmolFighter-Client/Content/mugen/motion/effect/tx_youli_zidongsheji.motion` | `{0,2,4,6,8,10,12,14,16,JN1}` | **mismatch** |
| `Avatar: motion '1004' not found in 'mugen/motion/effect/tx_youli_zidongsheji.motion'` (`MissingAvatarMotion.cpp:27`; autotest 20002 mage once-log) | effect | `action_effect.lua` id **121116** field `action` (`action_effect.lua:95156` value, `:95178` id) | `1004` | `AxmolFighter-Client/Content/mugen/motion/effect/tx_youli_zidongsheji.motion` | `{0,2,4,6,8,10,12,14,16,JN1}` | **mismatch** |
| `Avatar: motion '52' not found in 'mugen/motion/effect/tx_youli_zidongsheji.motion'` (`MissingAvatarMotion.cpp:27`; autotest 20002 mage once-log) | effect | `action_effect.lua` id **10050** field `action` (`action_effect.lua:12114` value, `:12136` id) | `52` | `AxmolFighter-Client/Content/mugen/motion/effect/tx_youli_zidongsheji.motion` | `{0,2,4,6,8,10,12,14,16,JN1}` | **mismatch** |
| `Avatar: motion '50' not found in 'mugen/motion/effect/tx_youli_zidongsheji.motion'` (`MissingAvatarMotion.cpp:27`; autotest 20002 mage once-log) | effect | `action_effect.lua` id **10049** field `action` (`action_effect.lua:11988` value, `:12096` id) | `50` | `AxmolFighter-Client/Content/mugen/motion/effect/tx_youli_zidongsheji.motion` | `{0,2,4,6,8,10,12,14,16,JN1}` | **mismatch** |
| `Avatar: motion '54' not found in 'mugen/motion/effect/tx_youli_zidongsheji.motion'` (`MissingAvatarMotion.cpp:27`; autotest 20002 mage once-log) | effect | `action_effect.lua` id **10047** field `action` (`action_effect.lua:11908` value, `:11930` id) | `54` | `AxmolFighter-Client/Content/mugen/motion/effect/tx_youli_zidongsheji.motion` | `{0,2,4,6,8,10,12,14,16,JN1}` | **mismatch** |
| `MotionPlayer::play: motion not found '0' in 'mugen/motion/hero/rw_newzhujue_lilimu.motion'` (`MotionPlayer.cpp:59`) | hero | `action.lua` id **900000** field `action` (`action.lua:210238` value, `:210280` id) | `0` | `AxmolFighter-Client/Content/mugen/motion/hero/rw_newzhujue_lilimu.motion` | starts `101`; has `10100`; no `0` | **code-bug** |
| `Avatar: motion '0' not found in 'mugen/motion/hero/rw_newzhujue_lilimu.motion'` (`MissingAvatarMotion.cpp:27`) | hero | same `action.lua` id **900000** `action=0` (render once-log of the same play) | `0` | `AxmolFighter-Client/Content/mugen/motion/hero/rw_newzhujue_lilimu.motion` | starts `101`; has `10100`; no `0` | **code-bug** |

Youli cluster verdict is **mismatch**, not missing-file: the `.motion` exists; requested names `{18,30,38,74,siwang,1004,52,50,54}` are absent from the JSON name set. Downstream must not invent clips. Autotest extra names `{1004,52,50,54}` are the same mismatch class as the owner-reported cluster (file present; names absent).

Lilimu `0` verdict is **code-bug**, not missing-file: spawn uses the monster kit. Closed later by todo 5 (`playerLoadout` from profession tree), **not** by adding a `0` clip.

## Lilimu `0` chain (cited)

1. `--offline-role=mage` → `MainScene.cpp:116-117` `roleId = 104`.
2. `role.lua:1007` id **104**; `role.lua:940-942` `aiId = {3}`; `role.lua:1030` `resSpineId = 88104`.
3. `res_spine.lua:14907-14909` id **88104** `fileName = "mugen/spine/hero/rw_newzhujue_lilimu.skel"` → motion `mugen/motion/hero/rw_newzhujue_lilimu.motion`.
4. `RoleSpawn.cpp:200-201` `skill::loadSkill(world, entity)` with no loadout (non-Town).
5. `SkillLoad.cpp:108-110` `monsterLoadout(world.ecs().get<RoleIdentity>(entity).aiId)`.
6. `ai.lua:364` id **3**; `ai.lua:434-452` `skillIds` six copies of **82010**.
7. `skill.lua:15660-15676` id **82010** `actionIds = {{900000, 900010, 900020}, {-1}}`.
8. `action.lua:210238` `action = 0`; `action.lua:210280` `id = 900000`.
9. U key: `GameView.cpp:43` `KEY_U` → `ControlKey::AttackA` → `SkillInput.cpp:15-16` slot `"A"`.

`playerLoadout` (`SkillLoadout.cpp:30`) is unused on this spawn path. Mage real attack clip is `10100` (present in lilimu.motion line 160); that path is todo 5.

## Optional: other `resSpineId = 101` actions

Grep `effect.lua` `resSpineId = 101` clusters (`effect.lua:11471` id 1014 … `:12287` id 1030; `:353142` id 900130 …; `:361914` id 901850 …). Their `actionIds` resolve in `action_effect.lua` to `action` values `{0,2,4,6,8}` (examples: id 1014 `action=2` `:7201/:7223`; id 1026 `action=0` `:7681/:7703`; id 900130 `action=2` `:263293/:263315`; id 901850 `action=2` `:270162/:270184`). Those names **are** in `tx_youli_zidongsheji.motion`. No extra miss names from this optional pass.

Owner-reported youli names `{18,30,38,74,siwang}` are `ActionEffectConfig.action` values played onto the youli skeleton (`Effect.cpp:190` + `AvatarPaths` from resSpine 101). Representative rows cited above; many other `action_effect` rows share the same numeric `action` on other spines (e.g. effect 20160 itself uses `resSpineId = 2000` at `effect.lua:34667/:34677`). The miss is the **name** vs youli JSON list, not a missing `.motion` file.
