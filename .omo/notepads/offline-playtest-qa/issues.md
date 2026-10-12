
## 2026-10-11 Plan: offline-playtest-qa
- Metis session ses_ed589dd83ffe0QenXyGHTcDoso completed without a written 8-section report; findings folded from its last thinking + independent reads.
- Do not key spawn player kit on playerSlot: Determinism rooms would empty the dummy hero kit.
- Do not leave stale .mgrp schemaHash after packing new tables.
- Dirty LocalBattleMode.cpp setFollowEntity: keep the line; isolate from catalog/Tools-only commits.
- deep-low quota exhausted; do not resume ses_ed9bcab61ffeINHkgnbQdAR3Jq.

## 2026-10-11 Todo 1 catalog
- Do not treat youli `{18,30,38,74,siwang}` as missing-file: `tx_youli_zidongsheji.motion` exists; names `{0,2,4,6,8,10,12,14,16,JN1}`.
- Do not add a `0` clip to `rw_newzhujue_lilimu.motion`; lilimu `'0'` is spawn monster-kit (todo 5).
- writing quota exhausted on earlier sessions; do not resume ses_ed51833f8ffeVXvP7uD91rh1B0 / ses_ed51664e1ffeTR7fxm2AsMzbmx.
- unspecified-high monthly quota exhausted (todo 2 import failed with quota_exceeded, ses_ed4a2f20bffeLAXdy7yvQkZLGK, no files changed). Retry todo 2 as quick. Do not resume that session.

## 2026-10-11 Todo 2 import
- Do not pack config.bin here. skill_tree/skill_leaf are not in the packer schema yet (todo 4).
- Tools working tree was already dirty. Commit 183c6cd is only the skill_tree/skill_leaf registration. skill_rock and the other uncommitted converter edits were put back after that commit.
- Re-verify left those unrelated Tools dirty files unstaged. Do not fold them into the KIND_SPECS commit.

## 2026-10-12 Todo 4 pack retry
- unspecified-low monthly quota exhausted (todo 4 pack failed with quota_exceeded, ses_ed405f427ffer425HDUxJZTQfS, no files changed). Retry todo 4 as quick. Do not resume that session.



## 2026-10-12 Todo 4 pack
- Client 索引里已有 200+ 条暂存路径。提交必须用 path-limited commit，不能 git commit 不带路径。
- HEAD 的 ConfigTables.h 仍是 skill/skill_hit 两行 stub；工作区才是完整登记表。提交记录的是测试过的工作区头文件。
- Tools 工作区其余转换器改动保持未暂存。table-kind-mapping.md 里原有的无关行差不要整文件带走。
- 根 README 的 40→42 落在一份已有大段未提交文档差的文件上。不提交根仓库，避免子模块指针。

## 2026-10-12 Todo 5 spawn blocked
- Fresh `task()` spawn blocked: root `ses_ed9e94eceffe9HINasR4YgkNW3` has 24 live descendants (`background_task.maxLiveDescendantsPerRoot=24`). `background_cancel` only cancels running tasks; completed descendants still count. Resume an existing completed worker via `task_id` instead of spawning.
- Do not resume quota-exhausted sessions. Resume `ses_ed49fdd70ffeQQJKO1igOFm4bt` (todo 2 quick, succeeded) for todo 5.
- Resume `ses_ed49fdd70ffeQQJKO1igOFm4bt` with `run_in_background=false` timed out 30min, zero product files; later `run_in_background=true` returned Task not found. Same Task-not-found on `ses_ed483387bffekquJDvSpRT26fO`. Fresh spawn still 24/24. Next: resume live Sisyphus `ses_ee1e7957fffeJdLBo3v9iMK1ZM` (session_info still answers) with foreground continuation.

## 2026-10-12 F-wave
- Autotest extra youli `{1004,52,50,54}` were not in the original owner-reported set. They are catalog-class mismatch, not a new implementation todo.
- Do not generate `.motion` / pack `avatar.bin` for those names.
- Do not mark mugen-rewrite F3 `[x]`.

