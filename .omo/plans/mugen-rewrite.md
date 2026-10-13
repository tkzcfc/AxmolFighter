# mugen-rewrite - Work Plan

## TL;DR (For humans)

**Who this is for and what changes for them:** For the project owner (combat programmer and designer). When this is done you can launch the client locally and play a full multi-room dungeon. Combat feel and numbers follow the reference project, and the combat core is ready for the later lockstep or state sync work.

**What you'll get:**
- A rewritten combat core with deterministic fixed-point math. It rebuilds the reference project's character, skill, hit, Buff, AI, and room flow.
- A config packer that reports errors as soon as there is a problem.
- Headless automated tests and deterministic replay.

**Why this approach:**
- The current gameplay layer has too many deviations and bugs to patch.
- Fixed-point math plus a data-only ECS lets client and server produce bit-identical results and makes snapshots and rollback cheap.
- Using C++ structs as the config schema keeps code and tables from drifting apart.

**What it will NOT do:**
- No server or network sync. The battle server will rewrite against this core later.
- No artifacts, rage transformation, pets, PVP-specific logic, auto battle, transformation (`transform_id`), story, or tutorial.

**Effort:** XL
**Risk:** High - large porting volume (about 29k lines of Lua semantics), and the fixed-point/determinism constraints touch every line.
**Decisions to sanity-check:**
- Fixed-point is Q44.20.
- The behavior tree splits definition from instance.
- Collision uses 2D AABB in the screen plane plus a depth radius filter. The box depth field is kept but ignored.
- Config is packed by pure C++.
- Online battle code is deleted for now.
- Town mode reuses the new World.

Your next move: run `/ulw-execute mugen-rewrite` in OpenCode. Whenever a milestone completes, follow `.omo/evidence/milestones/M<n>.md` to do a hands-on check.

---

> TL;DR (machine): XL / High. Rewrite `AxmolFighter-Client/Source/mugen` (core + conf + sim + render/battle), pure-C++ config converter, local full-dungeon combat, headless deterministic tests. Binding contract: `.omo/specs/mugen-rewrite-architecture.md`.

**Binding contract:** every worker MUST read `.omo/specs/mugen-rewrite-architecture.md` §0 plus the sections cited by its todo before writing code. If the contract conflicts with old code or old READMEs, the contract wins. If the contract conflicts with reference-project combat semantics, the reference semantics win; record that in the notepad.

## Scope

### Affected user and ideal state
**Affected user:**
- The project owner (runs and tweaks combat locally).
- Designers (edit tables and repack).
- The future battle-server rewriter (consumes the headless sim core).

| Row | Statement | Reason |
| --- | --- | --- |
| IS-1 | Go from town into a dungeon locally. The hero can walk, run, chain combos, use B/C/D skills, dodge, enter Crazy, input motion commands (搓招), break free, and do sprint attacks, cancelling in the same windows as the reference | The core of combat feel |
| IS-2 | Monsters follow the reference AI: patrol, wake up, chase, alert-wander, and cast skills by priority, interval, and SkillAi | Without AI there is no combat |
| IS-3 | Hit checks, damage numbers, crits/dodges, launch-fall-knockdown-getup, hit-freeze, root, Buff, and special abilities match reference semantics; damage-formula golden tests pass | Numbers and feel are the acceptance baseline |
| IS-4 | Room flow: spawns, waves, victory/defeat, Boss KO slow-mo, revive, portal room change, obstacles, drops, summons | Needed to finish a full dungeon |
| IS-5 | Same input gives the same per-frame hash. After snapshot restore or clone rollback, continued play gives the same hash. All logic is fixed-point | Foundation for lockstep / state sync |
| IS-6 | After editing a Lua table, one command repacks. Field, type, and reference errors are reported at pack time, never silently dropped | Data correctness |
| IS-7 | Town still supports walking, and remote players still render | No regression |
| IS-8 | The sim layer has no engine dependency and can be compiled and tested headless | Paves the way for the server and CI |
| GAP-1 | Today: the cd=0 basic attack can only be cast once, hero skills are hard-coded, cancel windows are wrong | Basic gameplay is broken |
| GAP-2 | Today: AI behavior is invented and does not follow Entity.xml | Combat experience is distorted |
| GAP-3 | Today: damage formula is wrong, Buff lacks execute/reset/immunity, there is a phantom "every skill also hits in melee" path | Numbers and feel are distorted |
| GAP-4 | Today: no room state machine, waves, portals, obstacles, drops, or summons | Cannot finish a dungeon |
| GAP-5 | Today: float physics; snapshots miss the clock; system order changes after restore; restore loses config pointers | Cannot sync |
| GAP-6 | Today: hand-written struct and converter pairs. Types such as 0.5→0 and nested arrays→0 drop data silently. entity_effect2 and others were never imported | Data is wrong |
| GAP-7 | After the rewrite, the town must be re-adapted | Regression risk |
| GAP-8 | Today: logic calls axmol rendering and audio directly; logs are compiled out on the server | Cannot run headless |

### Must have
- Everything in `.omo/specs/mugen-rewrite-architecture.md`: fixed-point math, reflection, ECS, behavior tree, config, sim, collision, presentation, tests.
- Gameplay semantics match the reference project line by line. Each gameplay todo comes with at least 2 scenario tests (one happy path, one boundary or failure).
- A debug entry point that can start offline combat without any server: `--offline-room=<roomId>`, plus `--autotest-frames=N`, which runs N frames, prints the world hash, and exits.
- Every reference-project behavior marked "unconfirmed" gets a decision written into `.omo/notepads/mugen-rewrite/decisions.md`. Rulings for AI and the behavior tree are added to the matching section of the `Reference/` docs.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- No changes to `AxmolFighter-Server`, `AxmolFighter-Editor`, `AxmolFighter-UI`, or `heiyue/`. No push. No changes to the root repo's submodule pointers.
- No artifacts, rage transformation, pets, PVP-specific logic (pvp_cd / pvp_hurt_rate keep their data fields only), auto battle, transformation, story, tutorial, or online sync.
- No third-party ECS library. No compatibility shims for old APIs. No `float`/`double`/`std::function`/unordered containers in `sim/` or `core/` (see contract §0.4).
- Do not change combat semantics ("optimizing" feel, merging states, or simplifying formulas are all forbidden).
- Do not let the sim layer touch rendering, audio, UI, or system time. The presentation layer must never write sim state.
- No placeholder implementations left behind. During development, an unported behavior-tree leaf may only use the single searchable type `kUnimplementedLeaf`, and an unported Buff rule may only use `kUnportedRule`. Todos 30 / F1 require both counts to be zero for referenced data.

## Verification strategy
> All verification is executed by agents. When a milestone is reached, the orchestrator writes the manual acceptance checklist to `.omo/evidence/milestones/M<n>.md` for the user to check.

- Test decision: tests-after, with each todo finishing in the same session. The framework is doctest in the headless project `AxmolFighter-Client/TestsHeadless`.
- Per-todo gates (every one must pass):
  - G1 `pwsh AxmolFighter-Client/TestsHeadless/run_headless_tests.ps1` exits 0.
  - G2 `pwsh AxmolFighter-Client/TestsHeadless/check_rules.ps1` exits 0. Todo 2 only checks the paths it fixed; from todo 3 onward the full check must pass.
  - G3 client build: inside `AxmolFighter-Client`, run `axmol build -p win32 -c` (required after adding or removing files), then `axmol build -p win32`; both exit 0. Required from todo 3 onward.
  - G4 when `conf/` or `Config/table` changes: `pwsh AxmolFighter-Tools/config_converter/run_config_converter.ps1` exits 0. The new script name and arguments are fixed by todo 9.
  - G5 once todo 15 is done, gameplay todos also run the offline smoke: `AxmolFighter-Client/build/bin/AxmolFighter-Client/Release/AxmolFighter-Client.exe --offline-room=<roomId> --autotest-frames=900`, with working directory `AxmolFighter-Client/Content`. It must exit 0 and print `world hash`.
- Evidence: `.omo/evidence/mugen-rewrite/task-<N>.md` holds the commands that ran, key output excerpts, and new test names. Logs and screenshots go in the same directory.

## Execution strategy

### Ground rules for the orchestrator
- **Work in place.** This repo is made of git submodules. **Do not use git worktree, `--worktree`, or `--make-pr`.** All edits go into the current checkout on the `mugen-rewrite` branch of each subrepo (`AxmolFighter-Client`, `AxmolFighter-Client/Content`, `AxmolFighter-Tools`, `AxmolFighter-Config`).
- **Shared registry files** are owned by the orchestrator. When parallel workers need to add an entry, they report it in their reply and the orchestrator merges it:
  - `sim/Components.h`
  - `sim/Singletons.h`
  - `conf/ConfigTables.h`
  - `conf/ConfigRefs.h`
  - `conf/GameDef.h`
  - the tick pipeline in `sim/World.cpp`
  - the CMake files
- Notepad: `.omo/notepads/mugen-rewrite/learnings.md`, `decisions.md`, `issues.md`. Read them before each todo; append to them after each todo.
- **How to read the reference project:** read the relevant section of the `Reference/heiyue-*.md` docs first, then read only the cited `heiyue/src/...lua:line` locations. Bulk-scanning `heiyue/src` is forbidden. Lua source is UTF-8.
- At milestones M1–M6, the orchestrator writes `.omo/evidence/milestones/M<n>.md` (steps and expected results), pauses, and reports to the user. The final verification wave requires the user's explicit okay.

### Parallel execution waves
- **W0 Preparation:** 1 → 2 → 3; todo 8 can run in parallel once 1 is done.
- **W1 Core and config:** 4 → 5 → (6 ∥ 7 ∥ 9) → 10 → 11.
- **W2 Sim skeleton:** 12 → 13 → (14 ∥ 15 ∥ 21) → 16. Ends at **M1** (move/run in battle, monsters idle, town works).
- **W3 Skills:** 17 → (18 ∥ 19) → 20. Ends at **M2** (combos, skills, effects spawn, no hits yet).
- **W4 Hits:** 22 → 23. Ends at **M3** (can launch, combo, and kill monsters).
- **W5 Buff / abilities / AI:** 24 → (25 ∥ 26 ∥ 27 ∥ 28). Ends at **M4** (Buff), **M5** (AI).
- **W6 Rooms:** 29 → 30. Ends at **M6** (finish a multi-room dungeon locally).
- **W7 Wrap-up:** 31 → 32 → 33. Then the final verification wave.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | — | all | — |
| 2 | 1 | 3,4 | 8 |
| 3 | 2 | 6,7,12 | 8 |
| 4 | 2 | 5 | 3,8 |
| 5 | 4 | 6,7,9 | 3,8 |
| 6 | 3,5 | 12 | 7,9 |
| 7 | 3,5 | 12 | 6,9 |
| 8 | 1 | 10 | 2–7,9 |
| 9 | 5 | 10 | 6,7,8 |
| 10 | 8,9 | 11 | — |
| 11 | 10 | 12 | — |
| 12 | 6,7,11 | 13 | — |
| 13 | 12 | 14,15,21 | — |
| 14 | 13 | 16,17 | 15,21 |
| 15 | 13 | 16 | 14,21 |
| 16 | 14,15 | 17 | 21 |
| 17 | 14 | 18,19 | 16,21 |
| 18 | 17 | 23 | 19,21 |
| 19 | 17 | 20 | 18,21 |
| 20 | 19 | 22 | 21 |
| 21 | 13 | 22,33 | 14–20 |
| 22 | 20,21 | 23 | — |
| 23 | 18,22 | 24 | — |
| 24 | 23 | 25,26,27,28 | — |
| 25 | 24 | 29 | 26,27,28 |
| 26 | 24 | 29 | 25,27,28 |
| 27 | 24 | 29 | 25,26,28 |
| 28 | 24 | 29 | 25,26,27 |
| 29 | 25,26,27,28 | 30 | — |
| 30 | 29 | 31 | — |
| 31 | 30 | 32 | — |
| 32 | 31 | 33 | — |
| 33 | 21 | F1–F4 | (runs next, before 20/22+) |

## Todos
> Implementation + Test = ONE todo. Never separate. Every todo: read contract §0 first; finish with gates G1–G5 as applicable; write evidence; commit per sub-repo.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [x] 1. Pre-flight: branches, clean-tree check, baseline record
  What to do:
  - Run `git status --short` in each of `AxmolFighter-Client`, `AxmolFighter-Client/Content`, `AxmolFighter-Tools`, and `AxmolFighter-Config`.
  - If any repo has uncommitted changes: **stop**, mark this todo `[~]`, list the change summary, and ask the user to commit or stash. This is an owner decision. Never commit, stash, or discard the user's changes yourself.
  - Once all trees are clean, create and switch to branch `mugen-rewrite` in the 4 repos above.
  - Create `.omo/notepads/mugen-rewrite/{learnings,decisions,issues}.md`, `.omo/evidence/mugen-rewrite/`, and `.omo/evidence/milestones/`.
  - Check the toolchain and record versions in the evidence file: `cmake`, `ninja`, `lua`, `axmol`, `$env:AX_ROOT`, and that `$env:AX_ROOT/3rdparty/doctest/doctest.h` and `$env:AX_ROOT/3rdparty/rapidjson` exist.
  - Baseline: run `axmol build -p win32` in `AxmolFighter-Client` and record whether it passes (a failure is recorded, not fixed). Record line counts per subdirectory of `Source/mugen`.
  Must NOT do: modify any source file; operate on the root repo or the Server/Editor/UI repos.
  Closes: precondition for all GAPs
  Parallelization: W0 | Blocked by: — | Blocks: all
  References: `.omo/specs/mugen-rewrite-architecture.md` §0.6
  Acceptance criteria: `git -C <repo> rev-parse --abbrev-ref HEAD` prints `mugen-rewrite` for all 4 repos; `.omo/evidence/mugen-rewrite/task-1.md` exists and contains toolchain versions and the baseline build result.
  QA scenarios: happy path, clean trees, all 4 branches created. Failure path, a dirty tree: the todo is marked `[~]` and the orchestrator asks the user. Evidence: `.omo/evidence/mugen-rewrite/task-1.md`.
  Commit: N
  Recommended task executor category: quick

- [x] 2. Headless test project, rule-check script, server-side logging, rewrite of mugen/AGENTS.md
  What to do:
  - Create the `AxmolFighter-Client/TestsHeadless/` standalone CMake project (C++20; MSVC `/utf-8 /permissive- /W4 /bigobj`), producing two targets:
    - `mugen_tests`: doctest; `RUNTIME_IN_AXMOL=0`; uses `CONFIGURE_DEPENDS` globs for `Source/mugen/core/**`, `Source/mugen/conf/**`, `Source/mugen/avatar/**` (excluding `avatar/render/**`) and `Source/mugen/sim/**` (may be empty for now), plus `TestsHeadless/tests/**`.
    - `mugen_sim_cli`: for now only a `--version` subcommand; later todos extend it.
    - Include doctest and rapidjson from `$env:AX_ROOT/3rdparty`.
    - At this stage the old gameplay directories (`component/ system/ bt/ skill/ buff/ combat/ effect/ ai/ net/ common/`, plus `GameWord`/`ActorSpawner`) are **excluded** from the build; todo 3 deletes them. If `core/`, `conf/` or `avatar/data` fail to compile headless, fix them with the smallest change.
  - Create `TestsHeadless/run_headless_tests.ps1`:
    - parameters `-Filter <doctest -tc filter>` and `-Config Release|Debug`;
    - configures with Ninja when available, otherwise the default generator, builds into `TestsHeadless/build/`, runs `mugen_tests`, and passes its exit code through.
    - Add `TestsHeadless/build/` to `AxmolFighter-Client/.gitignore`.
  - Create `TestsHeadless/check_rules.ps1`, implementing all checks in contract §10.2:
    - comments are filtered out before checking;
    - `-Paths` limits the check scope;
    - violations are printed as `file:line: rule`, and the exit code is non-zero.
    - The product-name check is case-insensitive and covers at least `heiyue|黑月`. The script holds the list internally and prints no other names.
  - Fix existing violations in **retained** directories (`core conf avatar render` and the `ui resource` comments under Source). Example: the product name in `conf/TableConfig.h:9`.
  - Change `core/StdC.h` so that when `RUNTIME_IN_AXMOL=0`, `MG_LOG_D/I/W/E` write to stderr with a level prefix. Keep the existing placeholder style: check whether the current macros use `{}` fmt; if so, use C++20 `std::format`.
  - Rewrite `AxmolFighter-Client/Source/mugen/AGENTS.md` as a self-contained summary of the new contract (layering, prohibitions, ECS/BT/config/sim conventions, test commands):
    - remove the old "Object class layout" and "Pool/Manager objects" rules;
    - do not reference the `.omo` path;
    - in English.
  - Add a smoke test: two `Random` sequences with the same seed are identical.
  Must NOT do: modify the old gameplay code (todo 3 deletes it); introduce new third-party libraries.
  Closes: GAP-8 (tooling)
  Parallelization: W0 | Blocked by: 1 | Blocks: 3, 4
  References: contract §0.4, §10.1, §10.2; `AxmolFighter-Client/CMakeLists.txt:48-72` (existing glob style); `AxmolFighter-Client/Source/mugen/core/StdC.h:17-59`; `AxmolFighter-Server/battle/CMakeLists.txt:70-84` (how mugen was previously compiled headless).
  Acceptance criteria:
  - `pwsh AxmolFighter-Client/TestsHeadless/run_headless_tests.ps1` exits 0 with at least 1 passing test case.
  - `pwsh AxmolFighter-Client/TestsHeadless/check_rules.ps1 -Paths core,conf,avatar,render` exits 0.
  QA scenarios:
  - Happy path: the two commands above.
  - Failure path: temporarily write `float x;` in `core/math/__rule_probe.h`; check_rules exits non-zero and prints that line. Delete the file afterwards.
  - Failure path: make a test fail on purpose with `-Filter`; the script exits non-zero. Restore afterwards.
  - Evidence: `.omo/evidence/mugen-rewrite/task-2.md`.
  Commit: Y | Client: `test(mugen): add headless test harness and rule checker`
  Recommended task executor category: unspecified-high

- [x] 3. Remove the old gameplay layer and online mode, keep the client building
  What to do:
  - Delete:
    - `Source/mugen/{GameWord.*,ActorSpawner.*,Components.h,Systems.h}`;
    - the directories `Source/mugen/{component,system,bt,skill,buff,combat,effect,ai,net}/` (including the READMEs in them);
    - `Source/mugen/core/{expr,fsm}/`;
    - `Source/3rd/tinyexpr/` (first confirm with `rg` that no client code still references it);
    - `Source/ui/battle/OnlineBattleMode.*`.
  - Move `Source/mugen/common/TypeConversions.*` into `Source/mugen/conf/`, then delete `common/`.
  - Move `actor_spawner::resolveRoleSpine` into `Source/mugen/avatar/AvatarPaths.*`, which `resource/builtin/RoleSpineHelper.cpp` uses:
    - resolve only `role.resSpineId → res_spine` paths;
    - **drop** the old `/hero/` forced 0.25 scale and the `io::isFileExist` `_city` guess;
    - if the town really needs a city skeleton, write it in the notepad and let todo 16 handle it.
  - Adapt the views:
    - `GameView` and `LocalBattleMode` keep the view skeleton and the "back to town" flow. The battle area shows the placeholder text `Battle is being rebuilt`. Remove all world code.
    - `TownView` keeps its UI and network code. Remove world, movement and remote-player rendering, and show the placeholder text.
    - `DungeonSelectView` keeps working.
    - Remove the online battle path that `BattleBootParams` depends on (the online entries for solo battles and duels): hide the buttons, or in `DuelStartPush` just log `Online battle disabled during rewrite`.
  - Remove the unused `mugen/GameWord.h` include in `MainScene.h`.
  - Delete or adapt files in `render/` that depend on deleted components. Keep the spine backend, `LayerRuntimeLoader`, `VirtualCamera` and `avatar/render`.
  - Re-run configure and build.
  Must NOT do: rewrite `core/ecs` or `core/bt` (that is todos 6/7; they only need to keep compiling); touch the Server repo; delete `avatar/` or `render/spine`.
  Closes: GAP-1..5 (clears the ground)
  Parallelization: W0 | Blocked by: 2 | Blocks: 6, 7, 12
  References:
  - external dependency list: the "What a gameplay rewrite has to keep" section of this plan's research output is summarized as follows:
    - `ui/views/GameView.cpp`, `ui/battle/LocalBattleMode.cpp`, `ui/battle/OnlineBattleMode.cpp`, `ui/battle/BattleMode.h`;
    - `ui/views/TownView.cpp:221-244,254-260,335,424,522-531,563,767,898-941,1020-1094,1153-1179,1288-1295`;
    - `resource/builtin/RoleSpineHelper.cpp`, `ui/input/DefaultInputSlotMap.h`, `MainScene.h:29`.
  - contract §1.
  Acceptance criteria:
  - In `AxmolFighter-Client`, `axmol build -p win32 -c` and `axmol build -p win32` both exit 0.
  - `rg -l "GameWord|BattleNetSync|OnlineBattleMode|ActorSpawner|tinyexpr" AxmolFighter-Client/Source` produces no output.
  - G1 passes; the full `check_rules.ps1` run passes.
  QA scenarios:
  - Happy path: the build passes. Start `AxmolFighter-Client.exe` (working directory Content), wait 10 seconds and close it; it must not crash on startup. Without a login server it stays on the login screen, which is normal.
  - Failure path: grep confirms nothing references the removed symbols.
  - Evidence: `task-3.md`.
  Commit: Y | Client: `refactor(mugen): remove legacy gameplay layer and online battle mode`
  Recommended task executor category: unspecified-high

- [x] 4. core/math: Fixed, FixedVec, FixedMath, Random API
  What to do:
  - Implement everything in contract §2.1–§2.3:
    - `core/math/Fixed.h/.cpp`: Q44.20 representation, operators, `fromInt/fromRaw/ratio`, the `consteval` literal `"..."_fx` (integer parsing, round half up), `floor/ceil/trunc/roundHalfUp/toInt`, and `toFloatForRender`.
    - `FixedVec2/3`.
    - `FixedMath`: integer sqrt, plus `sinDeg/cosDeg/atan2Deg` via table lookup with linear interpolation.
    - `FixedTables.gen.lua` generates `FixedTables.inc`, run with the system `lua`. Commit the generated result.
  - 128-bit multiply/divide:
    - Provide both an intrinsic path (`_mul128/_div128` on MSVC, `__int128` on clang/gcc) and a portable 64-bit-limb implementation.
    - The test target compiles both and compares them.
  - Add `randomF(Fixed,Fixed)` and `randomN(int32,int32)` to `Random`, matching the semantics of the reference project's `GRandomF/GRandomN`. Keep xoshiro256** and splitmix64. Fix the overflow in `nextInt` when the range is very wide.
  - Leave the existing `Vec2/Vec3/DamageBox` untouched; todo 11 deals with them.
  Must NOT do: construct Fixed from a float/double literal or call any libm function in `core/` (only the generator script may use Lua's math); make the representation configurable.
  Closes: GAP-5
  Parallelization: W1 | Blocked by: 2 | Blocks: 5
  References:
  - contract §2;
  - `heiyue/src/util/engine/AEUtilEx.lua:90-110` (FixPoint/Round semantics);
  - the semantics of `AEUtil:GRandomN/GRandomF`: `heiyue/src/util/engine/AEUtilEx.lua:18-60`;
  - `AxmolFighter-Client/Source/mugen/core/math/Random.cpp:17-91`.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Fixed*,*FixedMath*,*Random*"` exits 0. Tests cover at least:
  - multiply/divide sign and truncation direction (including negative numbers and boundary values), with intrinsic == portable over 10k random cases;
  - for `"0.0022"_fx`, `raw == 2307` (round(0.0022·2^20) = 2306.867… → 2307);
  - sqrt exact for perfect squares and monotonic;
  - sin/cos/atan2 error vs the Lua-generated reference values < 2e-4;
  - `randomN` boundaries are closed on both ends and `randomF` is half-open;
  - golden values: the first 16 outputs for seed 12345.
  QA scenarios: happy path, the test filter above. Failure path: a debug-build test where multiplication overflow triggers `MG_ASSERT`; check that the assert macro fires. Evidence: `task-4.md`.
  Commit: Y | Client: `feat(core): add Q44.20 fixed-point math and deterministic random API`
  Recommended task executor category: deep-low

- [x] 5. core/reflect and serialize (additive, old mechanisms kept)
  What to do:
  - Implement contract §3:
    - `core/reflect/Reflect.h`: the `MG_REFLECT` / `MG_REFLECT_DERIVED` macros (up to 128 fields), `kMgTypeName`, type traits, and a `static_assert` that rejects unsupported types.
    - `core/serialize/BinaryArchive.h`: `BinaryWriter/BinaryReader`, implemented on top of the existing `ByteBuffer`.
    - `core/serialize/Hash.h`: an in-house xxh64.
    - `core/reflect/SchemaHash.h`.
  - Fix the 3 `ByteBuffer` bugs listed in contract §3.3 and add regression tests.
  - This todo **only adds**. Do not delete `Object` or `MG_DEFINE_SERIALIZABLE`; `conf/` and `avatar/data` keep using them until todos 10/11.
  Must NOT do: migrate conf/avatar to the new macros (that belongs to 10/11); introduce third-party reflection libraries.
  Closes: GAP-5, GAP-6
  Parallelization: W1 | Blocked by: 4 | Blocks: 6, 7, 9
  References: contract §3; `AxmolFighter-Client/Source/mugen/core/serialize/ByteBuffer.{h,cpp}` (`.cpp:35-46` constructor, `:130` resize, `:457-466` writeString); `core/serialize/SerializableHelper.h` (the old macro, for comparison).
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Reflect*,*Archive*,*Hash*,*ByteBuffer*"` exits 0. Tests cover:
  - round trips of nested struct / vector<vector> / optional / variant / map / Fixed / enum, with re-serialized bytes identical;
  - the same data hashes the same; changing one field changes the hash;
  - adding a field changes the SchemaHash;
  - a `float` field fails to compile, checked with a compile-failure test or a commented example plus a `static_assert` unit test of the trait;
  - regression tests for the 3 ByteBuffer bugs.
  QA scenarios: happy path, the filter above. Failure path: reading truncated data returns false and does not crash. Evidence: `task-5.md`.
  Commit: Y | Client: `feat(core): add MG_REFLECT reflection, binary archive and hashing`
  Recommended task executor category: deep-low

- [x] 6. core/ecs: evolve into Overwatch-style ECS
  What to do:
  - Implement all of contract §4 by rewriting the internals of the existing `core/ecs`:
    - generational entity handles with FIFO slot reuse;
    - `ComponentPool<T>` (sparse + dense);
    - compile-time type ids from `MG_COMPONENT_LIST(X)` (provide a test-only component list);
    - singletons via `MG_SINGLETON_LIST(X)`;
    - `each<Ts...>` iterates in creation order, with the upper bound fixed when iteration starts;
    - deferred destruction with `flushDestroyed`;
    - `serialize/deserialize/clone/hash`.
  - Delete the old `Entity` object, string lookups, `printf` logging, `isReady/isDeserialized`, and the `MG_GET_COMPONENT` macro.
  Must NOT do: give components virtual functions or pointers; use unordered containers; implement any gameplay.
  Closes: GAP-5
  Parallelization: W1 | Blocked by: 3, 5 | Blocks: 12
  References: contract §4, §7.1 (traversal semantics); `heiyue/src/module/entity/EntityManager.lua:229-260` (the semantics of a fixed upper bound and in-place removal during traversal); `Reference/heiyue-战斗逻辑.md` §1.1.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Ecs*"` exits 0. Tests cover:
  - a stale handle is unreadable after create/destroy, and a new handle reuses the slot with generation + 1;
  - entities created during traversal are not traversed in the same frame;
  - entities marked for destruction during traversal disappear after flush;
  - after serialize → deserialize → serialize the bytes are identical;
  - `clone()` is independent of the original;
  - hash is stable;
  - 10k entities × 3 components, 1000 iterations take < 50 ms in Release. Record the number; it is a reference, not a hard gate.
  QA scenarios: happy path, the filter above. Failure path: `get<T>` on a missing component asserts, and `tryGet` returns null. Evidence: `task-6.md`.
  Commit: Y | Client: `refactor(core): rewrite ecs as data-only pools with deterministic snapshots`
  Recommended task executor category: deep-high

- [x] 7. core/bt: split definition from instance
  What to do:
  - Implement contract §5: `BTDef`, `BTInstance<LeafState>`, `BTRunner`, `BTRegistry` and `BTDefCache`.
  - Port the algorithms line by line from the existing `core/bt/BTSelector.cpp`, `BTSequence.cpp`, `BTParallel.cpp` and `BTComposite.cpp`, with these changes:
    - the exit order of contract §5.2.6;
    - a Selector child returning Failure only logs a warning;
    - the root does not restart automatically.
  - Delete the old node object classes and `BTFactory`.
  - Write a test for each of rules 1–9 in contract §5.2. Include an assertion on the call-order log for enter/exit/check, compared against the C++ AEBT in the reference project.
  Must NOT do: add preemption or decorators; change the success-on-guard-failure semantics.
  Closes: GAP-5
  Parallelization: W1 | Blocked by: 3, 5 | Blocks: 12
  References:
  - contract §5;
  - the existing `AxmolFighter-Client/Source/mugen/core/bt/*.cpp`, read in full before deleting;
  - `heiyue/frameworks/runtime-src/Classes/external/behavior/default/` (AEBTSelector/Sequence/Parallel/Composite/Action/Condition .cpp);
  - `Reference/heiyue-AI与行为树.md` §A.1–A.3.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*BT*"` exits 0, with at least 12 test cases. A BTInstance clone or serialize round trip followed by a continued tick produces exactly the same call log as the original.
  QA scenarios: happy path, the filter above. Failure path: a Sequence child returning Failure keeps the parent Running (same as the reference). Evidence: `task-7.md`.
  Commit: Y | Client: `refactor(core): split behavior tree into shared definitions and value instances`
  Recommended task executor category: deep-high

- [x] 8. Extend the import step: add missing tables, merge split tables, fix field names (Lua side only)
  What to do:
  - Edit `AxmolFighter-Tools/config_converter/script/migrate/import/TableConvert.lua` (`KIND_SPECS`) and `run_table_convert.lua` (kind lists):
    - `effect`: merge `entity_effect` and `entity_effect2` (id ≥ 2000000). Duplicate ids are an error.
    - `action_effect`: regenerate from `action_attack_effect` and `action_attack_effect2` and merge into one kind. Delete `AxmolFighter-Config/table/action_effect2.lua`. Normalize all fields to camelCase and rename `acitonScaleTime` to `actionScaleTime`.
    - New kinds: `special_ability` (specialability_base), `skill_rock`, `skill_change_system`, `obstacle` (entity_obstacle), `goods` (entity_goods).
    - Read `EntityRole:loadAttribute` (`heiyue/src/module/entity/EntityRole.lua:816`) to decide whether battle attributes depend on `attribute_change`. If they do, add the `attribute_change` kind. Record the decision in decisions.md.
    - Remove the derived field `skill.primaryActionIds`. Keep `room.monsterDropGoods` and `stage.mapCsb`.
    - Keep the source shape of every value: nested arrays stay nested, and decimals are not truncated. Strings such as `action.action` stay strings.
    - In equip/fashion, check that every row has a field that distinguishes occupation (class), so todo 10 can key rows by (id, occupation). If the field is missing, generate it from the occupation source file name.
  - Fix `validate_table_output.lua`, which errors on equip/fashion when `spec.source` is nil, and add count checks for the new kinds.
  - Run the full import and regenerate the `AxmolFighter-Config/table/*.lua` files.
  Must NOT do: hand-edit the generated tables; modify any C++; modify `heiyue/`.
  Closes: GAP-6 (data side)
  Parallelization: W0/W1 | Blocked by: 1 | Blocks: 10
  References:
  - `Reference/heiyue-战斗配置.md` §0 (file format, accessors), §1.6–1.7, §2.2, §3.4, §4.2, §4.5, §4.6, §9;
  - `AxmolFighter-Tools/config_converter/docs/table-kind-mapping.md`;
  - `AxmolFighter-Tools/config_converter/README.md`;
  - `heiyue/src/db/DBEntity.lua:3-13`, `heiyue/src/db/DBSkill.lua:3-10`, `heiyue/src/db/DBAction.lua:3-7`.
  Acceptance criteria:
  - The import command exits 0. In `task-8.md`, list the source row count next to the Config row count for each battle kind; they must be equal (effect = number of unique ids in entity_effect + entity_effect2; action_effect likewise).
  - `rg -c "acitonScaleTime|primaryActionIds" AxmolFighter-Config/table` produces no output.
  - `lua script/migrate/import/validate_table_output.lua --all` (check the exact arguments yourself) exits 0.
  QA scenarios:
  - Happy path: the commands above.
  - Failure path: point `--src` at an empty directory; the import must report a readable error and exit non-zero.
  - Evidence: `task-8.md`.
  Commit: Y | Tools: `feat(config): import missing combat tables and merge split tables`; Config: `data: regenerate tables with merged effect/action_effect and new combat kinds`
  Recommended task executor category: unspecified-high

- [x] 9. Pure C++ config converter skeleton: LuaReader, strict validation, scaffold
  What to do:
  - Rebuild `AxmolFighter-Tools/config_converter/CMakeLists.txt`:
    - Keep `lua_static` and the spine static libraries (todo 11 uses them).
    - Remove `mugen_tolua`, `sol`, `lua-cjson` (if no longer used) and `OLUA_AUTOCONF`.
    - Compile `Client/Source/mugen/{core,conf,avatar/data}`, with C++20.
  - Rewrite `main.cpp` as a subcommand CLI:
    - `pack <ConfigDir> <ContentDir>`
    - `scaffold <ConfigDir> <kind>`
    - `verify <ContentDir>`
    - Todo 11 adds `pack-avatar` and `spine-box`.
  - Implement `LuaReader` (a reflection visitor) following contract §6.3:
    - exact two-way field matching;
    - int/Fixed/string/bool/enum/vector/array/nested-struct rules;
    - error paths in the form `kind[id=...].field[i]`;
    - errors are collected and printed together, then the program exits non-zero.
  - `scaffold`: scan every row, infer field types (int / Fixed / string / bool / array depth / nested table → sub-struct draft), and print a draft struct that carries `MG_REFLECT`.
  - Write the file header of contract §6.3 (magic/version/schemaHash).
  - In this todo, only **skill** and **skill_hit** are fully wired, as a demo:
    - create `conf/tables/SkillTables.h`;
    - create the first version of `conf/ConfigTables.h` and a new runtime `Config` (it may live alongside the old one and become a full replacement in todo 10).
  - Add `config_converter/testdata/` bad tables (wrong type, extra field, missing field, duplicate id, decimal written into an int) with expected error snippets. Add a `selftest` subcommand that runs these cases.
  - Rename or rewrite `run_config_converter.ps1` so it calls the new CLI, and keep the `--skip-configure` argument.
  Must NOT do: delete the old Lua scripts or sol-related directories yet (todo 11 deletes them; the old config.bin stays usable for now); change the shape of Config tables.
  Closes: GAP-6
  Parallelization: W1 | Blocked by: 5 | Blocks: 10
  References: contract §3, §6; `AxmolFighter-Tools/config_converter/{main.cpp,CMakeLists.txt,run_config_converter.ps1}`; `AxmolFighter-Tools/config_converter/script/migrate/convert/TableConfigsConvert.lua` (field-mapping reference for the old converter; reading only); `Reference/heiyue-战斗配置.md` §1.1, §1.2.
  Acceptance criteria:
  - `config_converter selftest` exits 0 and every bad table produces its expected error.
  - `config_converter scaffold <Config> skill` prints a draft that contains all fields.
  - When packing skill/skill_hit, row counts equal the Lua tables, and loading them in the headless test lets you look up `skill 920000`.
  QA scenarios: happy path, the commands above. Failure path, the selftest cases. Evidence: `task-9.md`.
  Commit: Y | Tools: `feat(config): pure C++ lua table reader with strict schema validation`; Client: `feat(conf): reflected skill tables and new Config runtime`
  Recommended task executor category: deep-low

- [x] 10. All config tables become reflected structs; runtime Config; repack config.bin
  What to do:
  - For every Config kind (all files under `AxmolFighter-Config/table/` after todo 8):
    - Use the `scaffold` draft as a starting point and hand-write the reflected structs into `conf/tables/*.h`, split by domain: Skill / Action / Entity / Buff / Ai / Map / Sound / Equip / Fashion / Item.
    - Name and comment fields per `Reference/heiyue-战斗配置.md` (Chinese comments are fine; never mention the product name).
    - Enum fields use enums from `GameDef.h`.
    - Every value that can be a decimal is `Fixed`.
    - `equip`/`fashion` use a composite key (id, occupation).
  - Complete `ConfigTables.h` and `ConfigRefs.h`. Declare the combat main chain per contract §6.3; a dangling reference on it is a hard error.
  - `conf/BattleConst.h`:
    - Extract combat constants from `heiyue/src/imports/Const.lua` and `heiyue/src/imports/ConstBusiness.lua` (e.g. `ROOM_STATE_INTERNAL` is at `ConstBusiness.lua:1104`): GRAVITY, ZRATE, BOUNCES, WALK_RATE, RUN_RATE, the MP_INCREASE family, CRAZY_FROM_HURT_VALUE, SKILL_HURT_DEFAULT_ADDITION, ROLE_*_WAKE_BUFF_ID, the protection buff ids, ROOM_STATE_INTERNAL, ROLE_DEATH_TIME, CHANGE_TARGET_TIME, JOYSTICK_WAIT_TIME, and others.
    - Only read the lines you actually need, located with `rg -n`.
    - Every constant carries a comment with its source key name.
  - `conf/GameDef.h`:
    - `EntityRoleStatus` bits (`EntityRole.lua:1770-1950` / `GlobalBusinessEnum`);
    - ExtraState;
    - BFEvent (`BuffPool.lua:2-75`);
    - ControlEvent CTR_* (`EntityManager.lua:69-99`, `ControlManager.lua:122-240`);
    - EnumSkillSlot / EntitySkillGroup (`GlobalBusinessEnum.lua:552-590`, `SkillPool.lua:10-22`);
    - room states (`GlobalBusinessEnum.lua:152-191`);
    - EnumBattleRule;
    - role_type;
    - camps and hostile camps.
  - Rewrite the runtime `Config` per contract §6.4, delete the old `TableConfig.h` / `Config.cpp` implementation, and update every client user:
    - `ui/views/*`, `ui/UiConfig.*`;
    - `resource/builtin/BuiltinLoaders.cpp`, `resource/*`;
    - `avatar/FashionResolver.*`, `avatar/AvatarPaths.*`.
  - Move the old smoke checks (town 41, copy 102 → stage 40102, …) into `config_converter verify`, add structural checks, and run `pack`.
  Must NOT do: hand-edit Config tables to get past validation; when data is wrong, fix the import step (amend the todo 8 scripts and regenerate); keep the old structs alongside the new ones.
  Closes: GAP-6
  Parallelization: W1 | Blocked by: 8, 9 | Blocks: 11
  References: `Reference/heiyue-战斗配置.md` (whole document, by section); contract §6; `AxmolFighter-Client/Source/mugen/conf/{TableConfig.h,Config.h,Config.cpp,GameDef.h}` (old definitions; field meanings for reference only).
  Acceptance criteria:
  - `run_config_converter.ps1` exits 0. The pack report lists each table's row count (equal to the Lua tables) and dangling references (combat main chain = 0).
  - `config_converter verify AxmolFighter-Client/Content` exits 0.
  - G1, G2 and G3 pass.
  - The headless test `ConfigLoad` loads the real config.bin and checks a few known rows: skill 920000 → action chain; effect id ≥ 2000000 can be found; buff_rule className is non-empty.
  QA scenarios:
  - Happy path: the commands above.
  - Failure path: temporarily change a skill.lua row's `cd` to `0.5`; pack reports `skill[id=…].cd` and exits non-zero. Restore it afterwards.
  - Failure path: change the schema and leave config.bin unchanged; the runtime refuses to load it and logs `schema mismatch`.
  - Evidence: `task-10.md`.
  Commit: Y | Client: `feat(conf): reflected config tables for all kinds`; Tools: `feat(config): pack all kinds with reference checks`; Content: `data: regenerate config.bin`
  Recommended task executor category: deep-high

- [x] 11. Migrate avatar data to reflection; pack avatar.bin in C++; spine-box export in C++; delete legacy mechanisms
  What to do:
  - Convert these to plain reflected structs (no longer inheriting Object):
    - `avatar/data/{CombatTimeline,MotionMap,AniData,AvatarAssetCache}`;
    - `avatar/MotionPlayer`;
    - `core/math/DamageBox` (integer pos/size; keep the depth field y).
  - Delete `core/math/Vec2.*/Vec3.*` (replace with integer or Fixed vectors), `core/Object.*` and `core/serialize/SerializableHelper.h`; remove all `MG_DEFINE_SERIALIZABLE*`.
  - Converter additions:
    - `pack-avatar`: scan `.box/.motion/.ani` under Content (including `res_zhcn`), parse them with avatar/data's own parser, and write `avatar.bin` (with a header and schemaHash).
    - Port the existing spine-box export (the logic in `script/migrate/SpineBoxMigrate.lua`) to C++ subcommands `spine-box` and `spine-box-list`.
    - Update `run_spine_box_batch.ps1`.
    - **Add a non-rectangular polygon report**: in `spine_box_export/SpineBoxExport34.cpp` `sampleSlotAabb` and the spine-cpp version, count bounding boxes that have ≠ 4 vertices or are not axis-aligned, and print a summary.
  - Delete the old Lua pack scripts:
    - `script/{main.lua,migrate.lua,ConvertHelper.lua,Helper.lua,functions.lua}`;
    - `script/migrate/{BinaryMigrate,AvatarAssetMigrate,SpineBoxMigrate,PathRewrite,PathUtil,Json}.lua`;
    - `script/migrate/convert/`.
    - Keep `script/migrate/import/` (still the Import stage).
  - Remove the converter's dependency on `AxmolFighter-Tools/sol_binding` and `3rd/mugen_tolua`:
    - Delete `sol_binding/` and `3rd/mugen_tolua/`. `3rd/` is normally "do not modify", but here this is an **explicit, approved deletion**; record it in decisions.md.
    - Then grep to confirm nothing references them.
  - Delete `logs_pack.txt` and `script/migrate/import/_export_all.log` from version control.
  - Repack avatar.bin and update the client's `AvatarAssetCache` load path.
  Must NOT do: change the JSON formats of `.box/.motion` (the Editor depends on them); change the Avatar rendering logic.
  Closes: GAP-6, GAP-8
  Parallelization: W1 | Blocked by: 10 | Blocks: 12
  References: `AxmolFighter-Client/Source/mugen/avatar/data/*`, `avatar/MotionPlayer.*`, `core/math/DamageBox.h`; `AxmolFighter-Tools/config_converter/spine_box_export/*`, `script/migrate/{SpineBoxMigrate,AvatarAssetMigrate}.lua`; `AxmolFighter-Tools/AGENTS.md`; contract §3, §8.3.
  Acceptance criteria:
  - `rg -n "MG_DEFINE_SERIALIZABLE|class .*: public Object|mugen_tolua|sol::" AxmolFighter-Client/Source AxmolFighter-Tools --glob "!**/3rd/lua/**"` produces no output.
  - `config_converter pack-avatar` produces avatar.bin, and the headless test `AvatarAssetLoad` looks up the `rw_newzhujue_lilimu.motion` clip and its box timeline.
  - Running `spine-box` on one hero skeleton outputs .box files byte-identical to the existing ones, aside from formatting, and prints the polygon report.
  - G1–G3 pass.
  QA scenarios:
  - Happy path: the commands above.
  - Happy path: start the client, enter the character select screen, and the UI avatar preview works (record it).
  - Failure path: when an avatar.bin schema mismatch is detected, log the error and refuse to load.
  - Evidence: `task-11.md`, including the polygon report.
  Commit: Y | Client: `refactor(mugen): drop Object serialization, reflect avatar data`; Tools: `feat(config): C++ avatar.bin packing and spine box export, remove lua pack`; Content: `data: regenerate avatar.bin`
  Recommended task executor category: deep-low

- [x] 12. sim/World infrastructure: tick pipeline, input, events, timers, snapshots, CLI, scenario harness
  What to do:
  - `sim/World.{h,cpp}`:
    - `init(WorldSetup{seed, mode: Battle|Town, roomId/mapKey})`, `tick(const FrameInput&)`;
    - `serialize/deserialize/clone/hash`;
    - the tick pipeline of contract §7.1. Each group's update hooks into a function table; for now it is empty or minimal.
  - `sim/Components.h` / `sim/Singletons.h` (contract §4.2). Singletons: `WorldClock`, `RngState`, `SlowMotion`, `LogicTimers`, `PresentationEvents`, `PlayerSlots`, plus placeholders `MapRegion` and `RoomState`.
  - `sim/input/`: `PlayerCommand`, `FrameInput` (with `systemCommands`: Revive, Pause and other non-character commands; town `puppetUpdates`), and the `ControlEventQueue` component.
  - `sim/event/`: a variant of `PresentationEvent` keyed by `(frame, entity, seq)`.
  - `LogicTimers`: variant payload plus a `switch` dispatch. Mirrors the semantics of `REGLOGICTIMER` / `LogicTimerTrigger`, including fixed-point accumulation.
  - `EntityGroup` component, and the group order and "remove in place" semantics of contract §7.1 (`EntityManager.lua:229-436`).
  - Replay format `.mgrp`: magic, version, config schemaHash, seed, WorldSetup, then the FrameInput sequence.
  - `mugen_sim_cli`: `replay <file> [--hash-every N]`, `run-room <roomId> --frames N [--script file]`.
  - `TestsHeadless/support/ScenarioHarness.{h,cpp}`: loads the real config.bin/avatar.bin, creates a World, injects commands per frame, and offers assertion helpers.
  Must NOT do: implement any character gameplay (todo 13 onward); use `std::function` for timers or events.
  Closes: GAP-5, GAP-8
  Parallelization: W2 | Blocked by: 6, 7, 11 | Blocks: 13
  References: contract §4, §7.1, §7.4, §7.5, §10.1; `Reference/heiyue-结构.md` §4 (frame loop); `Reference/heiyue-战斗逻辑.md` §1, §13.2; `heiyue/src/trigger/LogicTimerTrigger.lua:1-60`; `heiyue/src/module/sync/SyncManager.lua:278-330,359-420` (input format and the order a frame is executed in).
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*World*,*Timer*,*Replay*"` exits 0. Covers:
  - an empty world ticked 1000 frames twice gives identical per-frame hashes;
  - snapshot at frame 500 → restore into a new World → continue to 1000, and the hash equals an uninterrupted run;
  - a clone run separately gives the same hash;
  - timers fire exactly on frame N;
  - event seq increments.
  `mugen_sim_cli run-room 30002 --frames 10` exits 0 (an empty room is fine).
  QA scenarios: happy path, the commands above. Failure path: a replay whose schemaHash does not match is rejected with a readable error. Evidence: `task-12.md`.
  Commit: Y | Client: `feat(sim): world tick pipeline, inputs, timers, presentation events, replay`
  Recommended task executor category: deep-high

- [x] 13. Character foundations: spawning, attributes, status bits, extra states, map region, motion and hitbox sampling
  What to do:
  - `sim/spawn/`: `spawnRole(World&, RoleSpawnParams{roleId, camp, level, aiDifficulty, position, toward, playerSlot?, isAi})`.
    - Order follows `EntityRole:init` (`EntityRole.lua:536-727`): getAIData (`:836-873`), camp and hostile camp, initial fields, timeRage.
    - Then `load` / `loadAttribute` (`:816,883`): the attribute curve and the entity_attribute segment base address plus level interpolation (`Reference/heiyue-战斗配置.md` §4.4).
    - Monster parameters follow `FightScene:handleLoadMonster` (`scene/FightScene.lua:566-604`).
    - For players the role comes from occupation, and the level is a spawn parameter.
  - Components:
    - `RoleIdentity`, `RoleStatus` (`eEntityStatus` + `entityParams`: hit_id, hit_counts, move_pos, displacement_id, death_displacement_id);
    - `ExtraState` (8 states with ref counts, `EntityExtraState.lua:3-145`);
    - `Attributes` (basic / overlay / extend 100–115, `EntityAttribute.lua:4-23,243-330`), `Vitals` (hp/mp/ep/maxima);
    - `Transform` (FixedVec3 position, towardX, vectorX/Z, scale);
    - `MotionState`: wraps MotionPlayer. Switch its time to Fixed ms; actionScale scales dt.
    - `ColliderState` (sampled world boxes, registration frame, radius);
    - freeze/static timers; rigidity/weight/fatigue/hitCounts/stiffTime.
  - Status functions: `dealWithStatus` / `mixStatus` / `abortStatus` / `isXxxStatus` and its combinations (`EntityRole.lua:1770-1950,2055-2123`; `EntityBase.lua:789-795`).
  - `MapRegion` singleton: built from the `.layer` `moveRange` (`conf/LayerLoader`), converted to Fixed. Provides the boundary queries the displacement code needs (read how `ComponentDisplacement.lua` calls MapRegion).
  - Character per-frame pipeline skeleton (contract §7.2). Implement in this todo:
    - MP regen (`EntityRole.lua:1090-1092`);
    - the freeze/static timers (`:2436,2441`);
    - the EntityBase freeze/static short-circuit (`EntityBase.lua:167-190`);
    - hitbox sampling in the component stage (contract §8.1; Fixed version of `DamageBoxTransform`).
    - Other steps are left as named empty functions; later todos fill them in.
  Must NOT do: create a second state source (e.g. currentKind); implement skills, AI or displacement.
  Closes: GAP-1, GAP-3 (foundation)
  Parallelization: W2 | Blocked by: 12 | Blocks: 14, 15, 21
  References: `Reference/heiyue-战斗逻辑.md` §1.2, §3, §4; `Reference/heiyue-战斗配置.md` §4.1, §4.3, §4.4, §7; contract §7.2–§7.4, §8.1; `AxmolFighter-Client/Source/mugen/avatar/DamageBoxTransform.h`.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Spawn*,*Status*,*Attribute*,*Collider*"` exits 0.
  - Golden: `TestsHeadless/golden/attribute_golden.lua` loads the Config tables, computes attributes for 3 roles at 2 levels each using the `loadAttribute` formula, and writes expected values. The C++ results must match (integers exact; Fixed error < 1e-4).
  - Status-rule tests: Walk is refused while in Attack; Hit resets to Idle|Hit; Death is terminal.
  - Hitbox mirroring: the box flips when towardX = -1.
  QA scenarios: happy path, the filter above. Failure path: an invalid roleId asserts in Debug with an English message. Evidence: `task-13.md`.
  Commit: Y | Client: `feat(sim): role spawning, attributes, status bits, extra states, map region`
  Recommended task executor category: deep-high

- [x] 14. Displacement, ROLE/CITY tree templates, movement leaves
  What to do:
  - `sim/motion/Displacement`: a faithful port of `ComponentDisplacement.lua:144-291` (`updateLogicDisplacement`), `:394-601` (calculateVelocity/Gravity/Displacement, setDisplacementData, tracking), and the event detection, including:
    - trapezoidal integration;
    - `velocity_time` -1/0 semantics;
    - gravity `GRAVITY` and bounce `BOUNCES`;
    - multiplying depth by `ZRATE`;
    - wall probing in axis order by displacement size, using the radius;
    - the VelocityScale of the cannot-move state;
    - the events brake/air/floor/lie/left/right/top/bottom;
    - the default correction when a leaf returns "handled";
    - trace displacement (`findTargetInSector`).
  - Event callback: through `BTRegistry` each leaf type registers `onDisplacementEvent` (a function pointer), which returns handled.
  - ROLE tree template: the 19 branches of `heiyue/src/imports/ConstBehaviorTree.lua:264-369`, including the conditions. The Attack selector (index 9) is left as a mount point for todo 18. CITY_ROLE template: `:532-548`.
  - Conditions: all the status conditions this tree needs (ConditionDeath/Revive/Wake/GetUp/Hit*/RoleAttack/Jostled/Patrol/Chase/Alert/PathFinding/Run/Walk/RoleIdle/Controlled), including the abortStatus in `exit`. Read each `conditions/Condition*.lua`.
  - Leaves in this todo:
    - `ActionBase` common parts (fTime ms accumulation, ActionType animation-name mapping `ActionBase.lua:11-38,57-150`, the BEHAVIOR_STATE_START/END hooks — calls declared, implemented in 24);
    - `ActionIdle`, `ActionWalk`, `ActionRun` (`ActionWalk.lua:43-48`, `ActionRun.lua:43-48`; footstep sounds become presentation events).
    - All other leaves temporarily register as `kUnimplementedLeaf`.
  - The movement part of `EntityRole:dealWithEvent` (`EntityRole.lua:2131-2187`): the Run/Walk events and Idle on release. Attack events go to a skill entry point (an empty function, implemented in 17).
  Must NOT do: force the tree to exit or add preemption; implement attack/hit leaves.
  Closes: GAP-1, GAP-5
  Parallelization: W2 | Blocked by: 13 | Blocks: 16, 17
  References: `Reference/heiyue-战斗逻辑.md` §1.2, §5.1, §12; `Reference/heiyue-AI与行为树.md` §A.5, §A.6, §A.8; contract §5.2-9, §7.3.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Displacement*,*RoleTree*,*Locomotion*"` exits 0.
  - Golden: `golden/displacement_golden.lua` copies the integration formulas from `updateLogicDisplacement` and records the per-frame position/velocity sequences for 3 displacement ids (one horizontal, one launch with bounce, one deceleration). C++ must match within 1e-3 per frame.
  - Scenario: run right for 30 frames and x increases by the expected amount; stop when hitting the map edge.
  - Scenario: after releasing input, the BT path returns to Idle.
  QA scenarios: happy path, the filter above. Failure path: an entity with VelocityScale = 0 still falls to the ground on the y axis. Evidence: `task-14.md`.
  Commit: Y | Client: `feat(sim): displacement port, role/city tree templates, locomotion leaves`
  Recommended task executor category: deep-high

- [x] 15. Presentation layer and local driver: Presenter, LocalBattleMode, ControlManager, debug panel, offline entry
  What to do:
  - `Source/mugen/render/battle/` (contract §9.1):
    - `WorldPresenter`;
    - `AvatarPresenter`: drives `Avatar` from MotionState with setMotion + seek, and interpolates position between logic frames;
    - `MapPresenter` (LayerRuntimeLoader + VirtualCamera);
    - `CameraDirector` (follow, shake from `action_camera`, display-spine events, slow-motion display);
    - `SoundPlayer` (with its own RNG), `HurtNumber`, `DebugDraw` (2D boxes, depth radius, map region).
  - `Source/ui/battle/`:
    - `LocalBattleMode`: fixed-step accumulator, at most 4 frames of catch-up, optional replay recording.
    - `ControlManager`: keyboard → CTR events, ported from `heiyue/src/module/touch/ControlManager.lua`:
      - joystick quantization and quadrant/angle;
      - the KeyCodeAttack mapping (`:122-139`), held basic attack repeating via `fAttackInterval` (`:419-480`);
      - joystick combo recognition (`:141-240,711-802`) and `JOYSTICK_WAIT_TIME`.
    - `BattleDebugPanel` (ImGui):
      - reflection inspector;
      - the BT path currently running;
      - world hash;
      - pause / single-step / level / room / spawn monster.
  - Adapt `GameView` and `DungeonSelectView`. Delete `ui/input/DefaultInputSlotMap.h` and use the new mapping.
  - Offline entry point: the command-line arguments `--offline-room=<roomId>`, `--offline-role=<roleId|class>`, `--autotest-frames=N`.
    - Skip login and go straight to GameView. Logs are in English.
    - Once N frames have run, print `world hash <frame> <hex>` and exit 0.
    - Find the launch argument parsing in `AppDelegate`/`MainScene`.
  Must NOT do: have the Presenter or UI write sim state (anything except FrameInput); consume the sim RNG; call into the sim layer from render code to change game logic.
  Closes: GAP-8, IS-1 (operability)
  Parallelization: W2 | Blocked by: 13 | Blocks: 16
  References: contract §9; `AxmolFighter-Client/Source/ui/views/GameView.cpp`, `ui/views/DungeonSelectView.cpp:67-102`; `Source/mugen/render/{LayerRuntimeLoader,VirtualCamera,RenderObjectPool}.*`; `Source/mugen/avatar/render/Avatar.h`; `Reference/heiyue-战斗逻辑.md` §5.1; `Reference/heiyue-战斗配置.md` §8.
  Acceptance criteria:
  - G1–G3 pass.
  - `AxmolFighter-Client.exe --offline-room=30002 --autotest-frames=300` (working directory Content) exits 0 and its output contains `world hash 300`.
  - Two runs print the same hash.
  - The headless test `ControlManagerTest` (if ControlManager has no engine dependency, move it under `sim/input/` or write a pure-logic core for it): the combo sequence → CTR_JOYn; holding basic attack produces the expected number of CTR_ATKA per frame.
  QA scenarios:
  - Happy path: the commands above.
  - Happy path: write `.omo/evidence/milestones/M1-draft.md` (manual steps: start offline, WASD to walk, Shift to run, the debug panel shows the hash).
  - Failure path: `--offline-room=999999` logs `Room not found` and exits non-zero.
  - Evidence: `task-15.md`.
  Commit: Y | Client: `feat(render,ui): battle presenters, local fixed-step mode, control manager, offline entry`
  Recommended task executor category: unspecified-high

- [x] 16. Town adaptation (CITY mode, remote players as puppets) — milestone M1
  What to do:
  - `TownView` uses `World(mode=Town)`:
    - the local player is driven by ControlManager movement;
    - remote players are puppet entities (Puppet component, no AI and no skills), driven by `FrameInput.puppetUpdates` (position, facing, motion name);
    - the network `PlayerState.state` carries the motion name of the local entity's MotionState.
  - Hand portal nodes over to MapPresenter (previously `GameMapRenderComponent.entityNode`).
  - If the town needs the city skeleton (the old `_city` guess), resolve it from table data and record the decision.
  - After finishing, the orchestrator writes `.omo/evidence/milestones/M1.md` and pauses to report to the user.
  Must NOT do: have the UI write any Transform/Status component directly; change the town network protocol.
  Closes: GAP-7
  Parallelization: W2 | Blocked by: 14, 15 | Blocks: 17
  References: `AxmolFighter-Client/Source/ui/views/TownView.cpp` (the old version is in git history: `git show HEAD~N:Source/ui/views/TownView.cpp`, compare against the pre-todo-3 version); `Reference/heiyue-AI与行为树.md` §A.6 (CITY_ROLE).
  Acceptance criteria:
  - G1–G3 pass.
  - The headless test `TownPuppetTest`: after a puppet update, the entity position equals the input and the motion name is synced.
  - `M1.md` exists.
  QA scenarios: happy path, `mugen_sim_cli` / the headless town scenario. Manual: log in → town → walk around → enter a dungeon → walk around → go back to town (written in M1.md). Failure path: a puppet update for an entity that does not exist is ignored with a warning. Evidence: `task-16.md`.
  Commit: Y | Client: `feat(ui): town view on sim world with puppet remote players`
  Recommended task executor category: unspecified-high

- [x] 17. SkillPool / SkillBase / SkillAi (data + logic)
  What to do:
  - Component `SkillPool`, value types only:
    - the slot table; slot strings are interned to small integer codes, keeping the original string for debugging;
    - `[slot][slotIndex][mode][step]` flattened into an index table;
    - per-skill `SkillBase` state: cd, ColdMaxTime, release count, bTiming, upTouch, skillTime, pipe, toward, finally, nextSkill index;
    - cursor, previous skill, `fAiSkillCastInterval`;
    - `SkillAi` state: load_cd, check_cd, use_count.
  - Functions, written as free functions in `sim/skill/`, each line-by-line against the reference:
    - `loadSkill`:
      - slot generation, `SkillPool.lua:57-90,650-656`;
      - recursive expansion along `next_skill`, `:770-814`;
      - finally flag, `:689-694`;
      - the player slot mapping `heiyue/src/scene/SceneFactory.lua:2-37,61-170`, including `skill_change_system` expansion;
      - `skill_rock` / joystick slots;
      - monsters take skill groups from entity_ai.
    - `update`: `SkillPool.lua:115-124`, `SkillBase.lua:229`, and `addSkillReleaseCount` `:990`.
    - `dealWithButton`, `:268-353`, covering sprint attack, joystick combos, crazy mode, and resetSkill.
    - `presetSkill`, `:361-432`; `getFightSkill`, `:1016`.
    - `isAllowCastInternal`, `SkillBase.lua:424-478`, with the CD check only when the count is used up and CD > 0 (`:320`).
    - `isPriority` / `isSuperPriority`, `:502/515`; `dealWithNextSkillBase`, `:561`; `dealWithDirection`, `:597`.
    - `castBegan`, `:818`: cooldown, consumption, direction, syncing CD across modes, chained CD.
    - `dealWithCastPipeBegan` / `Ended`, `SkillPool.lua:555/596`.
    - `forcedInterrupt`, `:187` (effect cleanup: interface declared, implemented in 20); `resetSkill`.
    - Crazy mode: `EntityRole.lua:2464` dealWithCrazy, EP drain, AFTER_CRAZY.
    - `SkillAi`: `SkillAi.lua:21-137`, including the one-frame distance tolerance.
  - Attack path in `EntityRole:dealWithEvent`: `dealButtonEvent` (`EntityRole.lua:2359`), `setSkillBase` (`:2828`), event → slot (`EntityManager.lua:69-99`). PVP branches are skipped.
  - BFEvent and SpecialAbility trigger points go through declared `buff::trigger(...)` / `ability::trigger(...)`; todos 24/27 implement them.
  Must NOT do: hard-code skill ids; keep the old "cd=0 lockout" bug; make choices for AI (todo 28).
  Closes: GAP-1
  Parallelization: W3 | Blocked by: 14 | Blocks: 18, 19
  References: `Reference/heiyue-战斗逻辑.md` §5, §6; `Reference/heiyue-战斗配置.md` §1.1, §1.4, §1.6, §1.7, §8; `Reference/heiyue-AI与行为树.md` §A.7, §B.5.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Skill*"` exits 0. Coverage:
  - a cd=0 basic attack can be cast 10 times in a row;
  - the count and CD rules for `cd_count = 3`;
  - A1 → A2 → A3 chaining via presetSkill caching;
  - a different slot with high priority replaces immediately, and with low priority is cached;
  - casting is refused under silence/stun;
  - the SkillAi composition AND/OR rules;
  - `loadSkill` slot count and order equal the golden list generated by `golden/skillpool_golden.lua` for 2 heroes and 2 monsters (slot string, number of steps).
  QA scenarios: happy path, the filter above. Failure path: insufficient MP/EP is refused, and the presentation event "body shake hint" is emitted. Evidence: `task-17.md`.
  Commit: Y | Client: `feat(sim): skill pool, skill casting rules and skill ai gate`
  Recommended task executor category: deep-high

- [x] 18. Attack subtree building and attack conditions
  What to do:
  - Build the subtree as in `SkillPool.lua:672-914`:
    - `createAttackSlotNode`, `createAttackSkillNode`, `createAttackPipeNode`, `createAttackReleaseTypeNode`, `createAttackTowardNode`;
    - mount it on the ROLE tree attack selector (index 9).
  - Include the skill group source in the BTDef key (contract §5.1).
  - Conditions, each read line by line from `heiyue/src/module/behaviortree/conditions/`:
    - `ConditionRoleAttack`: exit runs resetSkill and abortStatus(Attack);
    - `ConditionAttackSlot`, `ConditionAttackSkillStep`;
    - `ConditionAttackPipe`: enter/exit call dealWithCastPipeBegan/Ended;
    - `ConditionAttackVectorIndex`, `ConditionAttackPress`, `ConditionAttackRelease`.
  Must NOT do: rebuild the SlotIndex/Mode layers, which are commented out in the reference (`SkillPool.lua:714-718,742-746`).
  Closes: GAP-1
  Parallelization: W3 | Blocked by: 17 | Blocks: 23
  References: `Reference/heiyue-AI与行为树.md` §A.7; `Reference/heiyue-战斗逻辑.md` §6.1–6.2; contract §5.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*AttackTree*"` exits 0.
  - The BT path for A1 → A2 matches the expected node sequence.
  - For each pipe, castBegan/castEnded each run exactly once.
  - A release-on-lift skill takes the up_action_ids branch when the button is lifted.
  - Two heroes with identical skill groups share the same BTDef (same key, same pointer).
  QA scenarios: happy path, the filter above. Failure path: when the skill cursor matches no slot, the attack branch returns Success and the Attack bit is cleared. Evidence: `task-18.md`.
  Commit: Y | Client: `feat(sim): attack subtree builder and attack conditions`
  Recommended task executor category: deep-low

- [x] 19. AttackRole leaf (including the ActionAttack base class)
  What to do:
  - `ActionAttack`, `heiyue/src/module/behaviortree/actions/ActionAttack.lua:5-275`:
    - animation end and loop count;
    - `onDisplacementEvent` (brake / obstruct 0/1/-1 / floor);
    - `dealWithTime` (`action_delay_time`), `dealWithControl` 0/2/3;
    - shake and sound become presentation events;
    - the exit cleanup of `auto_release == 0` effects (calls the effect module interface).
  - `AttackRole`, `AttackRole.lua:30-610`:
    - enter: control==1 facing, action position/facing `:274-297`, BEFORE_ROLE_SKILL_ACTION, play animation and set time scale, displacement, action buffs, afterimage/bubble/tip presentation events.
    - execute, steps 1–10 in order:
      - the interrupt window `:390-435` and the supreme interrupt `:440-482`;
      - spawning effects per frame `:487-534` (calls `effect::spawnFromRole`, implemented in 20);
      - camera_frame / camera_id arrays;
      - the display-spine event;
      - hit protection `:376`;
      - root (static) `:568-610`.
    - exit `:302-344`.
    - Frame length: `fInterval = 1000*LOGIC_DT/(actionScaleTime × ActionScale)`.
  - Transformation (`dealWithTransformEntity`) is out of scope: log once in English and skip.
  Must NOT do: skip the `>=` comparisons in frame checks or change them to `>`; call rendering directly.
  Closes: GAP-1
  Parallelization: W3 | Blocked by: 17 | Blocks: 20
  References: `Reference/heiyue-战斗逻辑.md` §7, §13.1; `Reference/heiyue-战斗配置.md` §2.1, §2.3; `Reference/heiyue-AI与行为树.md` §A.8.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*AttackRole*"` exits 0.
  - The interrupt window opens on exactly the frame the formula predicts, verified with real config for a given action id.
  - Pressing during the window chains to the next move; not pressing waits until the animation ends plus the delay.
  - control 0 allows free movement; control 2 only turns.
  - static_target 0/1/2 affects the expected entities and durations.
  QA scenarios: happy path, the filter above. Failure path: `loop == -1` ends on the brake event. Evidence: `task-19.md`.
  Commit: Y | Client: `feat(sim): attack role action with interrupt windows, effects timing, static`
  Recommended task executor category: deep-high

- [x] 20. Effect entities: EFFECT tree, AttackEffect, lifecycle — milestone M2
  What to do:
  - `sim/effect/`, following the reference:
    - `EntityEffect:init` (`heiyue/src/module/entity/EntityEffect.lua:62-231`), including sharing the owner's attributes (`:118`, stores the owner Entity);
    - update (`:274-302`), including the freeze timing;
    - the EFFECT tree (`dealWithActionTree`, `:332-346`): `ConditionEffectAttack` + `AttackEffect`×n + `ActionDestroy`;
    - `setCustomPosition` (`:552`), follow, `setSkillInfo`, `extend_role_vec`;
    - auto_release 0/1/2/3, next_effect.
  - `AttackEffect`, `heiyue/src/module/behaviortree/actions/AttackEffect.lua:18-240`:
    - frame length scaled by the caster's ActionScale;
    - flight displacement;
    - child effects;
    - sound chosen by the target's sound_type;
    - summoning goes through the `spawn::summon` interface (implemented in 30; until then log once).
  - `EntityManager:addEffect` (`EntityManager.lua:1094`), no prefetch pool needed.
  - Fill in the `forcedInterrupt` effect cleanup (`SkillPool.lua:205`, match by skill id + caster tag).
  - When done, the orchestrator writes `.omo/evidence/milestones/M2.md` (combos, B/C/D, dodge, crazy mode, joystick combos, effects visible but no hits yet) and pauses to report.
  Must NOT do: implement hit detection (21/22).
  Closes: GAP-1, GAP-3
  Parallelization: W3 | Blocked by: 19 | Blocks: 22
  References: `Reference/heiyue-战斗逻辑.md` §1.3, §7.4, §7.6, §8.4; `Reference/heiyue-战斗配置.md` §2.2, §4.2; `Reference/heiyue-AI与行为树.md` §A.7 (effect tree injection).
  Acceptance criteria:
  - `run_headless_tests.ps1 -Filter "*Effect*"` exits 0: effects spawn on frame effect_frames[i] at the right position (position_type); auto_release 0 is destroyed at action exit; next_effect is created after destruction; follow tracks the caster.
  - G5 offline smoke passes.
  - `M2.md` exists.
  QA scenarios: happy path, the filter above plus the offline smoke. Failure path: an effect whose owner has been destroyed handles its lifecycle the way the reference does. Evidence: `task-20.md`.
  Commit: Y | Client: `feat(sim): effect entities, effect tree and attack effect action`
  Recommended task executor category: deep-high

- [x] 21. Collision: 2D AABB in screen space, depth-radius filter, contact state machine
  What to do:
  - Implement everything in contract §8 under `sim/collision/`:
    - In the component phase, sample `ColliderState`.
    - After all entities have updated, run one collision pass, iterating in creation order.
    - Do the AABB intersection test in the `(x, y+z)` plane, **ignoring** the box depth fields (pos.y/size.y) but keeping them in the data.
    - Depth filter: `|Δz| < r1+r2`.
    - The contact point is the center of the intersection rectangle.
    - Run the None→Began→Continue→End state machine per (collider, other) pair. When a pair leaves the depth range, emit End.
    - Drop collisions in the same frame the collider was registered.
  - Callback dispatch: an effect entity's collision events call `hit::onEffectCollision` (an empty function here; todo 22 implements it). Collisions between a character and an obstacle are dispatched via `obstacle::onCollision` (implemented in 30).
  - Collision filtering (who collides with whom): read `AEColliderFilter.h` and `AECollider.cpp` (C++ in the reference project) to confirm the rules for type, camp and hostile camp. Record the conclusion in decisions.md.
  Must NOT do: delete or reinterpret the box depth fields; introduce a physics engine.
  Closes: GAP-3
  Parallelization: W2/W3 | Blocked by: 13 | Blocks: 22
  References:
  - contract §8
  - `heiyue/src/module/component/ComponentCollision.lua:30-140`
  - `heiyue/frameworks/runtime-src/Classes/external/collision/{AECollision.cpp,AECollider.cpp,AEColliderFilter.h}`
  - `Reference/heiyue-战斗逻辑.md` §8.1
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Collision*"` exits 0. Coverage:
  - boxes overlap but depth exceeds the radius → no event;
  - event order Began→Continue×n→End;
  - same-frame registration is dropped;
  - mirroring when towardX = -1;
  - a box with a very large depth field gives the same result as one with a depth of 0, which proves depth is ignored.
  QA scenarios: Happy path: the filter above. Failure path: a destroyed entity emits End or is cleaned up, and does not crash. Evidence: `task-21.md`.
  Commit: Y | Client: `feat(sim): screen-plane aabb collision with depth radius filter`
  Recommended task executor category: deep-low

- [x] 22. Hit flow and damage: dealWithHitX, damage formula, modifyHp, energy
  What to do:
  - Port all of the following in `sim/hit/`:
    - `EntityEffect:onCollisionEvent` (`EntityEffect.lua:348-394`);
    - `dealWithHitX` (`:721-785`);
    - `skillDodge`/`dealWithDodge` (`EntityRole.lua:2979`);
    - attribute-based dodge (`SkillHurt.lua:227`);
    - `dealWithBeHitBefore` (`:3039-3103`);
    - `dealWithHitBegan` (`:2899`);
    - `dealWithBeHitBegan` (`:3129-3273`, including addition, super armor, freeze for attacker/effect/target and the delayed freeze through LogicTimers, facing, hard-stun time, the chase-hit data in-hit, `forcedInterrupt`, `dealWithStatus(Hit)`);
    - `calculateDamage` (`SkillHurt.lua:42-246`);
    - `modifyHp` and `calcShieldAndHp` (`EntityRole.lua:1482-1578`, including BFChill, BFHealingChange, HpLock, BEFORE_DEATH and the death entry);
    - `checkHurtPermit` (`:2801`);
    - `dealWithBeHitEnded` (`:3291`);
    - `dealWithHitEnded` (`:2932`);
    - hit effects (`EntityEffect.lua:401-452`);
    - `dealBuff`/`debuff`/`buff_all` (`:506-521`);
    - same-camp collisions (`:788-830`);
    - hit interval and count (`:275-278,633-652`).
  - PVP branches: keep the data but do not run them, and do not reproduce the source defect where true damage errors under PVP.
  - Golden test: `TestsHeadless/golden/damage_golden.lua` copies the arithmetic of `SkillHurt:calculateDamage` and replaces the random number with an injected sequence. It generates expected values for ≥ 50 groups of random attribute/hit_id inputs. C++ is fed the same inputs and the same random sequence; after floor, the allowed difference is ±1 (fixed-point vs. double), and the cases that differ by 1 must be ≤ 2%.
  Must NOT do: change the order of random draws (dodge → crit → spread); add a minimum damage.
  Closes: GAP-3
  Parallelization: W4 | Blocked by: 20, 21 | Blocks: 23
  References: `Reference/heiyue-战斗逻辑.md` §8.2–§9.4, §10.1, §13.1; `Reference/heiyue-战斗配置.md` §1.2, §1.3, §4.2, §7, §9.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Hit*,*Damage*,*Hp*"` exits 0. Coverage:
  - the damage golden test;
  - hit_interval = -1 deduplicates per target;
  - when hit_interval > 0, one frame can hit several targets;
  - the shield absorbs damage and breaks;
  - HpLock;
  - BEFORE_DEATH is triggered before death;
  - super armor takes no hard stun;
  - the freeze frame counts for attacker, effect and target match the configuration (including the delay).
  QA scenarios:
  - Happy path: the filter above.
  - Happy path: a scenario where a hero's basic attack hits a monster → the monster's HP drops by the expected amount and it enters Hit.
  - Failure path: an effect with hit_id = -1 does not deal damage.
  - Evidence: `task-22.md`, including the golden comparison table.
  Commit: Y | Client: `feat(sim): hit pipeline, damage formula, hp modification and energy`
  Recommended task executor category: ultrabrain

- [x] 23. Hit-reaction state leaves: Hit / HitSwitch / HitUp / HitDown / HitFloor / GetUp / Wake / Death / Revive — milestone M3
  What to do:
  - Each item below is a line-by-line port from `heiyue/src/module/behaviortree/actions/`:
    - `ActionCanBreakBase` (`:10-34`, breakaway);
    - `ActionHit` (`ActionHit.lua:13-196`);
    - `ActionHitSwitch`, `ActionHitUp`, `ActionHitDown`, `ActionHitFloor`, `ActionGetUp`, `ActionWake`, `ActionControlled`;
    - `ActionDeath`: move the drop logic `:128-186` into the hook that todo 30 implements; the role-death event is converted into a sim event plus a presentation event;
    - `ActionDestroy`, `ActionRevive`.
  - Helpers, per `EntityRole.lua`:
    - `dealWithWeight` (`:2413`);
    - `getStiffTime` (`:1224`);
    - `isRigidity` (`:1762`);
    - hit protection `hitProtectInit`/`updateHitProtectTime`/`dealHitProtectUpdate` (`:4019-4076`).
  - The add calls for protection buffs 154/155/156/173/201 go through the `buff::addEntityBuff` interface. Todo 24 implements it; until then, the call is recorded.
  - Make sure no `kUnimplementedLeaf` remains in the hit-reaction branches of the ROLE tree.
  - When done, the orchestrator writes `.omo/evidence/milestones/M3.md` (you can launch, juggle and kill monsters) and pauses to report.
  Must NOT do: merge states or simplify transitions; add a forced tree exit.
  Closes: GAP-3
  Parallelization: W4 | Blocked by: 18, 22 | Blocks: 24
  References: `Reference/heiyue-战斗逻辑.md` §10; `Reference/heiyue-AI与行为树.md` §A.6, §A.8.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*HitState*"` exits 0. Coverage:
  - a launch combo HitUp→HitDown→HitFloor→GetUp→Wake→Idle, with the frame count of each phase within the expected range;
  - chase hits retarget per hit_type;
  - once rigidity is exhausted, falling speeds up and hard-stun is reduced by fatigue;
  - casting a breakaway skill while in a hit state enters Attack;
  - dying during HitFloor → Death → Destroy.
  - G5 passes.
  QA scenarios: Happy path: the filter above plus the offline smoke. Failure path: hits are ignored during Wake (the invincible window). Evidence: `task-23.md`.
  Commit: Y | Client: `feat(sim): hit reaction state leaves, rigidity, hit protection`
  Recommended task executor category: deep-high

- [x] 24. BuffPool core and BFEvent wiring
  What to do:
  - `sim/buff/`. Data lives in components (instance array, immunity table, CD table, per-rule counters). Port:
    - BFEvent `heiyue/src/module/buff/BuffPool.lua:2-75`;
    - `loadBuffs` `:152`;
    - `addEntityBuff` target dispatch `:316`;
    - `buffCheck` `:369`;
    - `addBuff` `:380-459`: probability / probability_repeat, priority-based stacking and reset;
    - `removeBuff` `:534`, `destroyBuff` / `ByRule` `:557-576`;
    - `addSuperArmorRef` / `addInvincibleRef` `:706-718`;
    - `addBuffForApplicator` `:887-951`;
    - BEHAVIOR_STATE events forwarded to BFAddByState `:609`.
  - `BuffBase` `heiyue/src/module/buff/BuffBase.lua`:
    - `init` `:102-144`, `trigger` `:151-202`, `update` `:217-267` (follow the times/interval table strictly; time unit is seconds);
    - `addRepeat` `:270`, `removeRepeat` `:292`, `reset` `:337-406` (reset_type 0–7, re-enter on id change);
    - `setExecute` `:408`, `exit` `:540`, `onBeginEvent` `:575`, the hooks `:596-618`, `getAttackValue` `:984`.
  - `BuffCondition` `heiyue/src/module/buff/BuffCondition.lua`.
  - DOT: `calculateBuffDamage` (`SkillHurt.lua:82`) + `dealBuffDamage` (`EntityRole.lua:3344`).
  - Rule dispatch: `buff_rule.className` → rule enum, with a function-pointer table for the five hooks. All 161 class names are registered. Unported ones map to `kUnportedRule`, which logs once per buff id with `Buff rule not ported: <name>`.
  - Wire every declared `buff::trigger` / `buff::addEntityBuff` call point across the whole sim (grep for them) and complete any trigger points that are still missing (check the trigger-point list in Reference §11.3).
  - Buff spines and disappear animations become presentation events. A buff with a disappear animation does not wait for the animation in the sim (if the reference waits for the animation before destroying, convert the animation duration from table data into a timer; record that decision).
  - Data audit: write `.omo/evidence/mugen-rewrite/buff-rule-usage.md`. It counts the className of every buff reachable from combat data: role buffIds, action buff_ids, effect buff/buff_all/debuff, room actor_buff_ids, system buffs 154/155/156/173/201, the AddBy/Remove chains, and BossRush excluded. It lists usage counts and gives the porting priority for 25/26.
  Must NOT do: port concrete rules (25/26) beyond SuperArmor, Invincible and Stun, which are used to validate the framework.
  Closes: GAP-3
  Parallelization: W5 | Blocked by: 23 | Blocks: 25, 26, 27, 28
  References: `Reference/heiyue-战斗逻辑.md` §9.2, §11; `Reference/heiyue-战斗配置.md` §3.1, §3.2, §7.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Buff*"` exits 0, covering:
  - the 8 reset_type cases;
  - the 6 times/interval branches;
  - execute_type 1/2/3;
  - immunity / ImmuneDebuff / CD;
  - probability_repeat;
  - remove_repeat_all;
  - binding=1 only responds to the bound skill.
  `buff-rule-usage.md` exists.
  QA scenarios: happy path: the filter above. Failure path: an unknown className fails at config load time (strict). Evidence: `task-24.md`.
  Commit: Y | Client: `feat(sim): buff pool core, buff lifecycle and event triggers`
  Recommended task executor category: deep-high

- [x] 25. Buff rules: xstatus status classes
  What to do:
  - Using `buff-rule-usage.md`, port rules from `heiyue/src/module/buff/xstatus/*.lua` (70 files) one by one into the rule table, highest usage first. Each file maps to one rule implementation.
  - **Every rule referenced by combat data must be ported.** Unreferenced ones may stay `kUnportedRule`, listed in evidence.
  - Extra states go through the ExtraState reference count. Stun calls `forcedInterrupt` and sets speed scale to 0. Taunt (Sneer) exposes a target query for the AI.
  - The orchestrator may split this todo into several parallel subtasks by file list; each subtask must not edit the shared rule registration file at the same time, and registration entries are merged by the orchestrator.
  Must NOT do: alter rule semantics or merge similar rules into a generalized one (unless the Lua implementations are line-for-line identical).
  Closes: GAP-3
  Parallelization: W5 | Blocked by: 24 | Blocks: 29
  References: `Reference/heiyue-战斗逻辑.md` §3.4, §11.1; `heiyue/src/module/buff/xstatus/*.lua` (read only the files assigned to you).
  Acceptance criteria:
  - `run_headless_tests.ps1 -Filter "*BuffStatus*"` exits 0; each status rule family has at least 1 test.
  - `kUnportedRule` referenced by data = 0 (counted by a script and written to evidence).
  QA scenarios: Happy path: the filter above. Failure path: removing a super armor buff with refcount > 1 does not clear super armor. Evidence: `task-25.md`.
  Commit: Y | Client: `feat(sim): port status buff rules`
  Recommended task executor category: deep-low

- [x] 26. Buff rules: xbasic numeric classes
  What to do:
  - Same as 25, applied to `heiyue/src/module/buff/xbasic/*.lua` (91 files: attributes, damage modifiers, shields, CD changes, consumption scaling, AddBy*/Remove*, etc.).
  - Every rule referenced by combat data must be ported.
  - Rules that involve out-of-scope systems (artifacts, rage) map to `kUnportedRule` if they are not referenced by data. If they are referenced, implement them as closely as possible and record the decision.
  - The orchestrator may split this todo into several parallel subtasks.
  Must NOT do: same as 25.
  Closes: GAP-3
  Parallelization: W5 | Blocked by: 24 | Blocks: 29
  References: `Reference/heiyue-战斗逻辑.md` §9.1, §11; `Reference/heiyue-战斗配置.md` §3.2, §7; `heiyue/src/module/buff/xbasic/*.lua` (read only the assigned files).
  Acceptance criteria:
  - `run_headless_tests.ps1 -Filter "*BuffBasic*"` exits 0.
  - Shield, HPLock, damage modifiers, and CD-modifier rules each have a numeric test.
  - `kUnportedRule` referenced by data = 0.
  QA scenarios: Happy path: the filter above. Failure path: with BFChill, healing does not take effect. Evidence: `task-26.md`.
  Commit: Y | Client: `feat(sim): port numeric buff rules`
  Recommended task executor category: deep-low

- [x] 27. Special abilities (SpecialAbilityPool)
  What to do:
  - Port `heiyue/src/module/specialAbility/{SpecialAbilityPool,SpecialAbilityBase,SpecialAbilityCondition}.lua` into `sim/ability/`, with data in components.
  - Wire every `ability::trigger` call point (BEFORE/AFTER_CASTSKILL, AFTER_TOBEHIT, AFTER_HIT, and the like, per the reference).
  - Wire `effect.specialabilityId/specialabilityAllId` and `buff.bindSpecialAbilityId`.
  Must NOT do: implement artifact-specific branches (keep the data, do not execute).
  Closes: GAP-3
  Parallelization: W5 | Blocked by: 24 | Blocks: 29
  References: `Reference/heiyue-战斗配置.md` §3.4; `Reference/heiyue-战斗逻辑.md` §6.2, §8.2, §11.6; `heiyue/src/module/specialAbility/*.lua`.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Ability*"` exits 0 (at least 3 trigger types and 1 condition-check test).
  QA scenarios: Happy path: the filter above. Failure path: when the condition is not met, it does not trigger. Evidence: `task-27.md`.
  Commit: Y | Client: `feat(sim): special abilities`
  Recommended task executor category: deep-low

- [x] 28. Monster AI: behaviac-semantics runtime, Entity.xml decision tree, AiAgent, movement leaves — milestone M5
  What to do:
  - In `sim/ai/`, implement a minimal decision-tree runtime covering the node types used in `heiyue/src/imports/behaviac_exported/Entity.xml`: Selector, Sequence, IfElse, Condition/Method (ResultOption), Assignment, precondition, custom attachment.
  - Semantics follow `AxmolFighter-Client/Source/3rd/behaviac` (vendored 3.6.39). Settle the exact semantics of precondition and `<custom>` Condition(34) by reading the source, record them in decisions.md, and add them to `Reference/heiyue-AI与行为树.md` §B.4.
  - Build the Entity tree by hand in C++ (do not parse XML at runtime). Comments note the XML node ids.
  - AiAgent (`heiyue/src/module/ai/AiAgent.lua:65-749`), monster branch:
    - checkAttack / checkAttackEnd / checkHit / checkHitEnd / checkChase / checkMoveEnd / checkTarget;
    - executeRandAttack("Z") / executeFirstAttack("X") / executeAttack (priority/interval, `:509-565`) / executeChase / executeAlert / executePatrol;
    - calcPos `:670-725`;
    - changeTarget (threat, 10 s) and taunt.
    - The auto-battle branch and moveToDoor are out of scope; skip them and record that.
  - Candidate targets: `findTargetForAI` (`EntityManager.lua:1848-1860`).
  - tick conditions: `EntityRole.lua:1103-1113`.
  - Movement leaves: `ActionMove` base, `ActionPatrol` (calls checkTarget every frame), `ActionChase`, `ActionAlert`, with the dwell time `*_delay_time` randomized by the sim RNG.
  - When done, the orchestrator writes `.omo/evidence/milestones/M4.md` (Buff and special abilities) and `M5.md` (AI) and pauses to report.
  Must NOT do: introduce the behaviac runtime library (only read its source for semantics); invent AI behavior.
  Closes: GAP-2
  Parallelization: W5 | Blocked by: 24 | Blocks: 29
  References: `Reference/heiyue-AI与行为树.md` §B (whole section), §A.8 (ActionMove family); `Reference/heiyue-战斗逻辑.md` §5.5; `Reference/heiyue-战斗配置.md` §1.4, §4.3.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Ai*"` exits 0, covering:
  - with no target in range, it patrols and pauses for the dwell time;
  - after being hit it casts the X slot, then eStatus = Alert;
  - in Alert, out of chase range it chases and stops at `target ± chase_scope[2]`; in range it wanders;
  - slot selection by priority + interval, and same-priority slots reset their intervals together;
  - SkillAi gating takes effect;
  - a taunt forces the target.
  G5 passes.
  QA scenarios: Happy path: the filter above. Manual: a room with monsters, and they behave as in M5.md. Failure path: when the target dies it retargets, and with no target it returns to patrol. Evidence: `task-28.md`.
  Commit: Y | Client: `feat(sim): monster ai decision tree and ai movement actions`
  Recommended task executor category: ultrabrain

- [x] 29. Room flow: state machine, monster spawns, waves, win/lose, KO slow-mo, revive
  What to do:
  - `sim/room/`, with the `RoomState` singleton:
    - `setExpectRoomState` / `updateCheckRoom` (`heiyue/src/scene/GameScene.lua:245,286`, including the `ROOM_STATE_INTERNAL` wait; skip the story hook);
    - each state function in `FightScene` (`heiyue/src/scene/FightScene.lua:1003-1096`).
  - Entering a room:
    - `processData` / `handleFormMonsterData` / `handleLoadMonster` (`FightScene.lua:194,490-604`, including boss flags, AI difficulty, levels, positions and facing);
    - `processRoomBuff` (`:1424`).
  - Per-frame checks:
    - `updateCheckKO` / `checkKO` / `executiveKO` (`:813,1297,1473`). Slow-mo curve from `heiyue/src/module/camera/CameraSlow.lua:25-77`, written into the `SlowMotion` singleton;
    - `updateCheckRoleDeath` (`:847`);
    - `updateCheckResult` (`:879`);
    - `updateCheckTime` (`:946`);
    - `checkWipeOutEnemys` (`:1250`).
  - battle_rule:
    - Clear / Defense / Survive (`heiyue/src/scene/game/PlotScene.lua:81-139,302-315,356,410-451`, `heiyue/src/helper/StageHelper.lua:124-146`).
    - The Defense countdown that used to be driven by the UI moves into the sim timer. Read the countdown duration from `heiyue/src/ui/view/UiFight/UiFightTypePlot.lua:480-500` (`startCounter`).
  - Revive: enters through `FrameInput.systemCommands.Revive`. The revive count comes from copy `max_revive`. Follow `enterReviveState` and `ActionRevive`.
  - Presentation: room state changes / warning / tips / victory / defeat become presentation events. The client shows them with a simple UI (ImGui or a minimal FairyGUI component), and includes "revive" and "back to town" buttons. Buttons only send commands through FrameInput.
  Must NOT do: story, tutorial, rewards/settlement network requests, auto-teleport (the portal part is in 30).
  Closes: GAP-4
  Parallelization: W6 | Blocked by: 25, 26, 27, 28 | Blocks: 30
  References: `Reference/heiyue-战斗逻辑.md` §2, §13.1; `Reference/heiyue-战斗配置.md` §5.2, §5.3, §5.4.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Room*"` exits 0, covering:
  - Clear room: clearing all enemies → Victory;
  - Defense: wave count and countdown;
  - Survive: time up → victory;
  - timeout → Failure;
  - after all bosses die, the KO slow-mo factor matches the curve at given frames;
  - revive count is used up → Failure.
  G5 passes (stage 901 → room 30002).
  QA scenarios: Happy path: the filter above. Failure path: the hero dies with no revives left → Failure event. Evidence: `task-29.md`.
  Commit: Y | Client: `feat(sim,ui): room state machine, monster waves, victory/failure, ko slow motion, revive`
  Recommended task executor category: deep-high

- [x] 30. Portals, room switching, obstacles, drops, summons, jostling — milestone M6
  What to do:
  - Portal entities:
    - `heiyue/src/module/entity/EntityPortal.lua`;
    - PORTAL tree `ConstBehaviorTree.lua:371-422`, implementing only the states the combat flow needs (Close/Active/Transfer) and recording the decision;
    - open after Fight_End;
    - collision triggers `executiveTransfer` (`GameScene.lua:429`, Room type);
    - room switching: `World::changeRoom` keeps the player entity and its state (BufferList semantics, `EntityManager.lua:253-258,416-435`; `FightScene.lua:759` is_pass_room).
  - Obstacles:
    - `EntityObstacle.lua`, OBSTACLE tree `ConstBehaviorTree.lua:424-449`;
    - `dealWithObsturct` (`EntityRole.lua:2024`);
    - the obstacle branch of effect hits on obstacles (`EntityEffect.lua:348-394`).
  - Drops and pickups:
    - `ActionDeath.lua:128-186`, `EntityGoods.lua` (including the `:153` pickup buff);
    - GOODS tree `:469-494`, `ActionSpurt`, `ActionCollect`.
  - Summons:
    - `AttackEffect.lua:171-240`;
    - `dealWithSummon` (`EntityRole.lua:2446`);
    - recursive standHurt to the owner in damage (`SkillHurt.lua:42-67`).
  - `ActionJostled` (pushback from portals).
  - Count `kUnimplementedLeaf` with `rg`: it must be **0**.
  - When done, the orchestrator writes `.omo/evidence/milestones/M6.md` (clear a whole multi-room dungeon locally) and pauses to report.
  Must NOT do: stage/camp transfers that need network requests; pets.
  Closes: GAP-4
  Parallelization: W6 | Blocked by: 29 | Blocks: 31
  References: `Reference/heiyue-战斗逻辑.md` §2.5, §7.6, §12 (obstacle correction); `Reference/heiyue-战斗配置.md` §4.6, §5.3; `Reference/heiyue-AI与行为树.md` §A.6 (other trees), §A.8.
  Acceptance criteria:
  - `run_headless_tests.ps1 -Filter "*Portal*,*Obstacle*,*Goods*,*Summon*"` exits 0, covering:
    - after clearing the room the portal opens, and stepping on it switches rooms with HP/EP/CD carried over;
    - characters are pushed back by obstacles, and destructible obstacles get destroyed;
    - killing a monster drops items, and pickup gives the buff;
    - summons are created at summon_frame and use the owner's standHurt.
  - `rg -c "kUnimplementedLeaf" AxmolFighter-Client/Source/mugen/sim` shows only the definition site.
  - G5 passes.
  QA scenarios: Happy path: a full-run scenario test using a multi-room stage (pick one from the copy/stage tables and record it in evidence) with a scripted input that clears every room. Failure path: a portal still Closed cannot be passed. Evidence: `task-30.md`.
  Commit: Y | Client: `feat(sim): portals and room transfer, obstacles, drops, summons`
  Recommended task executor category: deep-high

- [x] 31. Determinism and golden test suite
  What to do:
  - Replays:
    - Record replays from scenario scripts covering 3 rooms (including AI, buffs, waves and room switching), saved under `TestsHeadless/data/replays/`.
    - Tests:
      - running twice gives identical per-frame hashes;
      - snapshot at frames {1,137,900} → restore into a new World → continue, and hashes match;
      - clone at frame N → run 60 frames → restore the clone → replay, and hashes match;
      - serialization round-trip bytes match.
  - Golden: collect the existing golden scripts (attribute/displacement/damage/skillpool) and add `buff_tick_golden.lua` (the timing of one DOT buff tick).
  - Cross-compiler: if `clang-cl` (VS component) is available, build TestsHeadless with clang-cl and compare its replay hashes against MSVC. If it is not available, record a GAP in issues.md with the command to fill it in later.
  - `mugen_sim_cli replay` gets the `--compare <hashfile>` option.
  Must NOT do: relax the hash comparison to tolerate differences.
  Closes: GAP-5
  Parallelization: W7 | Blocked by: 30 | Blocks: 32
  References: contract §2, §4.2, §10.1; this plan's IS-5.
  Acceptance criteria: `run_headless_tests.ps1 -Filter "*Determinism*,*Golden*"` exits 0. `task-31.md` records the hash sequence summary and the cross-compiler result.
  QA scenarios: Happy path: the filter above. Failure path: deliberately use `std::unordered_map` iteration in a temporary branch or patch so that the order is randomized; the determinism test must detect a hash mismatch. Revert afterwards. Evidence: `task-31.md`.
  Commit: Y | Client: `test(sim): determinism, snapshot/rollback and golden suites`
  Recommended task executor category: deep-low

- [x] 32. Documentation updates
  What to do:
  - Root `README.md`: rewrite the "战斗核心（mugen）" section (layering core/conf/avatar/render/sim, system order replaced by the tick pipeline, behavior tree definition/instance split, snapshots), the "配置流水线" section (drop the wrong HACKER_DATA_INIT statement, the C++ converter, the strict rules, scaffold), the "Avatar 模型" section (AvatarRenderSystem/AvatarComponent → AvatarPresenter/MotionState), and the code conventions section. Make sure there are no references to the `.omo` path.
  - `AxmolFighter-Client/AGENTS.md` (TestsHeadless commands, offline arguments).
  - `Source/mugen/AGENTS.md` (final version).
  - `AxmolFighter-Tools/AGENTS.md`, `config_converter/README.md`, `config_converter/docs/table-kind-mapping.md`.
  - `AxmolFighter-Config/AGENTS.md` (struct-as-schema, strict validation, how to add a new table: scaffold → write struct → register in `MG_CONFIG_TABLES` → pack).
  - Delete stale READMEs that remain.
  - Root `AGENTS.md`: update the battle-server note (the battle server currently does not compile and is waiting on a rewrite).
  - Root-repo files are edited but not committed (contract §0.6); the orchestrator tells the user the list.
  Must NOT do: write the reference product name into anything under `Source/`.
  Closes: all GAPs (documentation)
  Parallelization: W7 | Blocked by: 31 | Blocks: F1–F4
  References: `README.md`, `AGENTS.md`, every AGENTS/README listed above; contract (all).
  Acceptance criteria: `rg -n "HACKER_DATA_INIT 格式|GameWord|BehaviorTreeSystem|MG_DEFINE_SERIALIZABLE|sol 绑定" README.md AGENTS.md AxmolFighter-Client/AGENTS.md AxmolFighter-Client/Source/mugen/AGENTS.md AxmolFighter-Tools AxmolFighter-Config/AGENTS.md` returns no stale descriptions (if a match is a historical note, explain it in evidence).
  QA scenarios: Happy path: a fresh agent can follow the docs to pack config and run the headless tests successfully (`task-32.md` records it). Failure path: none. Evidence: `task-32.md`.
  Commit: Y | Client/Tools/Config: `docs: update for mugen rewrite`; root repo: not committed.
  Recommended task executor category: writing

- [x] 33. Code-convention retrofit (Chinese comments / no-throw error handling / readability / singleton boundary)
  What to do:
  - Apply four user-mandated conventions (authoritative text in `.omo/specs/mugen-rewrite-architecture.md` §0.4) to ALL code written in Todos 1–32, and mirror them into `Source/mugen/AGENTS.md`:
    1. **Comments**: every type, member variable, and function under `Source/mugen/{core,conf,avatar,sim}` gets a concise Chinese comment stating intent/constraints. Trivial accessors may be omitted; anything with behavior/semantics must be commented. Comments must still not name the reference product or contain drive-letter / plan-doc paths (contract §0.4).
    2. **No exceptions**: remove every `throw` from mugen logic (`core/`, `sim/`, `conf/`, `avatar/`). Replace with `MG_ASSERT` + `MG_LOG_E` (English). Keep failure-returning APIs (`bool` / `std::optional` / `nullptr`) only where a caller must handle failure gracefully (`Config::find`, `ECSManager::tryGet`, `Replay::load`). Update affected `TestsHeadless` tests that currently assert `CHECK_THROWS_AS` / `std::invalid_argument` to assert the new behavior (Debug assertion / logged failure / returned `false`).
    3. **Readability**: behavior-preserving clarity pass over the changed files (named structs, `enum class`, explicit params, plain constructs; no clever templates/implicit conversions/hard-to-read chaining), especially in architecture code.
    4. **Singleton audit**: confirm no per-battle *mutable* state is a singleton/global/function-local `static` — a battle server may run multiple mugen instances in one process. Only process-wide *read-only* data may be static (read-only config, shared skeleton/resource caches, immutable `BTDef` cache). Audit `conf::Config::instance()`, `AvatarAssetCache::getInstance()`, the `behavior::definition(...)` static `BTDefCache`, and every `static` under `sim/`; record each finding and fix in `.omo/notepads/mugen-rewrite/decisions.md`.
  - Add the four style rules as binding text to `Source/mugen/AGENTS.md`.
  Must NOT do: change gameplay behavior or semantics; change config serialization/schemas; touch the reference source, Server, Editor, or UI.
  Closes: (quality retrofit; backs IS-8)
  Parallelization: W3+ (cleanup) | Blocked by: 21 | Blocks: F1–F4 | Execution order: run FIRST among remaining tasks — immediately after 21, before 20 and 22–32, so the conventions apply to all code written from here on and the pre-rule code (todos 1–21) is fixed before more is layered on top.
  References: contract §0.4; `Source/mugen/AGENTS.md`; the code written in Todos 1–32.
  Acceptance criteria:
  - `rg -n "throw " AxmolFighter-Client/Source/mugen/core AxmolFighter-Client/Source/mugen/sim` returns nothing.
  - Every type/member/function in `core/ conf/ avatar/ sim/` carries a concise Chinese comment (spot-check + reviewer sign-off).
  - Singleton audit recorded in decisions.md; no per-battle mutable `static`/singleton remains.
  - G1 full headless suite green, G2 `check_rules.ps1` exit 0, G3 client configure+build exit 0.
  - `Source/mugen/AGENTS.md` and contract §0.4 carry the four rules.
  QA scenarios: Happy path: the commands above. Failure path: none (behavior-preserving refactor). Evidence: `task-33.md`.
  Commit: Y | Client: `refactor(mugen): chinese comments, no-throw errors, readability, singleton audit`
  Recommended task executor category: unspecified-high

- [x] 34. Cross-todo fix: control quadrant mapping and locomotion axes (discovered blocker for G1/F1)
  What to do: Fix the input-direction integration defect discovered at final verification. C++ `ControlManagerCore::direction()` renumbered physical directions (right→2, left→4, up→1, down→3), diverging from the reference `ControlManager.lua:slope2angle90` (right→1, left→3, up→4, down→2 with KeyCodeX d=+1/a=-1, KeyCodeY w=+1/s=-1). `RoleTree.cpp` and the other control-direction consumers (`ActionAttack.cpp`, `Effect.cpp`) used vector signs diverging from reference `Quadrant2Vector` (`EntityBase.lua:803-883`). Result: physical Right moved +z instead of +x (LocomotionTest:84 `after.z > before.z`). Correct direction()/angle and the vector signs to the reference, fix ComboTest's physical sequence and LocomotionTest expectations to reference behavior, then re-record the task-31 replays/hash files.
  Closes: GAP-1 (movement feel); unblocks G1 for F1.
  Execution: after 31. Verification: full headless suite exits 0 (225 cases / 245170 assertions), check_rules exits 0, 3x `mugen_sim_cli replay ... --compare ...` exit 0.
  Evidence: `.omo/evidence/mugen-rewrite/task-31-movement-fix.md`; corrected `task-31.md`.
  Commit: Y | Client: `fix(sim): correct control quadrant mapping and locomotion axes to match reference`

- [x] 35. IS-1 sprint-attack cast scenario
  What to do: Add a headless scenario that drives production `dealWithButton` / `dealButtonEvent` while `SkillPool::m_canSprint` is set and the role is in run status (or the current skill base slot is Y and not final). Assert the selected slot becomes Y and a sprint skill is preset or cast. Do not satisfy this with `getGivenSkill(..., "Y")` loadout presence alone. Keep the reference redirect: attack A during run or an in-progress non-final Y skill selects Y; otherwise it stays A.
  Must NOT do: change sprint semantics, retune locomotion axes, edit plan checkboxes, or modify any test file except the new `SprintCastTest.cpp` (and CMake only if tests are not globbed).
  Closes: GAP-1 / IS-1 sprint-attack clause (F4 REJECT 2026-10-09).
  Execution: after 34; parallel with 36, 37, 38 (isolated new test file).
  Acceptance criteria: `pwsh AxmolFighter-Client/TestsHeadless/run_headless_tests.ps1 -Filter "*Sprint*"` exits 0 and the new case fails if the Y redirect is removed. Existing full suite still green.
  QA scenarios: Happy path: running plus attack A selects Y. Failure path: `m_canSprint` false keeps slot A. Evidence: `.omo/evidence/mugen-rewrite/task-35.md`.
  Commit: Y | Client: `test(sim): sprint-attack Y redirect via dealWithButton`
  Recommended task executor category: unspecified-low (quota: do not use deep-low/deep-high)
  Parent-verified 2026-10-09: Client commit `f4182a0`; `*Sprint*` 4 cases / 33 assertions / 0 failed; production redirect `SkillInput.cpp:67-71`; evidence `task-35.md`. No production edit.

- [x] 36. IS-1 active dodge scenario (skill slot F)
  What to do: Add a headless hit scenario whose target current skill base slot is F. Assert the hit takes the active-dodge path: no damage application and a DODGE presentation tip (the passive attribute-dodge roll stays a separate path and must still be covered by the existing damage golden). Do not treat `attributeDodge` or `Damage golden same inputs and ordered draws` as this scenario.
  Must NOT do: reorder dodge, crit, and spread draws; edit plan checkboxes; modify any test file except the new `ActiveDodgeTest.cpp` (and CMake only if tests are not globbed).
  Closes: GAP-1 / IS-1 active-dodge clause (F4 REJECT 2026-10-09).
  Execution: after 34; parallel with 35, 37, 38 (isolated new test file).
  Acceptance criteria: `pwsh AxmolFighter-Client/TestsHeadless/run_headless_tests.ps1 -Filter "*Dodge*"` exits 0 with a case that requires slot F. Removing the slot-F check in the hit path fails that case. Existing damage golden still passes.
  QA scenarios: Happy path: slot F dodges. Failure path: a non-F slot with a failing attribute roll still applies damage. Evidence: `.omo/evidence/mugen-rewrite/task-36.md`.
  Commit: Y | Client: `test(sim): active dodge via skill slot F`
  Recommended task executor category: unspecified-low (quota: do not use deep-low/deep-high)
  Parent-verified 2026-10-09: Client commit `10c4e52` (ActiveDodgeTest.cpp + Hit.cpp main-path skip at `:259-264`); parent re-ran `*Dodge*` 2 cases / 33 assertions / 0 failed. Slot F emits DODGE and keeps HP; non-F with failing attribute roll still damages.

- [x] 37. IS-1 crazy-mode entry scenario
  What to do: Add a scenario that enters crazy through the production entry hook (buff crazy enter or the player action that sets `SkillPool::m_crazy`), starting from `m_crazy == false`. Assert `m_crazy` becomes true and the next cast of a slot that has a crazy variant selects the `+` skill. Keep the existing drain test: EP reaches zero and crazy does not end until `m_slotChanged`. Do not preset `m_crazy = true` as the only setup for the entry assertion.
  Must NOT do: change crazy EP-drain semantics; edit plan checkboxes; modify `SkillAiTest.cpp`; modify any test file except the new `CrazyEntryTest.cpp` (and CMake only if tests are not globbed).
  Closes: GAP-1 / IS-1 crazy-entry clause (F4 REJECT 2026-10-09).
  Execution: after 34; parallel with 35, 36, 38 (isolated new test file).
  Acceptance criteria: `pwsh AxmolFighter-Client/TestsHeadless/run_headless_tests.ps1 -Filter "*Crazy*"` exits 0 and includes both entry-plus-crazy-slot selection and the existing EP-drain wait. Evidence: `.omo/evidence/mugen-rewrite/task-37.md`.
  Commit: Y | Client: `test(sim): crazy-mode entry then plus-slot selection`
  Recommended task executor category: unspecified-low (quota: do not use deep-low/deep-high)
  Parent-verified 2026-10-09: Client commit `e40a850`; parent re-ran `*Crazy*` 2 cases / 24 assertions / 0 failed (new BuffCrazy entry + existing EP-drain). Production entry `BuffRules.cpp:315-320`; plus rewrite `SkillInput.cpp:84`. No production edit.

- [x] 38. IS-1 B/C/D and motion-command cast scenario
  What to do: Add scenarios that pass `CTR_ATKB`, `CTR_ATKC`, `CTR_ATKD` (or the JOY B/C/D events the input layer actually emits) into `dealWithButton` and assert the resolved slots are B, C, and D (including the `_2` form when that is the event mapping). Feed the existing Down-Left-Up-Right-Down plus AttackA sequence's `CTR_JOY1` into `dealWithButton` on a pool that has the matching rock skill, and assert that skill is selected. Assert fallback to A when the rock skill is absent. `ControlManager combo emits joystick event` and `getGivenSkill` loadout checks are not sufficient by themselves.
  Must NOT do: change the combo physical order (Down, Left, Up, Right, Down) or the quadrant numbering from todo 34; edit plan checkboxes; modify `ControlManagerTest.cpp` or `SkillCastingTest.cpp`; modify any test file except the new `SkillButtonCastTest.cpp` (and CMake only if tests are not globbed).
  Closes: GAP-1 / IS-1 B/C/D and motion-command clauses (F4 REJECT 2026-10-09).
  Execution: after 34; parallel with 35, 36, 37 (isolated new test file).
  Acceptance criteria: `pwsh AxmolFighter-Client/TestsHeadless/run_headless_tests.ps1 -Filter "*SkillButton*"` exits 0 and the new cases fail if event-to-slot mapping for B, C, D, or JOY1 is removed. (Plan F4 text said `*Skill*`; use `*SkillButton*` so this file is uniquely filterable and does not collide with sibling filters.) Evidence: `.omo/evidence/mugen-rewrite/task-38.md`.
  Commit: Y | Client: `test(sim): B/C/D and JOY1 cast through dealWithButton`
  Recommended task executor category: unspecified-low (quota: do not use deep-low/deep-high)
  Parent-verified 2026-10-09: Client commit `f359f9a`; parent re-ran `*SkillButton*` 4 cases / 69 assertions / 0 failed. Production `eventSlot` `SkillInput.cpp:15-20` and JOY fallback `:73-81` unchanged. Cases: ATKB/C/D → B/C/D; JOYB/C/D → mode 2; JOY1 selects `1+`; absent rock falls back to A.

- [x] 39. F2 §0.4: delete unused float/double serialize helpers and commit unordered-trait removal
  What to do: Delete ByteBuffer and EndianUtils float/double methods, if-constexpr arms, and helpers. Delete the four `DeferredDeterminismPaths` entries in `TestsHeadless/check_rules.ps1` so a reintroduction fails G2. Commit the working-tree removal of `unordered_map`/`unordered_set` traits from `ByteBuffer.h` (already deleted in the dirty tree, still present on committed HEAD `4f08561`). Parent grep of `writeFloat32|readFloat32|getFloat32|writeFloat64|EndianUtils::` under `Source/` shows no caller outside these two types.
  Must NOT do: change live snapshot/hash serialization of production types; retune locomotion; edit plan checkboxes; modify `SprintCastTest.cpp` / `ActiveDodgeTest.cpp` / `CrazyEntryTest.cpp` / `SkillButtonCastTest.cpp`; reintroduce exemptions; touch `sim/` combat files.
  Closes: F2 REJECT blockers 1 and 2 (2026-10-09, `F2-code-quality.md`).
  Execution: after F2 REJECT; parallel with 36, 37, 38 (isolated serialize/utils + check_rules files).
  Acceptance criteria: `pwsh AxmolFighter-Client/TestsHeadless/check_rules.ps1` exits 0 with the four exemptions gone; no float/double APIs remain in ByteBuffer/EndianUtils; no `unordered_map`/`unordered_set` in `core/` or `sim/`; full headless suite still green. Evidence: `.omo/evidence/mugen-rewrite/task-39.md`.
  Commit: Y | Client: `fix(core): remove float and unordered serialize helpers`
  Recommended task executor category: unspecified-low (quota: do not use deep-low/deep-high)
  Parent-verified 2026-10-10: Client commit `d7542d2e84ba87d59afcf9dc7e41a316dc3c6121` (message exact; five files only). `check_rules.ps1` exit 0 with DeferredDeterminismPaths gone and `$checkDeterminismTokens = $inCoreOrSim`. ByteBuffer/EndianUtils have no float/double APIs and no unordered traits. Grep of core/sim unordered_map/unordered_set empty. Parent re-ran full headless: 236 passed / 245326 assertions / 0 failed, EXIT=0. Evidence: `.omo/evidence/mugen-rewrite/task-39.md`.

- [x] 40. F2 §0.4: commit Object/Vec deletion and BTDef no-throw rewrite so committed HEAD passes G2
  What to do: The 2026-10-10 F2 re-review (`F2-code-quality-rereview.md`, `VERDICT: REJECT`) closed todo 39's two blockers on HEAD `d7542d2`, then found three remaining HEAD-only §0.4 failures that the working tree already fixes but has not committed: (1) `core/Object.h` / `Object.cpp` process-wide `std::unordered_set<Object*> g_objectSet`; (2) `core/math/Vec2.h` / `Vec3.h` unguarded `float` fields; (3) eleven runtime `throw std::invalid_argument` in `core/bt/BTDef.h` / `BTDef.cpp` (branch-added; not the consteval Fixed.h allowance). Commit the existing working-tree deletions of Object/Vec2/Vec3, add `IntVec2.h` / `IntVec3.h`, rewrite BTDef throws to `MG_LOG_E` + `MG_ASSERT`, and commit every HEAD dependent that still includes those deleted headers so a `git archive HEAD` copy of `check_rules.ps1 -Paths core,sim` exits 0. Parent-confirmed HEAD includes: `avatar/MotionPlayer.h`, `avatar/data/AniData.h`, `avatar/data/MotionMap.h`, `conf/GameDef.h`, `conf/LayerLoader.h`, `conf/MapScope.h`, `conf/TableConfig.h`, `core/math/DamageBox.h`, `core/math/Random.h`, `render/LayerRuntimeLoader.h`, `render/RenderUtils.h`, `render/VirtualCamera.h`. Working-tree already replaces Object/Vec includes with IntVec/FixedVec and deletes TableConfig.h; include `.cpp` siblings only when the header change requires them to compile.
  Must NOT do: dump the entire Client dirty tree (sim/, TestsHeadless tests, UI, CMake, .clangd); retune locomotion; edit plan checkboxes; modify Sprint/Dodge/Crazy/SkillButton tests; reintroduce float/unordered/throw in core/sim; touch sim/ combat files except if a HEAD include of Object/Vec forces it (parent grep of HEAD sim/ had no Object/Vec includes); push; commit the root repo; change submodule pointers; amend `d7542d2`.
  Closes: F2 REJECT blockers 1–3 (2026-10-10, `F2-code-quality-rereview.md`).
  Execution: after F2 re-review REJECT; sequential before a FRESH F2 session. Do not resume `ses_edb8c30c9ffel6Mz1TnkQ1h3rC` for implementation.
  Acceptance criteria: `git archive HEAD Source/mugen TestsHeadless/check_rules.ps1` into a temp dir, then that copy of `check_rules.ps1 -Paths core,sim` exits 0; `git grep -nE '\bthrow\b' HEAD -- Source/mugen/core Source/mugen/sim` matches only the five consteval `Fixed.h` hits; `git grep` HEAD of `unordered_map|unordered_set` under core/sim is empty; `git grep` HEAD of `Object.h|Vec2.h|Vec3.h` under Source excluding 3rd is empty; full `pwsh AxmolFighter-Client/TestsHeadless/run_headless_tests.ps1` exits 0. Evidence: `.omo/evidence/mugen-rewrite/task-40.md`.
  Commit: Y | Client: `fix(core): drop Object/Vec float types and BTDef runtime throws`
  Recommended task executor category: deep-low (cheap pools quota_exceeded; worker settles the dependent-file allowlist from git grep of HEAD)
  Parent-verified 2026-10-10: Client commit `c2925b4b82afec0214ed4fed46ddf273b79b77b9` (parent `d7542d2`, message exact). Deleted Object.h/.cpp, Vec2/Vec3 .h+.cpp, TableConfig.h; added IntVec2.h/IntVec3.h; BTDef uses MG_LOG_E + MG_ASSERT. Extra allowlist: AvatarAssetCache and CombatTimeline (HEAD derived from Object). Parent git-archive HEAD `check_rules.ps1 -Paths core,sim` EXIT=0; git grep HEAD unordered empty; throw only five consteval Fixed.h; Object.h/Vec2.h/Vec3.h gone from HEAD tree. Parent re-ran full headless: 236 passed / 245326 assertions / 0 failed, EXIT=0. Evidence: `.omo/evidence/mugen-rewrite/task-40.md`.

- [x] 41. Playtest: stop portal MotionPlayer::bind spam (room 20002)
  What to do:
  - User repro: `AxmolFighter-Client.exe --offline-room=20002 --offline-role=mage` (cwd `AxmolFighter-Client/Content`) prints every logic frame `MotionPlayer::bind: motion map not found 'mugen/motion/por/tx_ui_sizhongchuansongmen.motion'`.
  - Root cause (verified): `room.lua` 20002 → portal 101 → `res_spine` 1222 → `mugen/spine/por/tx_ui_sizhongchuansongmen.skel`. `RoomEntities.cpp` `base()` always writes `motion.motionFile = AvatarPaths::motionFileFromSpine(...)`. Portal `update()` calls `animate()` every tick; `animate()` constructs a fresh `MotionPlayer` and `bind()`s. `bind` logs on every miss and does not clear `MotionState.motionFile`. `Content/mugen/motion/por/` does not exist; `avatar.bin` has no `por` keys. Reference portals are Spine appearance + radius collision, not combat `.motion` timelines (`Reference/heiyue-战斗逻辑.md` portal section; `heiyue-战斗配置.md` entity_portal).
  - Ruling (do not reopen): portals MUST NOT bind a combat `.motion`. Do NOT generate `motion/por/*.motion`. Do NOT run `pack-avatar` or `run_spine_box_batch.ps1`. Do NOT edit Tools.
  - Code:
    - `RoomEntities.cpp` `base()`: when `group == GroupKind::Portal`, leave `MotionState.motionFile` empty. Still apply `res_spine.scale` onto `Transform.scale` when the spine row exists.
    - Extract the radius AABB write currently inside `animate()`'s failure branch into a local helper (anonymous namespace). Portal `update()` MUST NOT call `animate()`. Every portal tick: write the radius AABB, then if `PortalPhase::Transfer` and `RoomState.m_transferRoom == 0`, write transfer fields exactly as today (`RoomEntities.cpp:245-253`). Keep the one-frame delay: collision sets Transfer, the next portal `update` commits `m_transferRoom` (current missing-motion behavior).
    - Goods and Obstacle keep calling `animate()`.
    - `MotionPlayer::bind`: log each distinct missing path at most once (English). Use a file-scope `std::set<std::string>` solely for log de-dupe (not battle state, not `unordered_set`). Empty path: no log.
  - Tests: new headless case (globbed). Load production config, `run-room` 20002 for ≥30 frames. Every `PortalState` entity has empty `motionFile` and non-empty `ColliderState.damage`. Capture `mugen_sim_cli run-room 20002 --frames 60` stderr: it MUST NOT contain `tx_ui_sizhongchuansongmen.motion` or `MotionPlayer::bind: motion map not found`.
  - Append the ruling to `.omo/notepads/mugen-rewrite/decisions.md` (append only). Evidence: `.omo/evidence/mugen-rewrite/task-41.md`.
  Must NOT do: generate `.motion`; pack avatar.bin; edit Tools/Server/Editor/UI/heiyue; change portal collision/jostle/openPortals phase machine except removing `animate()`; change Goods/Obstacle bind success path; edit plan checkboxes; use a worktree; push; mark F3 `[x]`.
  Closes: F3 playtest gap (portal log spam); IS-4 portal operability.
  Parallelization: W8 | Blocked by: 30 | Blocks: F3 | Can parallelize with: 42, 43, 44
  References: `RoomEntities.cpp:36-67,69-91,163-178,242-255`; `MotionPlayer.cpp:13-25`; `.omo/notepads/mugen-rewrite/problems.md:58-82`; `issues.md` Task 30 portal asset gap.
  Acceptance criteria: G1 full suite exit 0; G2 `check_rules.ps1` exit 0; G3 only if configure required after adding the test file; `mugen_sim_cli run-room 20002 --frames 60` stderr has no bind-miss for the por motion; new `*Portal*` (or unique filter) case fails if `base()` still writes a portal `motionFile`.
  QA scenarios: Happy path: the cli stderr check + new test. Failure path: a Goods/Obstacle with a real `.motion` still samples boxes through `animate()`. Evidence: `task-41.md` including stderr excerpt.
  Commit: Y | Client: `fix(sim): skip portal motion bind and keep radius collider`
  Recommended task executor category: deep-low
  Parent-verified 2026-10-10: Client commit `1a0c12073715c5b5722609772ad592b4f14f688e`. Parent re-ran `*Portal*` 6 cases / 88 assertions / 0 failed; `check_rules.ps1` EXIT=0; `mugen_sim_cli run-room 20002 --frames 60` EXIT=0 hash `6e1f372fe94ca5cc`; stderr has no `tx_ui_sizhongchuansongmen.motion` and no `MotionPlayer::bind: motion map not found`. Evidence: `task-41.md`.

- [x] 42. Playtest: SpineBody durationMs assert after running (room 20002 mage)
  What to do:
  - User repro: after playing a while, Debug assert `clip.durationMs == static_cast<int>(std::lround(anim.duration() * 1000.0f))` at `Source/mugen/avatar/render/SpineBody.cpp:245`.
  - Diagnose first (cite file:line): why `.motion` `MotionClip.durationMs` and the live Spine `Animation::duration()` diverge after time, not only at bind. Check looping wrap, `setMotion`/`seek`, shared skeleton, attachment/skin swap, timescale, clip concatenation, and float rounding. Architecture: logic and render bind the same `.motion` and duration is homologous — do NOT delete the assert to “fix” it.
  - Fix the source of the mismatch so the equality holds for every clip the client actually plays in room 20002 / mage. If an authored clip duration is wrong, correct the clip or the seek path; if Spine duration is read at the wrong time (pre-skin), read it when the animation is the one being posed.
  - Add a regression test if the mismatch is visible headless (clip vs parsed motion JSON). If it is render-only, add a client-side unit/smoke that walks every motion the mage uses and compares `durationMs` to `anim.duration()` after skeleton setup, and record a RelWithDebInfo run of `--offline-room=20002 --offline-role=mage --autotest-frames=900` that does not abort.
  Must NOT do: remove or `#ifdef` away the assert; change combat sim numbers; generate portal `.motion` (todo 41); edit Server/Editor/UI/heiyue; worktree; push; mark F3 `[x]`.
  Closes: F3 playtest crash.
  Parallelization: W8 | Blocked by: 15 | Blocks: F3 | Can parallelize with: 41, 43, 44
  References: `SpineBody.cpp` around 245; `avatar/data/MotionMap.h`; `AvatarPresenter`; contract §8.3 / §9 Avatar duration homology.
  Acceptance criteria: G1 and G2 exit 0; G3 client build exit 0; RelWithDebInfo `--offline-room=20002 --offline-role=mage --autotest-frames=900` (cwd Content) exits 0 and does not hit the duration assert; evidence names the clip(s) that mismatched and the one-line root cause.
  QA scenarios: Happy path: autotest 900 frames. Failure path: a unit case where a known clip's stored `durationMs` disagrees with Spine duration fails before the production assert. Evidence: `task-42.md`.
  Commit: Y | Client: `fix(render): keep motion clip duration aligned with Spine animation`
  Recommended task executor category: deep-low
  Parent-verified 2026-10-10: Client commit `8d6588707c02433ef17d962a6dbcc51eb233147c`. Root cause: 11 mage clips (airmash/death/ground/...) have Spine duration 0 and box sample 33 ms; assert fires on first setMotion of those clips, not drift. Assert kept. Parent re-ran `*clip duration*,*stored duration*,*Duration*` 4 cases / 30 assertions / 0 failed; `check_rules.ps1` EXIT=0. Evidence: `task-42.md`.

- [x] 43. Playtest: releasing direction keys must stop the hero
  What to do:
  - User repro: in `--offline-room=20002 --offline-role=mage`, pressing a direction key moves the matching way, but releasing the key does not stop.
  - Diagnose first. Reference: `EntityRole:dealWithEvent` Idle on joystick release (`EntityRole.lua:2131-2187` via `Reference/heiyue-战斗逻辑.md` §5.1); `ControlManager.lua` key-up clears the axis. C++ must emit a release/idle control event (not keep the last CTR_JOY / walk vector). Do not retune todo 34 quadrant numbering (`ControlManagerCore::direction` and `Quadrant2Vector`).
  - Fix the sticky axis: keyboard key-up must zero that axis; when both axes are zero, the ROLE tree must leave Walk/Run and enter Idle the same frame window as the reference (no coasting from a latched command).
  - Headless: extend `ControlManagerTest` or add `LocomotionReleaseTest` that presses Right for N frames then releases (no buttons), then asserts Transform stops changing within 2 frames and status is Idle not Walk/Run.
  Must NOT do: change quadrant mapping from todo 34; change WASD-to-move mapping; edit Server/Editor/UI FairyGUI; worktree; push; mark F3 `[x]`.
  Closes: IS-1 walk operability (F3 playtest).
  Parallelization: W8 | Blocked by: 14, 15, 34 | Blocks: F3 | Can parallelize with: 41, 42, 44
  References: `Source/ui/battle` ControlManager; `sim/input`; `RoleTree` / `ActionWalk` / `ActionRun`; `ControlManagerTest.cpp`; `LocomotionTest.cpp`; todo 34.
  Acceptance criteria: G1 filter `*Control*` and `*Locomotion*` plus the new release case exit 0; full G1 still green; G2 exit 0. The new case fails if key-up is ignored.
  QA scenarios: Happy path: press then release stops. Failure path: holding the key continues to move. Evidence: `task-43.md`.
  Commit: Y | Client: `fix(input): clear locomotion on direction key release`
  Recommended task executor category: deep-low
  Parent-verified 2026-10-11: Client commit `957cb0ab6533059f496ba26b354783876a1520ee`. Root cause: `updateDirection` returned on direction 0 without `CTR_IDLE`; ROLE tree kept last `CTR_RUN`. Fix emits `{CTR_IDLE,0,0,0}` on the edge to 0. Quadrant map unchanged. Parent re-ran `*Control*,*Locomotion*` 12 cases / 123 assertions / 0 failed; `check_rules.ps1` EXIT=0. Evidence: `task-43.md`.

- [x] 44. Playtest: battle camera must follow the local player
  What to do:
  - User repro: in `--offline-room=20002 --offline-role=mage`, the camera does not follow the hero while walking.
  - Diagnose first. Todo 15 required `CameraDirector` follow + `MapPresenter` (`LayerRuntimeLoader` + `VirtualCamera`). Find why the follow target is missing, stale, or never applied (wrong entity, world-space vs layer-space, follow disabled, camera updated before the player moves, offline boot skips director).
  - Fix so the virtual camera tracks the local player's `Transform` every presented frame. Keep shake / slow-mo / action_camera as already implemented; do not invent a new camera rig. Match the existing presenter interpolation so the camera does not snap one logic frame behind in a broken way — following a moving walk is the acceptance, not cinematic polish.
  - Headless if CameraDirector logic is engine-free: assert follow offset tracks a moving entity. If it is render-only, drive RelWithDebInfo `--offline-room=20002 --offline-role=mage --autotest-frames=300` and log camera center vs player position (add a Debug log or debug-panel value already present); evidence must show camera center moved with the player under injected movement, or a new presenter unit test that feeds two Transform samples and checks VirtualCamera look-at.
  Must NOT do: rewrite the map renderer; change sim camera slow-mo numbers; worktree; push; mark F3 `[x]`; edit Server/Editor/heiyue.
  Closes: IS-1 operability (camera follow).
  Parallelization: W8 | Blocked by: 15 | Blocks: F3 | Can parallelize with: 41, 42, 43
  References: `Source/mugen/render/battle` CameraDirector / WorldPresenter / MapPresenter; `render/VirtualCamera.*`; `ui/battle/LocalBattleMode.cpp`; contract §9.1.
  Acceptance criteria: G3 client build exit 0; G1/G2 still green; evidence proves camera look-at/center changes when the local player Transform changes (test log or unit assertion), and does not stay at the spawn camera when the player has walked away.
  QA scenarios: Happy path: player walks +x, camera center +x. Failure path: no local player → camera stays on the map default without crashing. Evidence: `task-44.md`.
  Commit: Y | Client: `fix(render): follow local player with battle virtual camera`
  Recommended task executor category: visual-engineering
  Parent-verified 2026-10-11: Client commit `9f81c81e4e46451b686cd7626a0dd02ebd5bbfce` adds `WorldPresenter.h/.cpp`. Root cause: `VirtualCamera` defaulted `m_regionSize` to the viewport so `clampViewPosition` pinned view to 0; `setCall` moved only the `ParallaxNode`. Fix: `MapPresenter::load` calls `setRegion` from `LayerLoader` map size; camera callback moves map and `worldLayer` (avatars/hurt/debug) together; `CameraDirector::follow` sets focus from the local `Transform`; `present` calls follow every frame. Parent independently: `check_rules.ps1` EXIT=0; no `QA-TEMP` left in source; RelWithDebInfo exe 19962880 bytes 2026-10-11 01:32:40 (dirty-tree build). Evidence QA log: player x 950→1932, view -139→-1036. HEAD `LocalBattleMode.cpp` is still the todo-3 placeholder; `setFollowEntity(player)` lives in the uncommitted rewrite (todo 15 working tree), which is what the exe was built from. Evidence: `task-44.md`.

- [x] 45. Playtest: stop Avatar motion-not-found spam on tx_youli_zidongsheji (room 20002 mage)
  What to do:
  - User repro (F3 2026-10-11): `--offline-room=20002 --offline-role=mage` no longer floods `tx_ui_sizhongchuansongmen.motion` bind (todo 41 done), but every logic frame prints `Avatar: motion 'N' not found in 'mugen/motion/effect/tx_youli_zidongsheji.motion'` for names `18`, `20`, `24`, `28`, `64`, `72`, `siwang`.
  - Diagnose first (cite file:line). The log is Avatar, not `MotionPlayer::bind`. `problems.md` already recorded this file lists `{0,2,4,6,8,10,12,14,16,JN1}` — the names the skeleton actually has. Config/effect spawn requests absent names; regeneration cannot invent them.
  - Ruling (do not reopen): do NOT generate `.motion`; do NOT pack `avatar.bin`; do NOT edit Tools; do NOT invent missing animation names or remap config ids without an authoritative source. This is a config/skeleton mismatch, not a missing asset.
  - Code: stop the per-frame flood. Log each distinct `(motionFile, motionName)` miss at most once (English). Analog: `MotionPlayer::bind` file-scope `std::set<std::string>` de-dupe from todo 41 (not battle state, not `unordered_set`). If `AvatarPresenter::present` / `setMotion` re-enters the miss path every frame, skip the repeated lookup after the first miss so the warning cannot return. Empty name: no log.
  - Tests: if the miss is reachable headless, add a case that looks up a known-absent name twice on this motion and asserts the English warning appears once. If it is render-only, add a client-side unit/smoke on the same once-per-key contract and record RelWithDebInfo `--offline-room=20002 --offline-role=mage --autotest-frames=300` stderr: after the first miss for a given name, that exact `Avatar: motion 'N' not found` line must not repeat every frame. Evidence: `.omo/evidence/mugen-rewrite/task-45.md`.
  Must NOT do: generate `.motion`; pack avatar.bin; edit Tools/Server/Editor/UI/heiyue; change combat sim numbers; retune locomotion; edit plan checkboxes; worktree; push; mark F3 `[x]`.
  Closes: F3 playtest gap (Avatar motion log spam).
  Parallelization: W9 | Blocked by: 15 | Blocks: F3 | Can parallelize with: 46
  References: `avatar/render` Avatar / AvatarPresenter; `MotionPlayer.cpp` bind once-log; `.omo/notepads/mugen-rewrite/problems.md:58-82`; todo 41 analog.
  Acceptance criteria: G1 full suite exit 0; G2 `check_rules.ps1` exit 0; G3 only if a client unit is added; stderr of a 20002 mage autotest (or the new unit) does not flood the same `tx_youli_zidongsheji` miss every frame. The new case fails if the miss path logs on every call.
  QA scenarios: Happy path: first miss logs once, later frames stay quiet for that name. Failure path: a name that EXISTS in the motion file still plays. Evidence: `task-45.md` including a stderr excerpt or unit assertion.
  Commit: Y | Client: `fix(render): log missing Avatar motions once`
  Recommended task executor category: unspecified-high (deep-low quota exhausted)
  Parent-verified 2026-10-11: Client commit `45dd47e54ab6d3de55a20647557704f90d871a47` (`fix(render): log missing Avatar motions once`). Four files: `MissingAvatarMotion.h/.cpp`, `Avatar.cpp` `setMotion` -> `findAvatarMotion`, `MissingAvatarMotionTest.cpp`. File-scope `std::set<std::string>` keyed by `motionFile + '\n' + motionName`; empty name no log; present names still resolve. Parent independently: `*Missing avatar motion*` 3/14/0; full G1 245/245364/0 EXIT=0; G2 EXIT=0. Evidence `task-45.md`. F3 stays `[~]`. LocalBattleMode not committed. No `.motion` generated.

- [x] 46. Playtest: dual-axis diagonal plus opposing-key last-wins (room 20002 mage)
  What to do:
  - User repro (F3 2026-10-11): `--offline-room=20002 --offline-role=mage`. Todo 43 already stops on full release. Remaining: (a) Up+Right moves on only one axis, not diagonal. (b) Left then Right must move right while both are held. (c) Releasing Right while Left is still held must move left with no Idle gap.
  - Root cause (verified, do not re-litigate): `ControlManagerCore.cpp` `direction()` encodes four bools into ONE quadrant; Right/Left are checked before Down/Up, so Up+Right stays `1` and `updateDirection` returns because `current == m_lastDirection`. Angle is hardcoded `0` or `90000`. Left+Right fails both XOR arms and returns `0` → `CTR_IDLE`. `m_held` has no press recency. ROLE Walk/Run (`RoleTree.cpp` tick) already writes both `vectorX` and `vectorZ` when `angle==45000` via `cosDeg`/`sinDeg`; ControlManager never emits that angle. Combos (`kCombos`) stay 4-way quantized on the 90° sector.
  - Code:
    - `ControlManagerCore`: track per-axis press recency in `setKey(pressed=true)` (counter or timestamp owned by the manager instance — not a process-wide static, not `unordered_map`). When Left+Right (or Up+Down) are both held, the later key wins that axis. Releasing the later key falls back to the remaining held key in the same `updateDirection` edge; do NOT emit `CTR_IDLE` while any axis is still held.
    - Perpendicular keys (Up+Right, Up+Left, Down+Right, Down+Left): emit `{CTR_RUN, quadrant, 45000, 1}` where `quadrant` is still the 90° sector (Up+Right → 1). Re-emit when the *angle* changes even if the quadrant stays the same (Right held, then Up: 0° → 45°). `m_lastDirection` alone is not enough — also remember the last emitted angle.
    - Combo matching continues to use the 4-way sector code (1/2/3/4), never a fifth diagonal code. Keep todo 34 numbering: Right=1, Down=2, Left=3, Up=4. Do not change WASD mapping (client movement is arrow keys in `GameView.cpp`).
    - Do not retune `RoleTree.cpp` vector signs unless a new 45° case actually fails; the tick already supports 45°. Same for `ActionAttack.cpp` / `Effect.cpp` unless they ignore non-cardinal angles.
  - Tests (globbed; titles must match `*Control*` or `*Locomotion*` so existing filters see them):
    - Up+Right for N frames: Transform Δx>0 AND Δz>0 (role 104 / mage velocity, not role 261 velocity=0).
    - Left then Right while both held: moves +X, not idle.
    - Release Right, Left still held: moves −X within 2 frames, no Idle coast in between.
    - Existing single-key LocomotionTest quadrants and LocomotionReleaseTest Right-release still pass. Combo Down-Left-Up-Right-Down still emits JOY as today.
  - Evidence: `.omo/evidence/mugen-rewrite/task-46.md`.
  Must NOT do: change quadrant numbering from todo 34; change WASD-to-move mapping; add a fifth combo code; edit Server/Editor/UI/heiyue; worktree; push; mark F3 `[x]`; edit plan checkboxes.
  Closes: IS-1 walk operability (diagonal + opposing last-wins).
  Parallelization: W9 | Blocked by: 34, 43 | Blocks: F3 | Can parallelize with: 45
  References: `ControlManagerCore.cpp:27-42,94-118`; `ControlManagerCore.h` `m_held` / `m_lastDirection`; `RoleTree.cpp` tick ~176-189; `LocomotionTest.cpp`; `LocomotionReleaseTest.cpp`; todo 34; todo 43.
  Acceptance criteria: G1 filter `*Control*,*Locomotion*` plus the new dual-axis/last-wins cases exit 0; full G1 still green; G2 exit 0. The new diagonal case fails if `direction()` still returns a single axis for Up+Right. The new last-wins case fails if Left+Right emits `CTR_IDLE`.
  QA scenarios: Happy path: Up+Right walks diagonally; Left then Right walks right; release Right walks left. Failure path: releasing all keys still Idle (todo 43). Evidence: `task-46.md`.
  Commit: Y | Client: `fix(input): diagonal locomotion and opposing-key last-wins`
  Recommended task executor category: unspecified-high (deep-low quota exhausted)
  Parent-verified 2026-10-11: Client commit `8036f64299835e2cd85a495eb253a8fc7f3170fd` (`fix(input): diagonal locomotion and opposing-key last-wins`). Four files: `ControlManagerCore.cpp/.h`, `ControlManagerTest.cpp`, `LocomotionReleaseTest.cpp`. Instance `m_pressOrder[4]`/`m_pressSerial`; `axisSign` later stamp wins one axis; perpendicular keys emit `{CTR_RUN, sector, 45000, 1}` (Up+Right=1); `m_lastAngle` re-emits when Right is held and Up is added (quadrant stays 1, angle 0→45000); combo advances only on sector change, still codes 1/2/3/4; `CTR_IDLE` only when both axes resolve to 0 (todo 43). Quadrant numbering unchanged. RoleTree vector signs not retuned. WASD unused. Parent independently: `*Control*,*Locomotion*` 20/156/0 FILTER_EXIT=0; full G1 253/245397/0 EXIT=0; G2 EXIT=0; clangd `ControlManagerCore.cpp` clean. Evidence `task-46.md`. F3 stays `[~]`. LocalBattleMode not committed.

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [x] F1. Plan compliance audit
  - Re-run the acceptance commands of every todo and gates G1–G5.
  - Each GAP row has a todo that closes it.
  - Combat data references: `kUnimplementedLeaf` = 0 and `kUnportedRule` = 0.
  - The "Must NOT have" items all hold (check with `git diff --stat` that the Server/Editor/UI/heiyue repos are untouched).
  Parent-verified 2026-10-09: G1 log 225/245170/0 failed; G2 independently re-run exit 0; G5 Release hashes match RelWithDebInfo pair (2010101 `6231c7ecb324ea6f`, 2071501 `ffb825e92024d73d`, 30002 `3325585ada0f3232`); placeholders only enum/sentinel; Server/Editor/UI/heiyue diffs empty. Evidence: `F1-plan-compliance.md` (stale after 41-44).
  Parent-verified 2026-10-11 after 41-44 (`ses_ed9082e09ffeeEr8Hp91SFZ1l4`, evidence `F1-plan-compliance-after-41-44.md`, literal `VERDICT: APPROVE`). Parent independently: `kUnimplementedLeaf` only `RoleTree.h:89` enum; `kUnportedRule` only `BuffRules.cpp` sentinel/fill/`isUnportedRule`; G5 log pairs 30002 `1dc3eecaca364898` and 20002 mage `bc37c5a5d6618b1e` twice each EXIT=0; notepad `F1-rerun-after-41-44` entries present. Dirty-tree G1 242/245350/0; G2 EXIT=0; G3 not rebuilt (exe 19962880 bytes 2026-10-11 01:32:40 vs commit `9f81c81` 01:34:21). RelWithDebInfo does not prove todo 42. F3 stays `[~]`.
  Parent-verified APPROVE 2026-10-11 after 45-46 (`ses_ed6e148d9ffesyT2hD062zDIAd`, evidence `F1-plan-compliance-after-45-46.md`, literal `VERDICT: APPROVE`) on Client HEAD `8036f64299835e2cd85a495eb253a8fc7f3170fd`. Parent independently: G1 253/245397/0 EXIT=0; G2 EXIT=0; `*Control*,*Locomotion*` 20/156/0; `*Missing avatar motion*` 3/14/0. Worker live G1/G2 matched those counts. HEAD `kUnimplementedLeaf` only `AGENTS.md:50`; `kUnportedRule` no HEAD hits. Server/Editor/UI/heiyue product diffs empty. RelWithDebInfo 01:32:40 and `mugen_sim_cli` 2026-10-10 22:58:19 are pre-45/46; client G5 deferred to F3-machine. F3 stays `[~]`.
- [x] F2. Code quality review
  - An independent reviewer reads the diff on the `mugen-rewrite` branch of Client/Tools/Config against its base and checks compliance with contract §0.4 (no floats, no unordered containers, no std::function, no engine headers, no defensive null checks, English logs, no product names).
  - Checks there is no dead code, no duplicated logic, and that every placeholder has been removed.
  Parent-verified APPROVE 2026-10-10 on committed HEAD `c2925b4` (`ses_edb0f62c7ffegAgyBNAOO5kMD0`, evidence `F2-code-quality-rereview-c2925b4.md`, literal `VERDICT: APPROVE`). Parent independently re-ran `git archive HEAD` then `check_rules.ps1 -Paths core,sim` ARCHIVE_EXIT=0; Object.h/Vec2.h/Vec3.h absent from `git ls-tree HEAD`; `git grep HEAD \\bthrow\\b` only five consteval Fixed.h; unordered empty under core/sim; DeferredDeterminismPaths gone. Prior REJECTs retained: `F2-code-quality.md` (2026-10-09, closed by todo 39 `d7542d2`) and `F2-code-quality-rereview.md` (2026-10-10, closed by todo 40 `c2925b4`). Non-blocking notes: HEAD `conf/Config.h` still derives from deleted Object (outside core/sim, dirty-tree rewrite); stale BuffRules.cpp:818 comment; unused `kUnimplementedLeaf` enum; SkillPool/AttackRole vs SkillManager naming is a user-rule vs AGENTS.md direction question, not a §0.4 fail.
  Parent-verified APPROVE 2026-10-11 after 41-44 (`ses_ed8eba63fffevX2l574sjwLokc`, evidence `F2-code-quality-after-41-44.md`, literal `VERDICT: APPROVE`) on Client HEAD `9f81c81e4e46451b686cd7626a0dd02ebd5bbfce`. Parent independently: `RoleTree.h`/`BuffRules.cpp` exist on disk but not in HEAD (cat-file EXIT=128); `kUnimplementedLeaf` on HEAD only `AGENTS.md:50`; `kUnportedRule` no HEAD hits; `CTR_IDLE` in committed `ControlManagerCore.cpp`; notepad `F2-rerun-after-41-44` present. Archive `check_rules -Paths core,sim` ARCHIVE_EXIT=0. Tools/Config were not in 41-44. F3 stays `[~]`.
  Parent-verified APPROVE 2026-10-11 after 45-46 (`ses_ed6d65782ffeJOhZcVpurzDWmj`, evidence `F2-code-quality-after-45-46.md`, literal `VERDICT: APPROVE`) on Client HEAD `8036f64299835e2cd85a495eb253a8fc7f3170fd`. Parent independently: `9f81c81..HEAD` is 8 files +438/-33 (`45dd47e` + `8036f64`); `kUnimplementedLeaf` HEAD only `AGENTS.md:50`; `kUnportedRule` no HEAD hits; unordered empty under core/sim; `\bthrow\b` only five consteval `Fixed.h`; `ControlManagerCore.h` absent at `9f81c81` (EXIT=128) and present on HEAD; `RoleTree.h` not in HEAD (EXIT=128). Worker archive `check_rules -Paths core,sim` ARCHIVE_EXIT=0. Recency is instance `m_pressOrder`/`m_pressSerial`; missing-motion de-dupe is file-scope `std::set` in avatar/. Tools/Config were not in 45-46. F3 stays `[~]`.
- [~] F3. Real manual QA
  - Run `--offline-room` + `--autotest-frames` on 3 rooms; both runs must give the same hash.
  - Organize M1–M6.md into a final manual acceptance checklist for the user. Once the user has played through it in person (`run.bat Release`), they give an explicit okay.
  Machine gate parent-verified 2026-10-09: six 900-frame hashes match (RelWithDebInfo at 19:15, Release at 19:20–23). That table is stale after 41-44.
  Machine gate parent-verified 2026-10-11 after 41-44 (`ses_ed8bb867affeRiRaIoBuMm4Kq7`, evidence `F3-manual-qa-after-41-44.md` last line `MACHINE_GATE: PASS`, log `F3-g5-after-41-44.txt`). RelWithDebInfo exe 19962880 bytes, 2026-10-11 01:32:40, dirty-tree build. Six sequential 900-frame pairs on cwd Content, all EXIT=0: 2010101 `040cd83ac5ba9b55`, 2071501 `ffb825e92024d73d` (unchanged vs 10-09), 30002 `1dc3eecaca364898` (matches F1). 2010101 moved from `6231c7ecb324ea6f`; 30002 moved from `3325585ada0f3232`. 20002 mage 300-frame pair cited from F1: `bc37c5a5d6618b1e`. `M-FINAL.md` refreshed (exe stamp, section 5b unchecked W8 items, section 6 new hashes). RelWithDebInfo is NDEBUG and does not prove todo 42. BLOCKED on fangcheng play-through of `M-FINAL.md`. Start interactive play with `cd AxmolFighter-Client; run.bat RelWithDebInfo`. Offline: from `AxmolFighter-Client\Content` launch `--offline-room=20002 --offline-role=mage` (also 30002|2010101|2071501).    Do not mark `[x]` until todos 41-46 are `[x]` AND fangcheng checks the M-FINAL items (including room 20002 mage: no por bind spam, no SpineBody duration assert, key-release stops, camera follows, no Avatar motion-miss flood, Up+Right diagonal, opposing last-wins then fallback) and says an explicit okay.
  Machine gate parent-verified 2026-10-11 after 45-46 (`ses_ed69b642ffferz12tQqFezoLly`, evidence `F3-manual-qa-after-45-46.md` last line `MACHINE_GATE: PASS`, log `F3-g5-after-45-46.txt`). Parent independently: RelWithDebInfo exe 19968512 bytes, LastWriteTime 2026-10-11 13:23:39 (after `8036f64` 11:45:21); Client HEAD `8036f64299835e2cd85a495eb253a8fc7f3170fd`; `LocalBattleMode.cpp` still dirty/unstaged. Eight sequential cwd-Content pairs all EXIT=0: 2010101 `040cd83ac5ba9b55`, 2071501 `ffb825e92024d73d`, 30002 `1dc3eecaca364898`, 20002 mage 300 `bc37c5a5d6618b1e` (unchanged vs 41-44; empty autotest input can keep the hash after todo 46). Transcript Avatar miss lines are once per `(file, name)` not a flood. RelWithDebInfo is NDEBUG and does not prove todo 42. `M-FINAL.md` section 0/6 refreshed; section 5b/7 stay unchecked. F3 stays `[~]`.
- [x] F4. Ideal-state fidelity
  - Compare against the IS-1..IS-8 rows one by one. Each row needs a passing scenario test and evidence.
  - Any shortfall becomes a new `- [ ] N.` todo, not a note.
  Parent-verified APPROVE 2026-10-09 after 35-38. Original REJECT (`ses_edfa371f1ffeId7C1Y4Vh50ckl`, `F4-ideal-state.md`) named four IS-1 gaps; those todos are now `[x]` with parent-rerun filters: sprint `f4182a0` `*Sprint*` 4/33 via `dealButtonEvent`; dodge `10c4e52` `*Dodge*` 2/33 slot F DODGE; crazy `e40a850` `*Crazy*` 2/24 BuffCrazy then `A+`; SkillButton `f359f9a` `*SkillButton*` 4/69 ATKB/C/D + JOY1 through `dealWithButton`. IS-2..IS-8 unchanged PASS. Independent of todo 39. Independent-reviewer re-dispatch skipped: executor quota exhausted.
  Parent-verified APPROVE 2026-10-11 after 41-44 (`ses_ed8dd3d95ffe2TVYYLp0L4Kul3`, evidence `F4-ideal-state-after-41-44.md`, literal `VERDICT: APPROVE`). Parent independently: `MotionClipDurationTest.cpp` has three `TEST_CASE`s matching the live `*clip duration*,*stored duration*` 3/9/0 (assignment text 4/30 was wrong; `task-42.md` already recorded 3/9); filter log `F4-rerun-after-41-44-filters.log` Sprint 4/33, Dodge 2/33, Crazy 2/24, SkillButton 4/69, locomotion 12/123, Portal 6/88, Determinism 4/5096, all EXIT=0; camera from `task-44.md` player x 950→1932 / view -139→-1036 plus F1 G5 `bc37c5a5d6618b1e`. No new `- [ ]` todos. F3 stays `[~]`.
  Parent-verified APPROVE 2026-10-11 after 45-46 (`ses_ed6b57bbbffeBdXH3ibrBWYMTL`, evidence `F4-ideal-state-after-45-46.md`, literal `VERDICT: APPROVE`) on Client HEAD `8036f64299835e2cd85a495eb253a8fc7f3170fd`. Parent independently: filter log `F4-rerun-after-45-46-filters.log` Sprint 4/33, Dodge 2/33, Crazy 2/24, SkillButton 4/69, locomotion 20/156 (was 12/123), Portal 6/88, clip 3/9, Determinism 4/5096, Missing-avatar 3/14, all EXIT=0. IS-1 includes todo 46; IS-8 includes todo 45. Camera still `task-44.md`. RelWithDebInfo 01:32:40 is pre-45/46 and is not this proof. No new `- [ ]` todos. F3 stays `[~]`.

## Commit strategy
- One commit or more per todo, split by subrepo: `AxmolFighter-Client`, `AxmolFighter-Client/Content` (config.bin/avatar.bin), `AxmolFighter-Tools`, `AxmolFighter-Config`, all on the `mugen-rewrite` branch.
- Commit messages: English, `type(scope): summary` (feat/fix/refactor/test/docs/data). Run `format_code.ps1` on changed C++ before committing.
- No push. Do not change the root repo's submodule pointers. Do not commit the root repo; `.omo/` and root docs are handled by the user.
- Never use `--no-verify`. If a hook fails, fix the issue and commit again.

## Success criteria
> One row per IS row. The plan is complete only when every IS row has a delivering todo and a proving QA scenario; F4 checks the delivered behavior against these rows 1:1, and a shortfall becomes new `- [ ] N.` rows, never a note.

| IS | Delivering todo(s) | Proving QA scenario | Evidence |
| --- | --- | --- | --- |
| IS-1 | 14, 15, 17, 18, 19, 20, 35, 36, 37, 38, 43, 44, 46 | `*Skill*`, `*AttackTree*`, `*AttackRole*`, `*Effect*`, `*Sprint*`, `*Dodge*`, `*Crazy*`, `*SkillButton*`, locomotion release + camera follow + diagonal last-wins + M2 manual check | task-17..20, task-35..38, task-43, task-44, task-46, M2.md |
| IS-2 | 28 | `*Ai*` scenarios + M5 manual check | task-28, M5.md |
| IS-3 | 21, 22, 23, 24, 25, 26, 27 | damage golden test, `*HitState*`, `*Buff*`, `*Ability*` | task-21..27, M3.md, M4.md |
| IS-4 | 29, 30, 41 | `*Room*`, portal bind-skip + full-run scenario | task-29, task-30, task-41, M6.md |
| IS-5 | 4, 5, 6, 7, 12, 31 | `*Determinism*`, snapshot/clone tests | task-31 |
| IS-6 | 8, 9, 10, 11 | converter selftest, pack report, failure path with a bad table | task-8..11 |
| IS-7 | 16 | `TownPuppetTest` + M1 manual check | task-16, M1.md |
| IS-8 | 2, 3, 12, 15, 45 | headless tests, check_rules, offline autotest, Avatar motion-miss once-log | task-2, task-3, task-15, task-45 |
