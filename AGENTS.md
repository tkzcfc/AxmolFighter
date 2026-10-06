# AxmolFighter — Agent Guide

A fighting game. The client is C++ on the Axmol engine. The backend is Rust microservices plus a C++ battle server. One battle core, `AxmolFighter-Client/Source/mugen`, is compiled into both the client and the battle server.

The main architecture doc is `README.md`, written in Chinese UTF-8. In PowerShell, read it with `Get-Content -Encoding utf8`. **Update README.md** when you change the directory layout, protocol constants, frame format, service_id, config pipeline or mugen architecture.

## Layout (all git submodules)
| Dir | What | Details |
|---|---|---|
| `AxmolFighter-Client` | Axmol C++ client and shared `mugen` battle core | `AxmolFighter-Client/AGENTS.md` |
| `AxmolFighter-Server` | Rust gateway/game/town services and C++ battle server | `AxmolFighter-Server/AGENTS.md` |
| `AxmolFighter-Config` | Source Lua config tables | `AxmolFighter-Config/AGENTS.md` |
| `AxmolFighter-Tools` | Codegen: config.bin, protobuf, sol bindings, Spine export | `AxmolFighter-Tools/AGENTS.md` |
| `AxmolFighter-Editor` | Axmol-based animation/hitbox/scene editor | `AxmolFighter-Editor/AGENTS.md` |
| `AxmolFighter-UI` | FairyGUI editor project (edited in the FairyGUI editor; no build) | — |
| `heiyue` | Reference game source (Cocos2d-x Lua). **Read-only** | see below |

The Axmol engine is not in the repo. It needs `AX_ROOT` and the `axmol` CLI from `tkzcfc/axmol@release_custom` (clone it, then run `pwsh $AX_ROOT/setup.ps1`).

## Global rules
- The project is unreleased. **Do not add compatibility layers or shims**; you may change interfaces.
- Comments may be in Chinese. **Log and error strings must be in English.**
- In comments under `Client/Source/**` and `Server/**`, never name the reference product (Chinese name, pinyin or English name). Also never cite `E:\...` paths or planning-doc paths. Describe what the code means instead.
- Don't add defensive null checks. `BTContext.entity` is always valid, and results after `ensureXxx` are never null. The one exception is `MG_GET_COMPONENT`, whose result can be null.
- C++ members use the `m_` prefix. Rust uses snake_case / CamelCase.

## Porting from heiyue
- Before porting, read the `Reference/heiyue-*.md` docs first, then only the specific `.lua` files they cite (`path:line`). **Don't bulk-scan `heiyue/src`.** Lua sources are UTF-8.
- Only systems that are actually loaded are authoritative: `SkillPool`, `SkillBase`, `AttackRole`, AEBT for roles and behaviac for AI.

## Cross-cutting pipelines
- **Config:** edit `AxmolFighter-Config/table/*.lua`, run `AxmolFighter-Tools/config_converter/run_config_converter.ps1`, and the output is `Client/Content/mugen/config/config.bin`.
- **Protocol:** edit `Server/game/protocol/pb/*.proto`, then run `Tools/protoc/run_proto_gen.ps1`. It generates code into `Client/Source/net/` and `Server/battle/src/protocol/`.
- **Rebuild both:** after changing `mugen`, protocol or config, rebuild the client **and** the battle server.

## Reference docs (`Reference/`, Chinese UTF-8)
| Doc | Contents |
|---|---|
| `heiyue-结构.md` | Entry doc: bootstrap, `src/` layers, live vs dead modules, frame loop, object graph, file index |
| `heiyue-战斗逻辑.md` | Runtime battle: casting, SkillPool/AttackRole, collision/hit, damage formula, hit states, buffs, displacement, hitstop, sync |
| `heiyue-战斗配置.md` | Every battle table: fields, readers, cross-refs, lookup chain |
| `heiyue-AI与行为树.md` | AEBT nodes, ROLE tree branches, leaf actions, behaviac AI |

The old `server-*.md` docs were removed; server design is summarised in `README.md` and `AxmolFighter-Server/AGENTS.md`.
