# F1 — Plan compliance audit

Plan: `.omo/plans/offline-playtest-qa.md` Final Verification Wave F1.

**VERDICT: APPROVE**

## Acceptance commands re-run (parent)

| Gate | Command / artifact | Result |
| --- | --- | --- |
| Catalog | `.omo/evidence/offline-playtest-qa/motion-miss-catalog.md` | exists; youli `{18,30,38,74,siwang}` = mismatch; lilimu `'0'` = code-bug |
| G1 | `pwsh TestsHeadless/run_headless_tests.ps1` | 262 cases / 246100 assertions / 0 failed |
| G1 filter | `*PlayerKit*,*OfflineKitDump*,*Determinism*,*SkillTree*` | 13 passed / 5157 assertions |
| G2 | `pwsh TestsHeadless/check_rules.ps1` | EXIT=0 |
| G3 | `cmake --build build --config RelWithDebInfo --target AxmolFighter-Client` | EXIT=0 (todo 6) |
| G4 | packer (todo 4) | EXIT=0; schemaHash `15664757811292255776`; tree 9 / leaf 311; no re-pack after todos 5–6 (schema unchanged) |
| Autotest | cwd Content RelWithDebInfo `--offline-room=20002 --offline-role=mage --autotest-frames=300` | EXIT=0; `world hash 300 8c9e2797208ff29b`; **no** lilimu `'0'` |

## GAP → delivering todo

| GAP | Delivered by |
| --- | --- |
| GAP-1 youli name mismatch | todo 1 catalog |
| GAP-2 U → monster 82010 / action 0 | todo 5 `offlineKit` + RoleSpawn 101–104 |
| GAP-3 no packed tree/leaf / unused `playerLoadout` | todos 2, 4, 5 |
| GAP-4 DebugDraw not wired / no damage rects | todo 3 F8 + ImGui + cyan damage |
| GAP-5 fighter no professionType 3 | todo 5 empty kit + English warning; todo 6 `no profession tree` |

## Guardrail

`.omo/plans/mugen-rewrite.md` F3 remains `[~]` (line 1349). This F-wave does **not** mark it `[x]`.

## Client commits (path-limited)

- `886e99bd60022490a5737e459bf79f06ea1e3ee6` `feat(sim): load offline heroes from profession skill tree`
- `94315a797bb3e7cc9deac4a0af8577cba26c6a57` `feat(ui): list offline skill kit in battle debug`
