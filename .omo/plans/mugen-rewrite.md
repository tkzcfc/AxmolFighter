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
- **W7 Wrap-up:** 31 → 32. Then the final verification wave.

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
| 21 | 13 | 22 | 14–20 |
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
| 32 | 31 | F1–F4 | — |

## Todos
> Implementation + Test = ONE todo. Never separate. Every todo: read contract §0 first; finish with gates G1–G5 as applicable; write evidence; commit per sub-repo.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [ ] 1. Pre-flight: branches, clean-tree check, baseline record
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

- [ ] 2. Headless test project, rule-check script, server-side logging, rewrite of mugen/AGENTS.md
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

- [ ] 3. Remove the old gameplay layer and online mode, keep the client building
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

- [ ] 4. core/math: Fixed, FixedVec, FixedMath, Random API
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

- [ ] 5. core/reflect and serialize (additive, old mechanisms kept)
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

- [ ] 6. core/ecs: evolve into Overwatch-style ECS
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

- [ ] 7. core/bt: split definition from instance
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

- [ ] 8. Extend the import step: add missing tables, merge split tables, fix field names (Lua side only)
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

- [ ] 9. Pure C++ config converter skeleton: LuaReader, strict validation, scaffold
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

- [ ] 10. All config tables become reflected structs; runtime Config; repack config.bin
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

- [ ] 11. Migrate avatar data to reflection; pack avatar.bin in C++; spine-box export in C++; delete legacy mechanisms
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

- [ ] 12. sim/World infrastructure: tick pipeline, input, events, timers, snapshots, CLI, scenario harness
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

- [ ] 13. Character foundations: spawning, attributes, status bits, extra states, map region, motion and hitbox sampling
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

- [ ] 14. Displacement, ROLE/CITY tree templates, movement leaves
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

- [ ] 15. Presentation layer and local driver: Presenter, LocalBattleMode, ControlManager, debug panel, offline entry
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

- [ ] 16. Town adaptation (CITY mode, remote players as puppets) — milestone M1
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

- [ ] 17. SkillPool / SkillBase / SkillAi (data + logic)
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

- [ ] 18. Attack subtree building and attack conditions
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

- [ ] 19. AttackRole leaf (including the ActionAttack base class)
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

- [ ] 20. Effect entities: EFFECT tree, AttackEffect, lifecycle — milestone M2
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

- [ ] 21. Collision: 2D AABB in screen space, depth-radius filter, contact state machine
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

- [ ] 22. Hit flow and damage: dealWithHitX, damage formula, modifyHp, energy
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

- [ ] 23. Hit-reaction state leaves: Hit / HitSwitch / HitUp / HitDown / HitFloor / GetUp / Wake / Death / Revive — milestone M3
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

- [ ] 24. BuffPool core and BFEvent wiring
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

- [ ] 25. Buff rules: xstatus status classes
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

- [ ] 26. Buff rules: xbasic numeric classes
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

- [ ] 27. Special abilities (SpecialAbilityPool)
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

- [ ] 28. Monster AI: behaviac-semantics runtime, Entity.xml decision tree, AiAgent, movement leaves — milestone M5
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

- [ ] 29. Room flow: state machine, monster spawns, waves, win/lose, KO slow-mo, revive
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

- [ ] 30. Portals, room switching, obstacles, drops, summons, jostling — milestone M6
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

- [ ] 31. Determinism and golden test suite
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

- [ ] 32. Documentation updates
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

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [ ] F1. Plan compliance audit
  - Re-run the acceptance commands of every todo and gates G1–G5.
  - Each GAP row has a todo that closes it.
  - Combat data references: `kUnimplementedLeaf` = 0 and `kUnportedRule` = 0.
  - The "Must NOT have" items all hold (check with `git diff --stat` that the Server/Editor/UI/heiyue repos are untouched).
- [ ] F2. Code quality review
  - An independent reviewer reads the diff on the `mugen-rewrite` branch of Client/Tools/Config against its base and checks compliance with contract §0.4 (no floats, no unordered containers, no std::function, no engine headers, no defensive null checks, English logs, no product names).
  - Checks there is no dead code, no duplicated logic, and that every placeholder has been removed.
- [ ] F3. Real manual QA
  - Run `--offline-room` + `--autotest-frames` on 3 rooms; both runs must give the same hash.
  - Organize M1–M6.md into a final manual acceptance checklist for the user. Once the user has played through it in person (`run.bat Release`), they give an explicit okay.
- [ ] F4. Ideal-state fidelity
  - Compare against the IS-1..IS-8 rows one by one. Each row needs a passing scenario test and evidence.
  - Any shortfall becomes a new `- [ ] N.` todo, not a note.

## Commit strategy
- One commit or more per todo, split by subrepo: `AxmolFighter-Client`, `AxmolFighter-Client/Content` (config.bin/avatar.bin), `AxmolFighter-Tools`, `AxmolFighter-Config`, all on the `mugen-rewrite` branch.
- Commit messages: English, `type(scope): summary` (feat/fix/refactor/test/docs/data). Run `format_code.ps1` on changed C++ before committing.
- No push. Do not change the root repo's submodule pointers. Do not commit the root repo; `.omo/` and root docs are handled by the user.
- Never use `--no-verify`. If a hook fails, fix the issue and commit again.

## Success criteria
> One row per IS row. The plan is complete only when every IS row has a delivering todo and a proving QA scenario; F4 checks the delivered behavior against these rows 1:1, and a shortfall becomes new `- [ ] N.` rows, never a note.

| IS | Delivering todo(s) | Proving QA scenario | Evidence |
| --- | --- | --- | --- |
| IS-1 | 14, 15, 17, 18, 19, 20 | `*Skill*`, `*AttackTree*`, `*AttackRole*`, `*Effect*` + M2 manual check | task-17..20, M2.md |
| IS-2 | 28 | `*Ai*` scenarios + M5 manual check | task-28, M5.md |
| IS-3 | 21, 22, 23, 24, 25, 26, 27 | damage golden test, `*HitState*`, `*Buff*`, `*Ability*` | task-21..27, M3.md, M4.md |
| IS-4 | 29, 30 | `*Room*`, full-run scenario | task-29, task-30, M6.md |
| IS-5 | 4, 5, 6, 7, 12, 31 | `*Determinism*`, snapshot/clone tests | task-31 |
| IS-6 | 8, 9, 10, 11 | converter selftest, pack report, failure path with a bad table | task-8..11 |
| IS-7 | 16 | `TownPuppetTest` + M1 manual check | task-16, M1.md |
| IS-8 | 2, 3, 12, 15 | headless tests, check_rules, offline autotest | task-2, task-3, task-15 |
