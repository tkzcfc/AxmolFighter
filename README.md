# AxmolFighter

格斗游戏项目：Axmol C++ 客户端 + Rust 分布式服务端 + C++ 战斗服，战斗逻辑客户端与战斗服共用一套代码。

## 仓库结构

```text
AxmolFighter/
├── AxmolFighter-Client/          # C++ 客户端（Axmol 引擎 + CMake）
│   └── Source/
│       ├── AppDelegate.cpp / MainScene.cpp   # 入口
│       ├── 3rd/     # protobuf-lite、tinyexpr、behaviac 3.6.39（尚未接入编译）
│       ├── net/     # protobuf-lite 生成代码和客户端网络层（yasio）
│       ├── mugen/   # 自研战斗/动作逻辑，battle 复用（见下）
│       ├── ui/      # FairyGUI UI
│       ├── resource/ # 通用异步资源加载器（gameres 命名空间），见下
│       └── utils/   # 通用工具
├── AxmolFighter-Config/          # 配置源表（table/*.lua），由工具打包成 config.bin
├── AxmolFighter-Server/
│   ├── game/        # Rust workspace：gateway / game / town / protocol / backend-framework
│   └── battle/      # C++ 战斗服（复用客户端 mugen）
├── AxmolFighter-Tools/           # 协议生成、配置转换、sol 绑定、spine 导出等工具
├── AxmolFighter-UI/              # FairyGUI 工程
├── AxmolFighter-Editor/          # 场景/资源编辑器
├── Reference/                    # 参照工程（黑月）对照文档
│   ├── heiyue-结构.md            # 入口：启动、src 分层、有效/死代码、帧循环、文件索引
│   ├── heiyue-战斗逻辑.md        # 参照战斗流程（带文件/函数行号）
│   ├── heiyue-战斗配置.md        # 参照配置表全字段说明
│   └── heiyue-AI与行为树.md      # AEBT 行为树与 behaviac AI
└── heiyue/                       # 参照工程源码（Cocos2d-x Lua 完整项目；src/res 被 gitignore，以磁盘为准）
```

> 「黑月」是战斗语义的参照工程。对照文档全部在 `Reference/` 下；实现代码（`AxmolFighter-Client/Source/**`、`AxmolFighter-Server/**`）中不得出现该产品名或盘符路径。

## 战斗核心（mugen）

`AxmolFighter-Client/Source/mugen` 是战斗唯一实现，客户端与 `AxmolFighter-Server/battle` 共用；改战斗逻辑两边一起生效。

| 子目录 | 职责 |
|--------|------|
| `conf/` | `TableConfig.h`（配置结构体）+ `Config.h/cpp`（config.bin 加载） |
| `bt/` | 行为树对象图：`RoleTreeBuilder` / `SkillTreeBuilder` / `EffectTreeBuilder`，见其 README |
| `skill/` | `Skill` / `SkillManager` 施法对象图 |
| `buff/` | `Buff` / `BuffManager` 对象图 |
| `ai/` | `AiAgent` / `SkillAi` AI 对象图 |
| `effect/` | `Effect` 特效对象图 |
| `avatar/` | 角色表现：逻辑侧（`MotionPlayer`、外观解析）在根目录，渲染侧（`Avatar`/`SpineBody`/`AvatarAccessory`）在 `render/`（`#ifdef RUNTIME_IN_AXMOL`） |
| 组件 | ECS 组件在 `component/`、系统在 `system/`、动作叶子在 `bt/actions` |

### 系统顺序

`PhysicsSystem` → `AISystem` → `CombatSystem` → `BehaviorTreeSystem` → `DisplacementSystem`

战斗驱动唯一路径是 `BehaviorTreeSystem`；树由 Builder 按卡组重建，快照只存节点标量（DFS），恢复时按 `typeName` 回填。

## 配置流水线

1. 源表在参照工程 `heiyue/src/imports/table`。
2. `AxmolFighter-Config/table/*.lua` 是转换后的扁平表（`HACKER_DATA_INIT` 格式）。
3. 打包工具把 Lua 表转成 C++ 结构体并序列化为 `AxmolFighter-Client/Content/mugen/config/config.bin`：

```powershell
powershell -File AxmolFighter-Tools/config_converter/run_config_converter.ps1 --skip-configure
```

C++ 结构体字段必须与 Lua 表一一对应；Lua 没有的字段一律不进结构体，运行时需要的信息从已有列推导。打包脚本内置 smoke 校验。

## 网络与服务架构

服务端为 Rust 微服务 + C++ 战斗服：

| 服务 | service_id | 语言 |
|------|-----------:|------|
| game | 0 | Rust |
| battle | 1 | C++20 |
| town | 2 | Rust |

- 客户端只连 gateway；后端启动后向 gateway 注册，gateway 按 `msg_id` 范围路由。
- msg_id 范围：game 1–19999，battle 20000–29999，town 30000–39999；game↔battle 内部 60000–60999，game↔town 内部 61000–61999。
- 帧头：客户端 `len:u32 + cmd:u8 + msg_id:u16 + serial:i32`（11 字节）；后端多一个 `session_id:u32`（15 字节）；大端。
- serial：0 = push；请求 `-request_id`；响应 `request_id`；后端回包取负。
- 服务间转发外层是 `PB::Gateway::ForwardToServerReq`（cmd=GatewayControl），payload 为完整后端帧。

## Protobuf

- proto3 + `optimize_for = LITE_RUNTIME`；每个业务消息内嵌 `MsgId` 枚举，C++ 用 `PB::Game::FooReq::Id` 取协议号。
- `.proto` 源文件在 `AxmolFighter-Server/game/protocol/pb/`：
  - `client_game.proto`（PB.Game）/ `client_battle.proto`（PB.Battle）/ `client_town.proto`（PB.Town）
  - 内部协议：`game_battle.proto`（PB.BattleInternal）/ `game_town.proto`（PB.TownInternal）
  - 纯类型统一放 `game_types.proto`（PB.Types）
- 生成：`AxmolFighter-Tools/protoc/run_proto_gen.ps1`。客户端协议输出到 `AxmolFighter-Client/Source/net/`，服务器内部协议输出到 `AxmolFighter-Server/battle/src/protocol/`（当前 `game_town.proto` 在忽略列表）。

## Battle 战斗服约定

- 单线程 yasio 事件循环；网络事件、RPC 超时和战斗 tick 在同一线程，框架路径不加锁。
- 不用 C++ coroutine / concurrencpp；异步结果统一回调。
- 周期逻辑用 yasio timer/scheduler，不在 `run()` 里写 while/sleep 主循环。
- 日志用 spdlog（控制台 + `logs/battle_server.log` 滚动），文本英文。
- 框架层 `src/framework/`：`BackendCodec`（帧编解码）、`GatewayClient`（连接注册重连）、`RpcManager`（pending/超时）、`BackendSession`（session 与 delegate）。业务通过 `BackendDelegate` / `SessionDelegate` 接入。
- 流程：game →(RPC)→ battle `BattleCreateReq/Resp`；客户端 `BattleInputPush` 经 gateway 路由到绑定实例。

## Avatar 模型

- 一个角色 = 一个 `.motion`（动作名 → 串接的 spine 动画 + `.box` 时间轴）。逻辑侧 `MotionPlayer` 与渲染侧 `Avatar` 绑定同一个 `.motion`，时长同源；快照只序列化 `.motion` 路径与播放标量。
- 事件只从逻辑侧 `.box` 收集（`MotionPlayer::step`），渲染不产生游戏事件。
- `Avatar`（渲染节点）= 一个身体 `SpineBody` + 若干挂件 `AvatarAccessory`（武器/翅膀/光环前后，规则见 `AvatarAccessoryRules.h`）。没有分层：Avatar 持有当前 Motion 与绝对时间，按绝对时间给身体摆 pose；挂件循环动画独立推进。
- 资源描述 `AvatarDesc`（骨架、atlas 列表、皮肤、缩放、`.motion`、挂件 ResSpine id、职业）；外观 `FashionAppearance` 经 `FashionResolver` 解析为 `AvatarDesc`。
- 加载方式 `AvatarLoadMode`：
  - `kSyncShared`：同步 + `SpineSkeletonCache` 共享数据（战斗单位、特效、固定展示），不可换装/嫁接。
  - `kAsyncExclusive`：异步 + 实例私有数据（UI 角色），就绪后浮现；`Avatar::setAppearance` 整体下发外观，身体 atlas/皮肤异步换装（最新请求优先），武器/翅膀数据嫁接到身体插槽。
- 换装原理：身体部位（发型/衣服/皮肤…）= 同一骨架换合并 atlas（attachment 按同名 region 重指）；武器/翅膀/光环 = 独立 spine 挂件，武器/翅膀的 attachment 同时嫁接到身体插槽用于动作表现。
- 帧动画（纸娃娃）资源的接入方式：离线转换为 spine（每部位一个 slot，attachment 时间轴 + drawOrder；每个部位的区域名一致的 atlas），直接复用 atlas 换装；`AniData`/`MotionEntryType::kAni` 仅保留数据类型，运行时不使用。
- Spine 数据归属在创建时确定（`MgSkeletonData::isExclusive`），不从 `use_count` 推断；共享缓存 key 为骨架 + 规范化 atlas 列表 + scale，切换 View 后 `purgeUnused`。
- 逻辑文件放 `mugen/avatar/` 根目录（禁止 include axmol/spine）；渲染文件放 `render/` 并整体 `#ifdef RUNTIME_IN_AXMOL`（battle CMake 自动排除）。
- 状态机经 `AvatarComponent::play` 驱动 `MotionPlayer`；渲染 `Avatar` 由 `AvatarRenderSystem` 跟随（动作变化时 setMotion + seek，漂移超过阈值时 seek 校正）。

## 资源加载器（Source/resource, 命名空间 gameres）

- 定位：异步预加载一批资源并驱动进度条。`View` 子类重写 `onPrepareLoad()` 声明要加载的资源和加载完成后要跑的初始化步骤；什么都不声明就不会出现加载界面，直接创建正式内容（见下面的“View 加载流程”）。
- `Resource`：资源描述基类，负责“加载什么”和持有加载结果；内置 `TextureResource` / `SpriteFramesResource` / `SpineResource` / `FguiPackageResource` / `AudioResource` / `ConfigResource` / `MapResource`，开发者可以继承它接入自定义类型。`ConfigResource` 在主线程解析全路径、工作线程反序列化；`MapResource` 只解析 `.layer` 的 JSON（`mugen::LayerRuntimeLoader::collectResources`，不建节点）再派生出 Spine/纹理/SpriteFrames/背景音乐子资源。`SpineResource` 按 ResSpine id 构造时，id 必须 `> 0` 才会走"按 id 查表"的路径（0 是"未配置"的常见哨兵值）。
- `ResourceLoaderRegistry`：按 `ResourceType` 注册加载函数（签名 `void(std::shared_ptr<T>, const LoadTaskPtr&)`）和进度权重；`ResourceLoader::add<T>(...)` 按“类型 + key”去重，只能在 `start()` 之前调用；`LoadTask::spawn<T>(...)` 可以从一个资源内部派生子资源（受同一并发上限调度，均分计入父资源进度，不计入总权重），用于组合型资源（`FguiPackageResource` 派生图集纹理、`MapResource` 派生地图引用的各类资源）。
- 进度：`Σ(weight_i * progress_i) / Σ(weight_i)`，权重只由注册表按类型配置（默认 FGUI 包 10、Map 10、Spine 3、Config 2、其余 1）；复杂类型可以调大权重避免进度卡在接近 100% 不动。有任务结束时才触发 `onProgress`；失败的任务也算结束，失败列表可以通过 `getFailedResources()` 轮询。
- 帧预算：主线程上的加载工作（启动任务、`onChildrenDone` 收尾、`runOnWorker` 的 `then`）统一排队，每帧在 `setFrameBudget`（默认 8ms）内执行，超出部分顺延到下一帧，每帧至少执行一项。
- 生命周期：加载函数被调用过的资源（含失败的）由 `ResourceLoader` 持有，**析构时立即**调用 `releaseHold()`（不延迟）。调用方负责把 `ResourceLoader` 持有到真正不再需要这些资源的那一刻——典型用法是 `View` 把它持有到自己销毁为止（见下面的“View 加载流程”），这样加载完成的资源在整个 View 存活期间都不会被 `SpineSkeletonCache::purgeUnused()` 或 `FGUIPackageManager::unload()` 过早回收。需要资源比某个 View 活得更久（常驻资源）时，用 `std::shared_ptr` 让多个持有者共用同一个 `ResourceLoader`，最后一个持有者销毁时才真正释放（`AppContext::globalLoader()` 和 `LaunchView` 就是这么共用的）。
- FGUI 包预热 ATLAS 项纹理（随后调用 `UIPackage::getItemAsset` 完成接管）和 SPINE 项的图集纹理；SPINE 骨架只在 `fairygui::UIConfig::useSkeletonCache` 为 true 时才会写入 `fairygui::GCache`（该开关默认关闭，且 `GCache` 没有按需释放接口）。SOUND 等其他项不处理。
- `gameres::addRoleSpine(loader, roleId, preferCity)`：按角色 id 预热身体 Spine，和 `mugen::actor_spawner::resolveRoleSpine` 共用同一套路径/缩放规则（城镇 `_city` 覆盖、`/hero/` 默认缩放 0.25），确保预加载和运行时查询 `SpineSkeletonCache` 用的是同一个 key；跨客户端/战斗服共享，改动需要两边都重新编译。
- `mugen::GameWord::resolveMap(mapId)`：Town/Room/Camp 共用一个 mapId 空间解析出 mapKey 和对应配置的纯查表函数，只读配置不加载任何东西；`loadMap` 和 `TownView`/`GameView` 的预加载都调用它，确保两边解析规则一致（包括联网对战时服务器下发的 mapId）。

### View 加载流程（Source/ui/core）

- `View::onPrepareLoad()`：在这里通过 `getResourceLoader()`（本 View 专属的加载器，持有到 View 销毁为止）或 `setResourceLoader(外部共同持有的加载器)`（比如 `AppContext::globalLoader()`；本 View 只负责在它还没 `start()` 时调用 `start()`，销毁时只释放自己的引用，不影响其他持有者）添加资源；再用 `addLoadStep(fn)` 添加资源就绪后要执行的初始化步骤（`fn` 返回 `false` 表示失败）。两者都没有就不会显示加载界面。
- 加载界面统一是 `ui/widgets/common/LoadingLayer`（Common 包里的 `LoadingLayer` 组件），进度显示不是直接跟着真实进度跳动，而是经过 `ProgressSmoother`（纯函数，不依赖引擎）平滑：落后时按指数缓动追赶（带最低速度，保证追得上）；追上后朝着一个比真实进度略高、但不超过 95% 的上限缓慢“爬行”，让玩家感觉一直在动；全部完成后再用较快的匀速冲到 100%。
- 失败策略分两种：
  - **预加载的资源失败**：调用 `View::onResourceLoadFailed(failed)`，默认只打印警告并返回 `true`，继续执行初始化步骤（运行时按老办法自行处理资源缺失，比如 Avatar 身体贴不上就是个空壳，不影响城镇/副本正常进入）。返回 `false` 才算致命。`LaunchView` 覆盖这个函数，让配置表这类核心资源加载失败一律致命。
  - **初始化步骤失败**（`addLoadStep` 的 `fn` 返回 `false`）：固定视为致命，没有覆盖点。
  - 致命时弹出“资源加载失败/初始化失败”对话框，确认后结束程序；View 会一直停留在 Loading 状态，同一个 View 实例只会触发一次。
- `AppContext` 持有一个全局加载器（`globalLoader()`：目前是 `config.bin`、`avatar.bin`，以后可以继续加别的常驻资源），生命周期和 AppContext 相同（`std::shared_ptr`），由 `LaunchView` 通过 `setResourceLoader()` 共同持有并驱动加载。`UI/Common` 本身是同步加载的（`AppContext::create/destroy` 直接 `FGUIPackageManager::load/unload`，只读取包描述，图集等到用到时才解码），因为 `LaunchView` 的进度条和 `AppContext` 的断线遮罩都要用到它，必须在第一个 View 创建之前就绪。
- 启动流程：`MainScene` → `LaunchView`（驱动全局加载器）→ 加载完成后连接服务器 → `LoginView` → 登录成功 → `CharacterLobbyView`。
- `TownView`/`GameView` 的 `onPrepareLoad` 会预加载地图（`MapResource`）、传送门/怪物的 Spine（`addRoleSpine`）和本地玩家的身体 Spine（`gameui::resolveLocalPlayerRoleId()`，和 `LocalBattleMode` 共用同一套角色解析/兜底规则），再把 `initGameWord`/`createLocalPlayer`/战斗模式初始化作为 step 跑；联网对战靠 `world_dump` 还原 Avatar，不会重复预加载本地玩家数据。
- `ViewManager` 切换 View 时，`SpineSkeletonCache::purgeUnused()` 延后到新 View 进入 Active 之后才调度（而不是切换的那一刻）：新 View 的加载器这时已经把自己要用的共享数据标记为"在用"，不会被这次清理误删、又重新加载一遍（例如两个城镇之间来回传送，共用的英雄/传送门 Spine 不会被反复卸载重建）。

## 编码规范

- 注释可中文；运行日志、错误文本等面向运维的输出用英文。
- C++ 成员变量 `m_` 前缀；继承 `Object` 的类按「typedef Super → 公开方法 → 私有方法 → 私有成员 → 公开成员 → 序列化宏」排列；标量序列化用 `MG_DEFINE_SERIALIZABLE(...)`。
- UI 代码用 `gameui` 命名空间（避开 `ax::ui`）；战斗代码用 `mugen` 相关命名空间与既有宏。
- Rust 按 `snake_case` / `CamelCase` 惯例。
- 不要对必有指针做空判断（如 `MG_GET_COMPONENT` 返回值可为空，`ensureXxx` 之后不必再判空）。

## 构建入口

| 目标 | 入口 |
|------|------|
| 客户端 | `AxmolFighter-Client/CMakeLists.txt` |
| battle | `AxmolFighter-Server/battle/CMakeLists.txt` |
| 配置转换 | `AxmolFighter-Tools/config_converter/run_config_converter.ps1` |
| 协议生成 | `AxmolFighter-Tools/protoc/run_proto_gen.ps1` |
| sol 绑定 | `AxmolFighter-Tools/sol_binding/run_sol_binding.ps1` |
| 编辑器 | `AxmolFighter-Editor/`（详见其 README） |

## 维护要求

修改目录结构、协议常量、帧格式、service_id、配置流水线或 mugen 架构时，同步更新本文件对应章节。
