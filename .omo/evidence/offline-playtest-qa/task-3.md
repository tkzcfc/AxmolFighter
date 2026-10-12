# Task 3 — DebugDraw hurt boxes + ImGui checkbox + F8 (default off)

## Changes (AxmolFighter-Client)
- `Source/mugen/render/battle/WorldPresenter.cpp`: `DebugDraw::present` draws `collider.attack` (red) and `collider.damage` (cyan `kHurtBoxColor{0,1,1,1}`; axmol `Color4F` has no `CYAN`) via one `drawBoxes` lambda. Yellow radius circle and green moveRanges kept.
- `WorldPresenter.h`: `bool enabled() const`; `m_enabled = false` default unchanged.
- `BattleDebugPanel.{h,cpp}`: `render(..., bool& collisionDebug)` + `ImGui::Checkbox("Collision boxes (F8)")`.
- `LocalBattleMode.{h,cpp}`: `toggleCollisionDebug()`; `renderDebugPanel` reads `debugDraw().enabled()`, passes to panel, writes back `setEnabled`. `setFollowEntity(player)` (line 69) kept.
- `GameView.cpp`: `onKeyPressed` handles `KEY_F8` before `setInputFromKey` and returns; `onKeyReleased` unchanged → F8 not in `m_slotMap`, release never reaches a toggle (and maps to nothing).

## present() lines (WorldPresenter.cpp after edit)
```
180 void DebugDraw::present(sim::World& world)
182     m_node->clear();
183     if (!m_enabled)
184         return;
186     const auto drawBoxes = [this](const std::vector<sim::WorldBox>& boxes, const ax::Color4F& color) {
188             m_node->drawRect({renderValue(box.pos.x), renderValue(box.pos.z)},
189                              {renderValue(box.pos.x + box.size.x), renderValue(box.pos.z + box.size.z)}, color);
194         m_node->drawCircle(center, renderValue(collider.radius), 0.0f, 16, false, ax::Color4F::YELLOW);
195         drawBoxes(collider.attack, ax::Color4F::RED);
196         drawBoxes(collider.damage, kHurtBoxColor);
198-200   moveRanges GREEN drawRect
```
Failure QA: with `m_enabled == false`, line 183-184 returns before any `drawRect` (attack, damage, moveRange) — only `clear()` runs.

## Box formula deviation (intentional)
The old red formula treated `box.pos` as a local center offset added to `transform.position` (`center + pos ± size/2`). `RoleUpdate.cpp:98-108 transformBox` already writes **world-space** boxes with `pos` = min corner (x includes `position.x`; z = `position.y + position.z + box.z`), and `CollisionSystem.cpp:20-29 intersects` tests `[pos, pos+size]`. Old code double-added the entity position and shifted by half size. Both red and cyan now draw `[pos.x, pos.x+size.x] × [pos.z, pos.z+size.z]`, matching the collision test exactly.

## Render-only
`DebugDraw::present` takes colliders by const ref via `each<Transform, ColliderState>` and `singleton<MapRegion>()` read; it only writes the `ax::DrawNode`. No sim/collision/RoleUpdate files touched. Toggle state lives in `DebugDraw::m_enabled` (presentation object), not in the World.

## Gates
- G2 `pwsh TestsHeadless/check_rules.ps1` → EXIT=0
- G1 `pwsh TestsHeadless/run_headless_tests.ps1` → 253/253 test cases, 245397 assertions, EXIT=0
- G3 `cmake --build build --config RelWithDebInfo --target AxmolFighter-Client` (VS 18 2026 generator, existing `build/`) → EXIT=0 (first attempt failed on `Color4F::CYAN`, fixed with local constant). Note: `axmol build -p win32 -c RelWithDebInfo` earlier returned 0 without relinking, so cmake --build was used directly.
- Autotest RelWithDebInfo `--offline-room=20002 --offline-role=mage --autotest-frames=300` (cwd Content) → EXIT=0, `world hash 300 bc37c5a5d6618b1e` — identical to the pre-change exe run, confirming no sim effect. Logs: `task-3-autotest2.{out,err}.txt`.
- lsp_diagnostics: clangd has no compile DB for these files (only `file not found` include errors); MSVC build is the authoritative compile check.

No agent-owned display for screenshots; overlay QA is by code citation above.
