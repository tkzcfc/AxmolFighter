# AxmolFighter

格斗游戏项目：Axmol C++ 客户端 + Rust 分布式服务端 + C++ 战斗服，战斗逻辑客户端与战斗服共用一套代码。

## 仓库结构

```text
AxmolFighter/
├── AxmolFighter-Client/          # C++ 客户端（Axmol 引擎 + CMake）
│   └── Source/
│       ├── AppDelegate.cpp / MainScene.cpp   # 入口
│       ├── 3rd/     # protobuf-lite、spine 3.4
│       ├── net/     # protobuf-lite 生成代码和客户端网络层（yasio）
│       ├── mugen/   # 自研战斗/动作逻辑，battle 复用（见下）
│       ├── ui/      # FairyGUI UI
│       ├── resource/ # 通用异步资源加载器（gameres 命名空间），见下
│       └── utils/   # 通用工具
├── AxmolFighter-Config/          # 配置源表（table/*.lua），由工具打包成 config.bin
├── AxmolFighter-Server/
│   ├── game/        # Rust workspace：gateway / game / town / protocol / backend-framework
│   └── battle/      # C++ 战斗服（复用客户端 mugen）
├── AxmolFighter-Tools/           # 协议生成、配置转换、Spine 导出等工具
├── AxmolFighter-UI/              # FairyGUI 工程
├── AxmolFighter-Editor/          # 场景/资源编辑器
├── Reference/                    # 参照工程（黑月）对照文档
│   ├── heiyue-结构.md            # 入口：启动、src 分层、有效/死代码、帧循环、文件索引
│   ├── heiyue-战斗逻辑.md        # 参照战斗流程（带文件/函数行号）
│   ├── heiyue-战斗配置.md        # 参照配置表全字段说明
│   └── heiyue-AI与行为树.md      # AEBT 行为树与 behaviac AI
└── heiyue/                       # 参照工程源码（非 submodule；整目录 gitignore，本地自备）
```

> 「黑月」是战斗语义的参照工程。对照文档全部在 `Reference/` 下；实现代码（`AxmolFighter-Client/Source/**`、`AxmolFighter-Server/**`）中不得出现该产品名或盘符路径。

## 战斗核心（mugen）

`AxmolFighter-Client/Source/mugen` 是战斗唯一实现，客户端与 `AxmolFighter-Server/battle` 共用；改战斗逻辑两边一起生效。

| 子目录 | 职责 |
|--------|------|
| `core/` | 数学、反射、序列化、ECS、行为树内核。不依赖引擎 |
| `conf/` | 配置结构体、`Config` 加载、职业 id 换算（`TypeConversions`） |
| `avatar/` | 角色表现：逻辑侧（`MotionPlayer`、外观解析、`AvatarPaths`）在根目录，渲染侧在 `avatar/render/` |
| `render/` | 仅客户端：Spine 后端、`LayerRuntimeLoader`、`VirtualCamera` |
| `sim/` | 战斗逻辑（重写中）：`World` tick 管线、ECS 组件/单例登记、帧输入与表现事件、`.mgrp` 回放与 `mugen_sim_cli`；`ability/` 是组件化特殊能力池，按技能、命中、Buff 和角色生命周期事件稳定分派 | 

旧玩法层（对象图式技能/Buff/AI/特效、联网战斗）已删除，战斗由 `sim/` 重建。`sim/` 目前实现完整的单人战斗：`World::tick` 按固定顺序推进（时钟 → 逻辑定时器 → 控制事件 → 相机/慢放 → 实体组 Role/Effect/Obstacle/Goods/Portal → 场景 → 碰撞 → `flushDestroyed`）；组件与单例登记表在 `sim/Components.h` / `sim/Singletons.h`；帧输入由 `FrameInput` / `PlayerCommand` / 系统命令 / puppet 更新组成；`PresentationEvent` 队列承载表现层事件，`LogicTimers` 提供逻辑定时器。`sim/Replay` 定义 `.mgrp` 回放格式，配套 `mugen_sim_cli`（`replay` / `run-room` / `record-room` / `--compare`）与测试侧 `TestsHeadless/support/ScenarioHarness` 无头驱动。

`core/bt` 已拆成共享定义与值实例：`BTDef<Param>` 保存只读 DFS 节点、条件和参数池，派生直接子节点索引表（`firstChild` 指向该表）与紧凑叶状态索引；`BTInstance<LeafState>` 通过 `MG_REFLECT` 保存节点状态、int16 游标、Parallel 运行集、条件状态和叶状态。`BTRunner<Context, Param, LeafState>` 是瞬时执行视图，`BTRegistry` 仅存函数指针。Context/参数/叶状态由 sim 定义；当前仅 `TestsHeadless/tests/BTTestTypes.h` 提供测试 variant。`std::monostate` 在归档中为零字节载荷，variant 仍写 u8 标签。

组件快照只保存定义 key + instance；`BTDefCache<Key, Param, Config>` 用不可变配置和构建函数按 key 重建拓扑，缓存须比 runner 活得久。Selector 不抢占，成功后环形尝试其他兄弟；Sequence 忽略子节点 Failure；组合节点运行期间守卫失效返回 Success。退出先处理运行子节点，再将父游标/状态复位，最后逆序退出运行条件。Parallel 的 update 永不 Failure，但 enter 在守卫拒绝或无子节点可进入时返回 Failure。根停止只记一次错误，不自动重启。空 Sequence 在定义构造时拒绝。

`core/ecs` 已改为数据 ECS：`Entity` 是低 20 位 index、高 12 位 generation 的句柄，0 无效。`ECSManager<ComponentTuple, SingletonTuple>` 按登记顺序固定类型 id，以 sparse/dense 数组保存可拷贝的反射组件，tuple 保存单例。当前登记表仅在 `TestsHeadless/tests/EcsTestTypes.h`，生产 `sim/Components.h` / `Singletons.h` 在 World 阶段接入；核心不依赖测试头文件。

`destroy` 只标记，实体到 `flushDestroyed` 才失效；按销毁请求顺序进入 FIFO 空闲表，存活列表稳定压缩，generation 用尽的 slot 永久退役。`each<Ts...>(fn)` 按创建顺序、调用开始时的固定上界遍历，回调参数是 `(Entity, Ts&...)`。遍历中可创建/标记销毁，禁止 flush；组件池增删后须重新 `get/tryGet`，不能继续使用可能已失效的引用。快照包含 slot（含待销毁次序及下一创建序号）、创建顺序、FIFO、按类型 id 排列的组件池和单例；反序列化只接受从未分配 slot 的空 manager，失败不写入目标。`clone` 深拷贝，`hash` 对快照字节使用 xxh64。System 仅保留 `update(sim::World&)` 接口。

`sim/ai` 是怪物决策层，独立于角色状态机 `sim/role/brain`。`AiRules.h` 的 `kMonsterRules` 是 constexpr 条件表，每行最多三项判断，对应一个动作，可附带进入警戒和冷却，按优先级从高到低匹配：未警戒时，被激怒或在索敌范围内发现目标就释放 X 槽醒技能并进入警戒；巡逻结束后释放 Z 槽待机技能；其余情况巡逻。警戒后有目标时，技能间隔就绪或连段等待续接就释放最优普通技能；目标在追击范围外就追击；否则在警戒范围内游走。`AiDriver` 每帧在控制输入和角色状态机之前运行：先选目标（嘲讽优先；未警戒时取索敌范围内的目标；警戒后目标失效则从候选者中随机重选），再用 `gather()` 生成只读的 `AiFacts`，由 `pickRule` 选出第一条命中且不在冷却的规则。攻击中不做决策，移动中只允许更高优先级的规则抢占。动作只通过 `Role::changeStatus` 切换状态，由状态机中的 `CastState` / `AiMove` 执行。`AiAgent` 组件保存警戒、上次动作、规则冷却、技能间隔、十秒仇恨计时和按首次命中排序的伤害记录；进入警戒后不再清除。普通槽走 SkillAi 自动施放条件，X/Z 槽不走。嘲讽读取 `BuffHolder::sneerTarget` 并覆盖目标。巡逻和游走按 X、Z 顺序抽取偏移，移动叶子进入后抽取停留时长，全部使用本场 RngState。`WorldSetup::m_aiEnabled`（`mugen_sim_cli --ai off`）可整体关闭怪物决策：`TestsHeadless/data/replays/effects/` 是关 AI 的验收基线，`effects_ai/` 是开 AI 的基线。自动战斗、走向传送门不在此实现范围。

## 配置流水线
`sim/room/RoomEntities` 装配战斗房间的门、障碍和物品：门采用 Close/Active/Transfer 三阶段，Fight_End 开放 Room 类型门；碰撞请求延迟到帧尾调用 `World::changeRoom`，保留玩家与 `isPassRoom` 角色句柄和池状态。门位置读取已转换的 `portalPosX/Z`，不依赖已删除的地图实体槽节点。障碍按受击次数销毁，死亡掉落由 HitHooks 接入，物品抛射完成后可拾取并施加 Buff。特效按 summonFrame 创建角色，出生前建立归属并继承属性；寿命按逻辑毫秒推进，标准伤害递归读取主人。Finding 已接入单目标点走跑叶子。网络 Stage/Camp 传送和宠物不在该实现中。

`sim/room/RoomDirector` 在创建主控角色后显式启用，房间配置、状态队列、30ms 转换等待、波次和复活预算保存在 `RoomState`。场景阶段处理清场、Clear/Defense/Survive 和胜负事件；Defense 的 2 秒倒计时由 `LogicTimers` 驱动。非普通清场房的首领全部死亡时启动 `SlowMotion` 中的 `KoSlowMotion`，按未缩放固定秒数推进降速、保持、恢复三段曲线。复活和返回城镇通过 `FrameInput.systemCommands`；客户端先消费帧结果，再切换城镇视图。房间提示与胜负只发出表现事件，不调用结算网络或自动传送。

1. 源表在参照工程 `heiyue/src/imports/table`。
2. `AxmolFighter-Config/table/*.lua` 是转换后的扁平表。
3. 纯 C++ 打包工具 `config_converter` 用 `conf/ConfigTables.h` 的 `MG_CONFIG_TABLES` 注册反射结构，严格读取全部 42 种 Lua 表并序列化为 `AxmolFighter-Client/Content/mugen/config/config.bin`。C++ 结构体字段必须与 Lua 表一一对应；多余字段、缺失字段、类型错误、非整数写入整数字段和重复 id 会在一次检查中汇总报告。Import 按每种表的字段并集只补齐缺失键；equip/fashion 按 `(id, occupation)` 排序去重检查，五种 ordinal 音效表保留行序。文件头为 `MGCF + version + schemaHash`，运行时 schema 不匹配会拒绝加载。客户端统一使用 `conf/ReflectedConfig.h` 的 `mugen::conf::Config::instance()`，加载接口为 `load/loaded`；`find<T>/get<T>` 按登记策略接受 id、`{id, occupation}` 或从 1 开始的 ordinal，`findById/getById` 仅用于 KeyById 表。引用链使用可空 find，时装职业由角色 id 推导，职业行缺失时再查 occupation=0 的公共行：

```powershell
powershell -File AxmolFighter-Tools/config_converter/run_config_converter.ps1 --skip-configure
```

工具还提供 `scaffold <ConfigDir> <kind>`、`verify <ContentDir>` 与 `selftest` 子命令。`pack-avatar <ContentDir>` 扫描 Content（包括 `res_zhcn`）下的 `.box` / `.motion` 并写入 `Content/mugen/config/avatar.bin`；文件头为 `MGAV + version + schemaHash`，运行时 schema 不匹配会记录错误并拒绝加载。`spine-box` 和 `spine-box-list` 是 C++ Spine 碰撞框导出子命令。
数值超出目标整数或 Q44.20 Fixed 范围时，LuaReader 饱和到该类型边界；每种受影响表告警一次，并逐条输出原值与存储值。小数写入整数仍失败。`MG_CONFIG_REFS` 的全部引用边输出悬空数量与前五个样例，包括战斗链在内均只告警，不修改源 id；运行时遍历这些引用必须使用可空 `find`。

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
- 状态机经 `AvatarComponent::play` 驱动 `MotionPlayer`；渲染 `Avatar` 由 `AvatarPresenter` 跟随（动作变化时 setMotion + seek，漂移超过阈值时 seek 校正）。`MotionState` 是可序列化的播放标量，包含 `.motion` 路径、播放位置和速度。

## 资源加载器（Source/resource, 命名空间 gameres）

- 定位：异步预加载一批资源并驱动进度条。`View` 子类重写 `onPrepareLoad()` 声明要加载的资源；什么都不声明就不会出现加载界面，直接创建正式内容（见下面的“View 加载流程”）。
- `Resource`：资源描述基类，负责“加载什么”和持有加载结果；内置 `TextureResource` / `SpriteFramesResource` / `SpineResource` / `FguiPackageResource` / `AudioResource` / `ConfigResource` / `MapResource`，开发者可以继承它接入自定义类型。`ConfigResource` 在主线程解析全路径、工作线程反序列化；`MapResource` 只解析 `.layer` 的 JSON（`mugen::LayerRuntimeLoader::collectResources`，不建节点）再派生出 Spine/纹理/SpriteFrames/背景音乐子资源。`SpineResource` 按 ResSpine id 构造时，id 必须 `> 0` 才会走"按 id 查表"的路径（0 是"未配置"的常见哨兵值）。
- `ResourceLoaderRegistry`：按 `ResourceType` 注册加载函数（签名 `void(std::shared_ptr<T>, const LoadTaskPtr&)`）和进度权重；`ResourceLoader::add<T>(...)` 按“类型 + key”去重，只能在 `start()` 之前调用；`LoadTask::spawn<T>(...)` 可以从一个资源内部派生子资源（受同一并发上限调度，均分计入父资源进度，不计入总权重），用于组合型资源（`FguiPackageResource` 派生图集纹理、`MapResource` 派生地图引用的各类资源）。
- 进度：`Σ(weight_i * progress_i) / Σ(weight_i)`，权重只由注册表按类型配置（默认 FGUI 包 10、Map 10、Spine 3、Config 2、其余 1）；复杂类型可以调大权重避免进度卡在接近 100% 不动。有任务结束时才触发 `onProgress`；失败的任务也算结束，失败列表可以通过 `getFailedResources()` 轮询。
- 帧预算：主线程上的加载工作（启动任务、`onChildrenDone` 收尾、`runOnWorker` 的 `then`）统一排队，每帧在 `setFrameBudget`（默认 8ms）内执行，超出部分顺延到下一帧，每帧至少执行一项。
- 生命周期：加载函数被调用过的资源（含失败的）由 `ResourceLoader` 持有，**析构时立即**调用 `releaseHold()`（不延迟）。调用方负责把 `ResourceLoader` 持有到真正不再需要这些资源的那一刻——典型用法是 `View` 把它持有到自己销毁为止（见下面的“View 加载流程”），这样加载完成的资源在整个 View 存活期间都不会被 `SpineSkeletonCache::purgeUnused()` 或 `FGUIPackageManager::unload()` 过早回收。需要资源比某个 View 活得更久（常驻资源）时，用 `std::shared_ptr` 让多个持有者共用同一个 `ResourceLoader`，最后一个持有者销毁时才真正释放（`AppContext::globalLoader()` 和 `LaunchView` 就是这么共用的）。
- FGUI 包预热 ATLAS 项纹理（随后调用 `UIPackage::getItemAsset` 完成接管）和 SPINE 项的图集纹理；SPINE 骨架只在 `fairygui::UIConfig::useSkeletonCache` 为 true 时才会写入 `fairygui::GCache`（该开关默认关闭）。`FGUIPackageManager::unload` 引用计数归零时按同一份 ATLAS/SPINE 清单从 `TextureCache` / `GCache` 精确释放，不调用全量 `removeUnusedTextures` / `clearSkeletonData`。SOUND 等其他项不处理。
- `gameres::addRoleSpine(loader, roleId)`：按角色 id 预热身体 Spine。路径和缩放只来自 `mugen::AvatarPaths::resolveRoleSpine`（`role.resSpineId` → `res_spine`），不再猜测城镇 `_city` 骨架，也不再给 `/hero/` 强制 0.25 缩放。

### View 加载流程（Source/ui/core）

- `View::onPrepareLoad()`：在这里通过 `getResourceLoader()`（本 View 专属的加载器，持有到 View 销毁为止）或 `setResourceLoader(外部共同持有的加载器)`（比如 `AppContext::globalLoader()`；本 View 只负责在它还没 `start()` 时调用 `start()`，销毁时只释放自己的引用，不影响其他持有者）添加资源。没有加载器就不会显示加载界面。资源就绪后创建正式内容并调用 `onEnter()`；World / 输入等主线程组装放在 `onEnter`。
- 加载界面统一是 `ui/widgets/common/LoadingLayer`（Common 包里的 `LoadingLayer` 组件），进度显示不是直接跟着真实进度跳动，而是经过 `ProgressSmoother`（纯函数，不依赖引擎）平滑：落后时按指数缓动追赶（带最低速度，保证追得上）；追上后朝着一个比真实进度略高、但不超过 95% 的上限缓慢“爬行”，让玩家感觉一直在动；全部完成后再用较快的匀速冲到 100%。
- 预加载失败时调用 `View::onResourceLoadFailed(failed)`，默认只打印警告并返回 `true`，继续创建正式内容（运行时按老办法自行处理资源缺失，比如 Avatar 身体贴不上就是个空壳，不影响城镇/副本正常进入）。返回 `false` 才算致命。`LaunchView` 覆盖这个函数，让配置表这类核心资源加载失败一律致命。致命时弹出“资源加载失败”对话框，确认后结束程序；View 会一直停留在 Loading 状态，同一个 View 实例只会触发一次。
- `TownView` / `GameView` 在 `onPrepareLoad` 里用 `MapResource` 预热 `.layer` 引用的资源；`initTown` / 战斗 `init` 放到 `onEnter`。
- `AppContext` 持有一个全局加载器（`globalLoader()`：目前是 `config.bin`、`avatar.bin`，以后可以继续加别的常驻资源），生命周期和 AppContext 相同（`std::shared_ptr`），由 `LaunchView` 通过 `setResourceLoader()` 共同持有并驱动加载。`UI/Common` 本身是同步加载的（`AppContext::create/destroy` 直接 `FGUIPackageManager::load/unload`，只读取包描述，图集等到用到时才解码），因为 `LaunchView` 的进度条和 `AppContext` 的断线遮罩都要用到它，必须在第一个 View 创建之前就绪。
- 启动流程：`MainScene` → `LaunchView`（驱动全局加载器）→ 加载完成后连接服务器 → `LoginView` → 登录成功 → `CharacterLobbyView`。
- `TownView`/`GameView` 在战斗重写期间只保留视图骨架：战斗区显示 `Battle is being rebuilt`，城镇显示占位文字并继续走 town 服进出场景。副本选择仍进入 `GameView`（本地房间 id），返回城镇按钮仍在。联网战斗入口已关闭。
- `ViewManager` 切换 View 时，`SpineSkeletonCache::purgeUnused()` 延后到新 View 进入 Active 之后才调度（而不是切换的那一刻）：新 View 的加载器这时已经把自己要用的共享数据标记为"在用"，不会被这次清理误删、又重新加载一遍（例如两个城镇之间来回传送，共用的英雄/传送门 Spine 不会被反复卸载重建）。

## 编码规范

- 注释可中文；运行日志、错误文本等面向运维的输出用英文。
- C++ 成员变量 `m_` 前缀；可反射的组件与配置结构体使用 `MG_REFLECT(...)`；继承 axmol `Object` 的类按「typedef Super → 公开方法 → 私有方法 → 私有成员 → 公开成员」排列。
- UI 代码用 `gameui` 命名空间（避开 `ax::ui`）；战斗代码用 `mugen` 相关命名空间与既有宏。
- Rust 按 `snake_case` / `CamelCase` 惯例。
- 不要对必有指针做空判断（`ECSManager::tryGet<T>()` 返回值可为空，`ensureXxx` 之后不必再判空）。

## 构建入口

| 目标 | 入口 |
|------|------|
| 客户端 | `AxmolFighter-Client/CMakeLists.txt` |
| battle | `AxmolFighter-Server/battle/CMakeLists.txt` |
| 配置转换 | `AxmolFighter-Tools/config_converter/run_config_converter.ps1` |
| 协议生成 | `AxmolFighter-Tools/protoc/run_proto_gen.ps1` |
| 编辑器 | `AxmolFighter-Editor/`（详见其 README） |

## 维护要求

修改目录结构、协议常量、帧格式、service_id、配置流水线或 mugen 架构时，同步更新本文件对应章节。
