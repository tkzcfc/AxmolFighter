# F3 — Real manual QA (agent-executed)

Plan: `.omo/plans/offline-playtest-qa.md` Final Verification Wave F3.
This F3 does **not** clear mugen-rewrite F3 / M-FINAL.md.

**VERDICT: APPROVE**

## Autotest

- cwd: `AxmolFighter-Client/Content`
- exe: `build/bin/AxmolFighter-Client/RelWithDebInfo/AxmolFighter-Client.exe`
- flags: `--offline-room=20002 --offline-role=mage --autotest-frames=300`
- EXIT=0
- `world hash 300 8c9e2797208ff29b`
- stderr/stdout: **no** `MotionPlayer::play: motion not found '0'` and **no** lilimu `'0'`

## Once-log youli names (not a flood)

Each name logged **once**: `38`, `30`, `1004`, `18`, `52`, `50`, `54` on `tx_youli_zidongsheji.motion`.
Owner catalog names `{18,30,38,74,siwang}` remain mismatch. Extra names `1004/52/50/54` are the same once-log class (file exists; name not in JSON `{0,2,4,6,8,10,12,14,16,JN1}`).

## Kit dump (headless; ImGui cannot run in TestsHeadless)

`OfflineKitDumpTest.cpp`:

- mage: leaf **40010** / skill **980000** / key **U** / Attack / pool `A`
- fighter: empty rows; display string `no profession tree`; no skill 82010

Panel (`BattleDebugPanel.cpp:37-48`) prints those columns and overflow `Cast` → `presetSkill`.

## Guardrail

`.omo/plans/mugen-rewrite.md` F3 stays `[~]`.
