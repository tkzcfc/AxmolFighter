# AxmolFighter

格斗游戏项目：Axmol C++ 客户端 + Rust 分布式服务端 + C++ 战斗服，战斗逻辑客户端与战斗服共用一套代码。

## 仓库结构

```text
AxmolFighter/
├── AxmolFighter-Client/          # C++ 客户端（Axmol 引擎 + CMake）
│   └── Source/
│       ├── AppDelegate.cpp / MainScene.cpp   # 入口
│       ├── 3rd/     # protobuf-lite、spine 3.4、vfs（vendored 运行时，编进客户端/战斗服/TestsHeadless）
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
| `sim_legacy/` | 现行战斗逻辑（已冻结为旧实现，命名空间 `mugen::sim_legacy`；新的 ECS 实现见 `AxmolFighter-Client/Source/mugen/DESIGN.md`）：`World` tick 管线、ECS 组件/单例登记、帧输入与表现事件、`.mgrp` 回放与 `mugen_legacy_cli`；`ability/` 是组件化特殊能力池，按技能、命中、Buff 和角色生命周期事件稳定分派 | 
| `sim/` | 新的 ECS 战斗实现（命名空间 `mugen::sim`，设计见 `DESIGN.md`，按切片 S0–S8 推进）：`Schedule.h` 的 `kSchedule` 是唯一帧调度表，系统为 `XxxSystem.cpp` 中的 `void runXxx(World&)`，系统间只通过组件与 `EventQueue` 单例通信。目前完成 S0 骨架与 S1（B1–B3）：出生/房间进入、位移与地图钳制、技能簿与时间轴（含取消窗口连招）、碰撞与命中微管线（伤害公式、顿帧、受击/受击恢复/死亡状态机）、KO 慢放、最小 Buff（`BuffList`、`buff::rules::admit/remove`、片段 Buff 进入准入/退出移除、霸体为 `StatusFlags` 引用计数 op 并阻止受击转移）、DebugSink 追踪行导出效果摘要。系统文件头固定写读/写/消费/产生四行；规则库在 `mugen::sim::<域>::rules`；事实/请求事件只经 `EventQueue` 单例传递，系统之间不互相调用。已通过摘要比对的场景：`class1_move`、`class1_a_dummy`、`class1_superarmor`（min/max）；其余场景留给后续切片。尚未接入客户端与战斗服 |

新旧实现并存期间的无头目标（`AxmolFighter-Client/TestsHeadless`）：`mugen_tests` / `mugen_legacy_cli` 只链接 `sim_legacy`，`mugen_sim_tests` / `mugen_sim_cli` 只链接 `sim`，任何二进制不同时链接两者。等价性用「效果摘要」金样比较：`mugen_legacy_cli export-summary` 从旧实现导出 `TestsHeadless/data/golden_summaries/<场景>.<min|max>.summary`（场景清单 `scenarios.txt`，固定暴击/浮动等抽取策略，AI 关闭），`compare-summary <golden> <actual> [--deviations known_deviations.txt]` 按 `DESIGN.md` 附录 A 的容差（帧 ±1、位置 ≤2 逻辑单位、伤害相等）比较；重新导出用 `run_summary_export.ps1`。新 sim 侧用 `mugen_sim_cli compare-scenario (--scenario <名称> --crit min|max | --all) [--manifest scenarios.txt]` 直接运行场景并与金样比对（在 `TestsHeadless` 目录下执行；清单缺失或不可读、任一场景失败时返回非零），`mugen_sim_cli run-summary` 只输出新 sim 的摘要。新增场景：在 `data/scenarios/` 写脚本、在 `scenarios.txt` 加一行、用 `mugen_legacy_cli export-summary` 导出 min/max 金样（不得改动已有金样）。`conf/battle/` 的运行时派生表（`SkillDef`/`ClipDef`/`EffectClipDef`/`EffectDef`/`HitDef`/`RoleDef`）由 `config_converter/lower/` 降级生成，见「配置流水线」。

职业映射约定：主角职业保持 `1..4`（对应 role id `101..104`）；伙伴职业作为独立职业扩展为 `5..7`（对应 role id `105..107`），不参与转职树。创角列表、基础介绍与创角时装选项由 `create_role` 表提供（`id` 即 `CharacterClass`）。创角请求中，`canSelectFashion=false` 的职业（伙伴）必须使用 `hair_id=0`、`clothes_id=0`，外观由 `role.resFashion` 回退链决定。

旧玩法层（对象图式技能/Buff/AI/特效、联网战斗）已删除，战斗由 `sim_legacy/` 重建（该目录现已冻结，不再改动；新实现按 `Source/mugen/DESIGN.md` 另建 `sim/`）。`sim_legacy/` 目前实现完整的单人战斗：`World::tick` 按固定顺序推进（时钟 → 逻辑定时器 → 控制事件 → 相机/慢放 → 实体组 Role/Effect/Obstacle/Goods/Portal → 场景 → 碰撞 → `flushDestroyed`）；组件与单例登记表在 `sim_legacy/Components.h` / `sim_legacy/Singletons.h`；帧输入由 `FrameInput` / `PlayerCommand` / 系统命令 / puppet 更新组成；`PresentationEvent` 队列承载表现层事件，`LogicTimers` 提供逻辑定时器。`sim_legacy/BattleBootstrap` 提供统一引导（`world.init + spawn + RoomDirector::enter`），离线客户端与 `mugen_legacy_cli replay` 复用同一路径。`sim_legacy/Replay` 的 `.mgrp` 头携带完整 `WorldSetup`（seed/mode/room/mapKey、玩家出生参数、stage/copy、AI 开关、是否启用 scenario hooks），配套 `mugen_legacy_cli`（`replay` / `run-room` / `record-room` / `--compare`）与测试侧 `TestsHeadless/support/ScenarioHarness` 无头驱动。

联机回滚由 `sim_legacy/rollback/RollbackSession` 提供（编译进客户端与战斗服，无引擎依赖）。会话持有 `World`、按固定深度 `kMaxRollbackFrames` 保存每帧快照，按槽位维护已确认/预测输入：本地槽位用 `addLocalInput` 提交预测，远端槽位缺失输入时重复该槽位最近一次确认输入；`addConfirmedInput` 接收服务器确认（乱序、重复幂等、冲突记错误），确认与已用预测不一致时回滚到最早不一致帧之前的快照并重推。预测帧数超过窗口深度时 `advanceTo/tick` 返回 false 停止推进（stall），避免快照被覆盖。`resync(frame, snapshot)` 采用服务器快照复位并丢弃旧历史。会话累计 `rollbacks/maxDepth/resimFrames/stalls/mispredictions` 统计，`mugen_legacy_cli rollback-sim` 用模拟延迟驱动会话并打印统计。

联机同步的服务器权威侧由 `sim_legacy/net/` 提供：`NetCodec` 用 `BinaryArchive` 将 `WorldSetup` / `PlayerInput` / `FrameInput` 编解码为确定性字节串（承载在 protobuf `bytes` 字段）；`LockstepAuthority` 持有唯一权威 `World`，按槽位接受输入（超前 `kMaxInputLead`(90) 帧拒绝、同帧重复提交保持首次；首次到达时目标帧已 tick 的迟到输入，非空命令且迟到不足 `kMaxLateCarryFrames`(12) 帧则顺延到下一帧执行、其余丢弃；`needsInput` 供调用方在解码前跳过重发，`inputStats` 给出迟到 / 顺延 / 丢弃累计与「到达富余帧数」窗口统计）、`step()` 推进下一帧并返回确认 `FrameInput`、每 `kHashInterval`(30) 帧记录确定性哈希、`outcome()` 返回 `BattleOutcome`、`serializeWorld` 产出重同步快照。`WorldSetup` 的玩家配置为 `std::vector<PlayerSetup> m_players`（`m_slot/m_roleId/m_class/m_level/m_camp/m_aiDifficulty/m_isAi`），`bootstrapBattle` 按该列表出生全部玩家并返回 `std::vector<Entity>`。缺帧输入在权威侧与客户端预测采用同一规则补空输入（攻击命令是边沿事件，只在按下那帧提交，因此补空不会丢招）。回放 `.mgrp` 格式 v4：`MGRP` 魔数 + 版本 4 + schemaHash + seed + `WorldSetup` + 连续帧输入。

表现事件带稳定身份以便回滚去重：`PresentationEvent` 新增每帧从零重计的 `ordinal` 字段（`seq` 仍为全局单调，仅供追踪输出与离线去重）；`RollbackSession` 收集各帧事件，按「帧 + 实体 + ordinal + 载荷」哈希去重后经 `eventsToPresent()` 输出，重推产生的同帧同内容事件被跳过、误预测产生的新事件照常呈现（不撤销已播放事件）。表现层 `WorldPresenter` 新增 `presentEvents(events, …)` 消费会话去重后的显式列表（不再按 `seq` 单调去重），离线 `LocalBattleMode` 仍走原 `present(world, …)` 路径，行为不变。
表现层显示节点复用与伤害飘字（`WorldPresenter`）：`AvatarPresenter` 按实体句柄逐帧比对外观身份（实体组 + 配置行 id + 是否绑定动作文件），回滚恢复快照后同一句柄指向另一个实体时回收并重建显示节点（同时丢弃该句柄的宠物与换装覆盖）。无时装的 Avatar / 无动作文件的 Spine 节点摘下后按外观键进入复用池（每键上限 8、合计上限 64，复位颜色/缩放后重放动作），`loadMap` 与表现层析构时清空；时装角色实例私有，不入池。`PresentationEvent` 的 `HurtNumber` 载荷携带 `m_critical`、`m_hasContact`、`m_contact`（命中接触点，屏幕平面），不进入追踪输出。伤害飘字用位图字体 `Content/mugen/font/hurt_{normal,hero,crit,word}.fnt`（共用图集 `hurt_number.png`，由参考战斗文字图集转出：玩家方伤害 / 敌方打玩家 / 暴击 / 未命中·闪避文字），`ax::Label::createWithBMFont` 按字体池化，按 50ms 步进播放 20 步（放大回落 → 停留 → 上升淡出），最多同时 64 条。新增 `Content` 资源后需重新 configure（`cmake -S AxmolFighter-Client -B AxmolFighter-Client/build`）才会进入 Xcode 产物。

伙伴怒气职业（roleId=107）在 sim_legacy 侧新增 `PartnerRageState` 组件：施法管线开始记录首段技能 `rage`，首次命中结算一次怒气，怒气满后可通过怒气槽位 `P`（`CTR_ATKQ`）触发变身；变身状态同步到 `MotionState::m_partnerRageTransformed`，并通过 `PresentationEvent::PartnerRageChanged` 通知表现层。对应配置由 `partner` 表提供 `roleId/partnerType/typeValue`（`partnerType=1` 表示怒气变身伙伴，`typeValue` 为冻结毫秒）。

连击与评价由 `sim_legacy/role/RoleCombo` 提供（临时视图，状态存 `RoleHitState`）：命中时 `HitResolver` 以 `effect.comboExp * m_parameterExp` 调用 `RoleCombo::add(exp, target)`，累加连击数并结算评价经验；`RoleActor` 每帧调用 `RoleCombo::update()` 推进连击超时（`kComboTimeMs` 2000ms）与按评价等级的每帧经验衰减。评价经验 `m_evaluateExp` 按 `kComboStageExp` 阈值（200/500/1000/1700/2500）映射为评价等级 `m_curEvaluate`，封顶 2500；击杀与眩晕各额外增加 `kComboKillExp`/`kComboStunExp`（50），首领（roleType 4）按 `kComboBossExpRate`（3）倍率结算，击杀奖励按目标去重（`m_comboKilledTargets`）。评价等级同步写入 `BuffExternalConditions::m_comboEvaluate` 供 Buff/能力条件读取；`BuffRules` 的连击规则按评价等级写入 `m_parameterExp` 倍率。


`core/bt` 已拆成共享定义与值实例：`BTDef<Param>` 保存只读 DFS 节点、条件和参数池，派生直接子节点索引表（`firstChild` 指向该表）与紧凑叶状态索引；`BTInstance<LeafState>` 通过 `MG_REFLECT` 保存节点状态、int16 游标、Parallel 运行集、条件状态和叶状态。`BTRunner<Context, Param, LeafState>` 是瞬时执行视图，`BTRegistry` 仅存函数指针。Context/参数/叶状态由 sim 定义；当前仅 `TestsHeadless/tests/BTTestTypes.h` 提供测试 variant。`std::monostate` 在归档中为零字节载荷，variant 仍写 u8 标签。

组件快照只保存定义 key + instance；`BTDefCache<Key, Param, Config>` 用不可变配置和构建函数按 key 重建拓扑，缓存须比 runner 活得久。Selector 不抢占，成功后环形尝试其他兄弟；Sequence 忽略子节点 Failure；组合节点运行期间守卫失效返回 Success。退出先处理运行子节点，再将父游标/状态复位，最后逆序退出运行条件。Parallel 的 update 永不 Failure，但 enter 在守卫拒绝或无子节点可进入时返回 Failure。根停止只记一次错误，不自动重启。空 Sequence 在定义构造时拒绝。

`core/ecs` 已改为数据 ECS：`Entity` 是低 20 位 index、高 12 位 generation 的句柄，0 无效。`ECSManager<ComponentTuple, SingletonTuple>` 按登记顺序固定类型 id，以 sparse/dense 数组保存可拷贝的反射组件，tuple 保存单例。当前登记表仅在 `TestsHeadless/tests/EcsTestTypes.h`，生产 `sim_legacy/Components.h` / `Singletons.h` 在 World 阶段接入；核心不依赖测试头文件。

`destroy` 只标记，实体到 `flushDestroyed` 才失效；按销毁请求顺序进入 FIFO 空闲表，存活列表稳定压缩，generation 用尽的 slot 永久退役。`each<Ts...>(fn)` 按创建顺序、调用开始时的固定上界遍历，回调参数是 `(Entity, Ts&...)`。遍历中可创建/标记销毁，禁止 flush；组件池增删后须重新 `get/tryGet`，不能继续使用可能已失效的引用。快照包含 slot（含待销毁次序及下一创建序号）、创建顺序、FIFO、按类型 id 排列的组件池和单例；反序列化只接受从未分配 slot 的空 manager，失败不写入目标。`clone` 深拷贝，`hash` 对快照字节使用 xxh64。System 仅保留 `update(sim_legacy::World&)` 接口。

`sim_legacy/ai` 是怪物决策层，独立于角色状态机 `sim_legacy/role/brain`。`AiRules.h` 的 `kMonsterRules` 是 constexpr 条件表，每行最多三项判断，对应一个动作，可附带进入警戒和冷却，按优先级从高到低匹配：未警戒时，被激怒或在索敌范围内发现目标就释放 X 槽醒技能并进入警戒；巡逻结束后释放 Z 槽待机技能；其余情况巡逻。警戒后有目标时，技能间隔就绪或连段等待续接就释放最优普通技能；目标在追击范围外就追击；否则在警戒范围内游走。`AiDriver` 每帧在控制输入和角色状态机之前运行：先选目标（嘲讽优先；未警戒时取索敌范围内的目标；警戒后目标失效则从候选者中随机重选），再用 `gather()` 生成只读的 `AiFacts`，由 `pickRule` 选出第一条命中且不在冷却的规则。攻击中不做决策，移动中只允许更高优先级的规则抢占。动作只通过 `Role::changeStatus` 切换状态，由状态机中的 `CastState` / `AiMove` 执行。`AiAgent` 组件保存警戒、上次动作、规则冷却、技能间隔、十秒仇恨计时和按首次命中排序的伤害记录；进入警戒后不再清除。普通槽走 SkillAi 自动施放条件，X/Z 槽不走。嘲讽读取 `BuffHolder::sneerTarget` 并覆盖目标。巡逻和游走按 X、Z 顺序抽取偏移，移动叶子进入后抽取停留时长，全部使用本场 RngState。`WorldSetup::m_aiEnabled`（`mugen_legacy_cli --ai off`）可整体关闭怪物决策，并随回放/快照归档，保证跨端重放一致：`TestsHeadless/data/replays/effects/` 是关 AI 的验收基线，`effects_ai/` 是开 AI 的基线。自动战斗、走向传送门不在此实现范围。

## 配置流水线
`sim_legacy/room/RoomEntities` 装配战斗房间的门、障碍和物品：门采用 Close/Active/Transfer 三阶段，Fight_End 开放 Room 类型门；碰撞请求延迟到帧尾调用 `World::changeRoom`，保留玩家与 `isPassRoom` 角色句柄和池状态。门位置读取已转换的 `portalPosX/Z`，不依赖已删除的地图实体槽节点。障碍按受击次数销毁，死亡掉落由 HitHooks 接入，物品抛射完成后可拾取并施加 Buff。特效按 summonFrame 创建角色，出生前建立归属并继承属性；寿命按逻辑毫秒推进，标准伤害递归读取主人。Finding 已接入单目标点走跑叶子。网络 Stage/Camp 传送和宠物不在该实现中。

`sim_legacy/room/RoomDirector` 在创建主控角色后显式启用，房间配置、状态队列、30ms 转换等待、波次和复活预算保存在 `RoomState`。场景阶段处理清场、Clear/Defense/Survive 和胜负事件；Defense 的 2 秒倒计时由 `LogicTimers` 驱动。非普通清场房的首领全部死亡时启动 `SlowMotion` 中的 `KoSlowMotion`，按未缩放固定秒数推进降速、保持、恢复三段曲线。复活和返回城镇通过 `FrameInput.systemCommands`；客户端先消费帧结果，再切换城镇视图。房间提示与胜负只发出表现事件，不调用结算网络或自动传送。PVP 1v1 决斗按 `WorldSetup::m_pvp` 分支（不按房间类型猜测）：禁用复活，出生位置不读房间 `actorPos*`，而按阵营分左右两队（阵营 2 在右 x=1900 朝左，其余阵营在左 x=300 朝右，同队按出生顺序占用 z=200/150/50；玩家阵营不得为中立 1：特效自身是中立阵营，敌对掩码互相校验使中立目标永远无法被特效命中，`bootstrapBattle` 会拒绝中立玩家，决斗双方应为 Our=2 对 Enemy=8），双方面对面，逐帧统计各阵营存活玩家英雄，一方被清空判 KO（启动 KO 慢放、双方禁用受击、`m_winnerCamp` 记胜者），超时则按剩余生命比例判定（相等判平局，本地按失败处理）；结果写入 `PvpRoundEnd{winnerCamp, reason, hp ratios}` 表现事件，限时与出生生命倍率来自 `WorldSetup::m_pvpTimeLimit`（默认 100 秒）与 `m_pvpHpScale`（出生时缩放基础生命与生命上限）。

1. 源表在参照工程 `heiyue/src/imports/table`。
2. `AxmolFighter-Config/table/*.lua` 是转换后的扁平表。
3. 纯 C++ 打包工具 `config_converter` 用 `conf/ConfigTables.h` 的 `MG_CONFIG_TABLES` 注册反射结构，严格读取全部 46 种 Lua 表并序列化为 `AxmolFighter-Client/Content/mugen/config/config.bin`。资源路径字段写成 VFS 虚路径 `/mugen/...`。进程入口创建唯一的 `VirtualFileSystem`，把 `Content` 挂到虚根 `/`；`mugen::io::setVfs` 让战斗核共用该对象。客户端 `VfsFileUtils` 通过 `FileUtils::setDelegate` 接管引擎读写：`/mugen`、`/UI` 等走 VFS，axslc 着色器仍走原生搜索路径。C++ 结构体字段必须与 Lua 表一一对应；多余字段、缺失字段、类型错误、非整数写入整数字段和重复 id 会在一次检查中汇总报告。Import 按每种表的字段并集只补齐缺失键；equip/fashion 按 `(id, occupation)` 排序去重检查，五种 ordinal 音效表保留行序。文件头为 `MGCF + version + schemaHash`，运行时 schema 不匹配会拒绝加载。客户端统一使用 `conf/ReflectedConfig.h` 的 `mugen::conf::Config::instance()`，加载接口为 `load/loaded`；`find<T>/get<T>` 按登记策略接受 id、`{id, occupation}` 或从 1 开始的 ordinal，`findById/getById` 仅用于 KeyById 表。`res_fashion.spine` 支持单 atlas 字符串和 atlas 列表（例如常态/变身双形态）；渲染侧按 `FashionAppearance::transformed` 选择列表索引 1，缺失时回退索引 0。引用链使用可空 find，时装职业由角色 id 推导，职业行缺失时再查 occupation=0 的公共行：

```powershell
powershell -File AxmolFighter-Tools/config_converter/run_config_converter.ps1 --skip-configure
```

工具还提供 `scaffold <ConfigDir> <kind>`、`verify <ContentDir>` 与 `selftest` 子命令。`pack-avatar <ContentDir>` 扫描 `mugen/` 下的 `.box` / `.motion`，以 `/mugen/...` 为 key 写入 `Content/mugen/config/avatar.bin`；文件头为 `MGAV + version + schemaHash`，运行时 schema 不匹配会记录错误并拒绝加载。`spine-box` 和 `spine-box-list` 是 C++ Spine 碰撞框导出子命令。
数值超出目标整数或 Q44.20 Fixed 范围时，LuaReader 饱和到该类型边界；每种受影响表告警一次，并逐条输出原值与存储值。小数写入整数仍失败。`MG_CONFIG_REFS` 的全部引用边输出悬空数量与前五个样例，包括战斗链在内均只告警，不修改源 id；运行时遍历这些引用必须使用可空 `find`。

新 sim 运行时表放 `conf/battle/`（命名空间 `mugen::conf::battle`，见 `Source/mugen/DESIGN.md` §9）：`SkillDef`/`ClipDef`/`EffectClipDef`/`EffectDef`/`HitDef`/`RoleDef`。它们是**派生表**（登记在 `MG_DERIVED_TABLES`，是 `MG_CONFIG_TABLES` 的子集），不读取 Lua，而是由 `config_converter` 在读完全部源表后、写盘前，用 `AxmolFighter-Tools/config_converter/lower/` 的纯函数（每族一个 `.cpp`：`SkillLower`/`ClipLower`/`EffectLower`/`HitLower`/`RoleLower`）从 `action`/`action_effect`/`effect`/`skill_hit`/`role`/`skill` 降级计算并按 id 排序，随归档一起进 `schemaHash`。降级把 `effectIds/effectFrames`、`cameraId/cameraFrame` 等平行数组合并为按帧排序的 cue 列表；`skill` 的抬起释放语义保留为 `SkillDef::releaseSequences`/`holdRelease`/`pressTimeMs`（`skillType==1` 的蓄力行为），仅丢弃纯表现层字段（`nameId`/`descId`/`icon`、`shadow`/`tier`/`vertexPos`/`resFashion` 等），并把悬空引用、平行数组不等长、异常字符串数据写入 `Content/mugen/config/lower_report.txt`（与 `config.bin` 同目录）；引用悬空只告警不判失败（源数据本身存在悬空引用，旧实现同样容忍）。

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

## 城镇同步模型（town）

城镇内角色同步采用「客户端本地预测 + 服务端权威校验 + 固定频率广播」，外观由 game 服权威下发。

### 消息一览

| msg_id | 方向 | 消息 | 说明 |
|---|---:|---|---|
| 30000 | C→town | `TownMoveReport` | 本地预测移动上报（≤10 Hz，起停/朝向变化即时） |
| 30001 | town→C | `ScenePlayerEnterPush` | AOI 内玩家进入（外观 + 运动状态） |
| 30002 | town→C | `ScenePlayerLeavePush` | AOI 内玩家离开 |
| 30003 | town→C | `ScenePlayerAppearancePush` | 玩家外观变化（换装/切宠物） |
| 30004 | town→C | `ScenePlayerStatesPush` | 固定 tick 批量状态广播（send-on-change，不含自己） |
| 30005 | town→C | `TownPositionCorrectionPush` | 仅发给发送者：权威位置校正 + 序号 |
| 1302/1303 | C↔game | `EnterSceneReq/Resp` | 进入城镇；Resp 携带场景内玩家快照（外观+运动） |
| 1308/1309 | C↔game | `LeaveSceneReq/Resp` | 离开城镇（进入本地副本等离线战斗时调用，town 据此刻推送 `ScenePlayerLeavePush`） |
| 61000/61001 | game↔town | `TownEnterSceneReq/Resp` | 进入场景编排（携带外观） |
| 61002/61003 | game↔town | `TownLeaveSceneReq/Resp` | 离开场景 |
| 61004 | game→town | `TownUpdateAppearanceReq` | 外观变化单向通知 |

### 关键类型（`game_types.proto`，PB.Types）

- `TownVec3`：定点坐标（字段值 / 1000 = 像素），服务端整数运算避免浮点漂移。
- `TownVel`：速度（像素/秒，浮点），仅用于远端斜向外推，不参与权威校验。
- `TownMovement`：`pos`（定点）+ `facing`（0=左/1=右）+ `moving` + `vel` + `state`（motion 名）。
- `TownAppearance`：`class_id` + `name` + `level` + `fashions[]`（`position`/`config_id`）+ `pet_id` + `base_skins[]`（`position`/`res_fashion_id`）+ `armament_id`。
- `TownPlayerInfo`：`player_id` + `appearance` + `movement`（进入快照用）。

### 流程

1. **进入**：客户端 `EnterSceneReq`（仅目标 + 出生运动状态）→ game 用选中角色构造 `TownAppearance`，转发 `TownEnterSceneReq` 给 town → town 返回 `TownEnterSceneResp`（场景内玩家快照 `TownPlayerInfo[]`）→ game 绑定 town 后回 `EnterSceneResp`。
2. **移动**：客户端本地预测并发送 `TownMoveReport`（`client_seq` + `client_time_ms` + `movement` + `ack_correction_seq`）；town 用「位移预算（token bucket）」校验位移：预算按服务端接收时间以 `max_speed × tolerance` 恢复、上限为 `max_speed × tolerance × burst_seconds`，位移（欧氏距离）超出预算则沿方向 clamp 并只回 `TownPositionCorrectionPush`；校正回包携带该上报的 `client_seq`，客户端确认（吸附）后经后续 `TownMoveReport.ack_correction_seq` 回传，town 在收到确认前丢弃在途上报（既不校验也不推进预算时间）。
3. **广播**：town 按固定 tick（默认 10 Hz）把「发生变化」的玩家批量 `ScenePlayerStatesPush`（条目含 `server_time_ms` 供插值），排除接收者自身。
4. **外观变化**：game 服换装/切宠物后发 `TownUpdateAppearanceReq` → town 广播 `ScenePlayerAppearancePush`。
5. **AOI**：可配置半径；开启时进入/离开半径触发 enter/leave 推送，广播仅达半径内玩家；默认 `aoi_radius=0`（整个场景可见）。
6. **离开**：客户端进入本地副本/决斗时发 `LeaveSceneReq`（1308）→ game 转发 `TownLeaveSceneReq`（61002）→ town 把玩家移出场景并向同场景广播 `ScenePlayerLeavePush`；返回城镇时重新 `EnterSceneReq`。

### 客户端模型（`Source/ui/town/TownSync` + `TownScreen`）

- **本地预测上报**：本地玩家发送 `TownMoveReport`（`client_seq` 递增 + `client_time_ms` + `movement` + `ack_correction_seq`），坐标按定点 `round(px × 1000)` 编码；移动中最多 10 Hz 周期上报，起停/朝向/状态变化即时上报，静止且无变化时不上报；`ack_correction_seq` 回填最近一次已应用校正的序号（新场景进入时重置为 0）。
- **权威校正**：收到 `TownPositionCorrectionPush` 且 `seq ≥ 最近已应用校正序号` 时，把本地玩家吸附到权威位置（直接写 `Transform`，表现层大位移走既有 teleport snap），否则丢弃过期校正；吸附后把 `ack_correction_seq` 置为该序号并强制下一帧立即上报，使服务端尽快收到确认。
- **远端插值**：`TownSync` 为每个远端玩家维护快照缓冲（以 `server_time_ms` 为键，上限 32）；用平滑（EMA）的单调时钟偏移估计「服务端现在 = 本地单调时钟 + 偏移」；渲染时刻取「估计服务端现在 − 插值延迟」，在相邻快照间线性插值；缓冲不足时沿最近 `vel` 外推（≤ 1 tick），快照间隔超过阈值直接吸附。插值结果每逻辑帧喂入既有木偶更新路径。
- **插值常量**：`kInterpDelayMs = 2.5 × tick`（默认 250 ms）、`kExtrapolationMs = 1 tick`（100 ms）、`kSnapGapMs = 3 × tick`、`kMaxSnapshots = 32`、`kClockSmoothing = 0.1`。
- **外观/宠物**：远端玩家按 `TownAppearance`（`class_id → roleId`、`base_skins → baseFashion`、`fashions → equipFashion`、`armament_id → 武器挂件 spine`、`pet_id → 宠物`）在进入与 `ScenePlayerAppearancePush` 时应用；本地玩家宠物来自 `PetLocalState.activeId`（响应 `PetFollowChanged`）。表现层按实体维护宠物（`AvatarPresenter` 实体 → `PetFollower` 映射），离开时清理。

### 配置（`game/town/town.toml`，`[sync]`）

| 键 | 默认 | 说明 |
|---|---|---|
| `max_speed` | `600.0` | 最大移动速度（像素/秒） |
| `tolerance` | `1.5` | 位移校验容差（相对 max_speed 的倍数） |
| `burst_seconds` | `0.5` | 位移预算突发时长（秒）；预算上限 = `max_speed × tolerance × burst_seconds` |
| `tick_ms` | `100` | 广播 tick 间隔（毫秒，默认 10 Hz） |
| `aoi_radius` | `0.0` | AOI 半径（像素），0 表示关闭（整场景可见） |

## Battle 战斗服约定

- 单线程 yasio 事件循环；网络事件、RPC 超时和战斗 tick 在同一线程，框架路径不加锁。
- 不用 C++ coroutine / concurrencpp；异步结果统一回调。
- 周期逻辑用 yasio timer/scheduler，不在 `run()` 里写 while/sleep 主循环。
- 日志用 spdlog（控制台 + `logs/battle_server.log` 滚动），文本英文。
- 框架层 `src/framework/`：`BackendCodec`（帧编解码）、`GatewayClient`（连接注册重连）、`RpcManager`（pending/超时）、`BackendSession`（session 与 delegate）。业务通过 `BackendDelegate` / `SessionDelegate` 接入。
- 流程：game →(RPC)→ battle `BattleCreateReq/Resp`；客户端 `BattleInputPush` 等消息经 gateway 路由到绑定 battle 实例，细节见下「战斗同步模型」。

## 战斗同步模型（battle）

联网战斗采用「服务器权威 lockstep + 客户端回滚」，取代旧的 30Hz 全量 `world_dump` 快照模型：

- battle 服以 30 Hz 墙钟固定 tick 推进共享的 mugen `sim_legacy::World`（`frame_ms`≈33），收集各槽位输入、确认后广播每帧输入（`BattleFramesPush`）。
- 客户端本地预测推进；收到服务器确认后按帧对账，确认与预测不一致时回滚到最早不一致帧并重推（`sim_legacy/rollback/RollbackSession`，见「战斗核心」）。
- **自适应输入领先量**：客户端在「估计服务器帧 + 输入领先量」处预测并提交输入。估计服务器帧由 `BattleFramesPush` 到达时刻校时得出，天然落后真实帧约一个单向时延 d，输入再花 d 才到服务器，所以输入到达时约领先服务器「领先量 − 2d」帧，领先量至少要覆盖一个 RTT 加抖动，否则输入会在目标帧被 tick 之后才到达（迟到）。固定 4 帧领先量只能容忍约 66 ms 单向时延，因此领先量改为闭环自适应，由 `BattleStartPush.input_delay_frames`（当前 4，`kInputDelayFrames`）给出初值。
  - **服务器反馈**（`BattleFramesPush`，按接收方槽位个性化）：`input_slack_min/frame/samples` = 自上次推送以来该槽位首次到达的输入帧里最小的「到达富余帧数」（输入帧号 − 到达时已 tick 帧 − 1，负数为迟到）及对应帧号；`late_inputs` = 该槽位累计迟到帧数；`echo_client_time_ms` = 回显该槽位最近一条 `BattleInputPush.client_time_ms`（只回显一次），客户端用它测 RTT（含至多一个服务器 tick 的持有时间，略偏大）。`LockstepAuthority` 用每槽位已收帧号集合（回溯 `kReceivedWindowFrames`=64 帧）区分冗余重发与首次到达。
  - **客户端控制律**（`NetBattleSync::onServerFeedback`，纯整数）：最小富余 < `m_slackTargetFrames`(2) 时立即按缺口增大（单次至多 `m_maxLeadStep`=8），上限 `min(m_maxLeadFrames=30, 回滚深度−16, kMaxInputLead−8)`；只有一个观察窗口（`m_shrinkWindowFrames`=30 帧）内最小富余始终 ≥ 目标 + `m_shrinkMarginFrames`(2) 才缩小，每窗口至少 1 帧、富余大时约缩富余的三分之一，且不低于 `ceil((srtt + 2·rttvar)/frame_ms)` 与 `m_minLeadFrames`(2)。领先量变化后，帧号早于生效帧的旧样本被忽略，避免途中数据造成连续超调。
  - **不跳帧、不改写**：领先量只改变 `targetFrame`。增大时本地预测多追几帧（帧号连续）；缩小时 `targetFrame` 低于当前帧，`NetBattleMode::onUpdate` 自然等待。每个帧号只生成并发送一次输入（`RollbackSession::canAdvance` 在消费 `ControlManagerCore` 命令之前先判断预测窗口，被停顿的帧不会吞掉一次性命令）；冗余重发只会重发同一帧的同一内容。
  - **迟到输入顺延而非丢弃**：迟到的非空输入（迟到 < `kMaxLateCarryFrames`=12 帧）并入下一个未 tick 帧、排在该帧自身命令之前，保持命令先后顺序；该帧确认输入广播后，发送方客户端把本地预测回滚为服务器结果（一次 `localMispredictions`），攻击 / `CTR_IDLE` 只是晚几帧生效而不会彻底丢失。迟到更久（≥ `kMaxLateCarryFrames`）的：攻击等边缘命令丢弃（避免卡顿后很久才触发过期攻击），但最后一条移动状态命令（`CTR_RUN`/`CTR_IDLE`，电平语义，只在方向变化时发出一次）仍顺延，否则角色会永久停在旧状态。`net_duel_sync_test` 在 20/60/120/200 ms 单向时延 + 抖动、以及 20→150 ms 突变与 200→20 ms 恢复下验证：收敛后服务器不再记录任何迟到输入、本地输入不被改写、同帧号输入内容唯一；领先量收敛到约「RTT（含抖动）帧数 + 2~3 帧」。
- **本地英雄「被拉回 / 重影」的根因与对策**（`net_duel_sync_test` 的 `runMovementSuite`：键盘式 / 摇杆式持续移动，100~400 ms 单向时延 + 抖动、100→300 ms 突变与 300→100 ms 恢复）：
  1. **表现层插值进度与逻辑 tick 不同相（稳态重影的主因，无需任何回滚也出现）**：联网时逻辑 tick 由时钟估计驱动，旧实现的渲染 alpha 是独立回绕的墙钟锯齿，与「previous/current 随 tick 滚动」不同相，位置在一个逻辑帧内来回跳约 27 单位。现在 `TickAlpha`（`render/battle/PoseTrack.h`）从最近一次逻辑 tick 起算 alpha（tick 迟到停在 1、不回绕）。
  2. **开局校准期输入必然迟到**：初始领先量（4 帧）远小于 RTT，起步的方向命令在服务器目标帧之后才到，被顺延 / 丢弃后客户端回滚——起步即被拉回。现在首个 RTT 样本直接把领先量抬到覆盖 RTT（`ceil(1.25·rtt/frame_ms)` + 目标富余）；`NetBattleSync::inputReady` 在首个 RTT 样本到达前、以及领先量增大后的追帧期间（帧号 < 估计服务器帧 + 领先量 − 容差）不采样本地输入（按键状态保留，放行后的第一帧照常发出，`NetBattleMode` 与测试客户端一致）。领先量变化后的「生效帧」同样跳过追帧期间的帧，避免连续超调（领先量峰值 28→20 @200 ms）。
  3. **迟到过久的移动命令被丢弃**：见上，丢掉 `CTR_RUN`/`CTR_IDLE` 会让服务器权威状态与本地永久不一致（实测一次回滚拉回 220~770 单位）；现保留最后一条移动状态命令。
  4. **回滚后的硬拉回**（本地玩家档；对端角色的长时间常数档见下一条）：`PoseTrack` 在回滚前后记录角色位置差，`NetBattleMode::applyRollbackCorrections` 把差交给 `WorldPresenter::applyCorrection`：轨迹整体平移使显示位置连续，偏移以 100 ms 时间常数指数衰减；超过 400 单位或跳帧 > 8 / 帧号回退（重同步）才直接吸附。只读模拟位置，不改写模拟状态，确定性不受影响。
  实测（修复前 → 后，本地英雄）：稳态（收敛后）显示层反向抖动事件 212~801 次 → 0；本地错误预测 / 回滚（全程含校准期）2~15 → 0（稳定链路）；服务器对本槽位丢弃的输入 1~7 → 0；100→300 ms 突变的瞬间仍会有 2~11 次回滚（不可避免，之后 0），显示层按上面 4 平滑消化。
- **高延迟下「对端被拉回」的根因与对策**（RTT > 300 ms 时对端移动的英雄在其停下 / 转向时被明显拉回）：远端输入缺失时预测为空输入，「保持当前动作」使跑动状态持续；对端停下的 `CTR_IDLE` 要等确认帧到达才知道，本地回滚会把对端英雄从「预测多跑出去的位置」拉回，错误预测窗口 ≈ 本地领先确认帧的帧数 + 单向时延 ≈ 1.5×RTT（RTT 445 ms 实测回退 175~320 单位，超过 400 单位还会被旧平滑直接吸附）。两处对策：
  1. **对端角色用更长的纠正平滑**（只在表现层，不改模拟 / 哈希）：`PoseTrack` 有 `CorrectionProfile::Local / Remote` 两档，`AvatarPresenter::present` 对镜头跟随实体（本地玩家）用 Local（时间常数 `kCorrectionTauSec`=0.1 s，吸附阈值 `kMaxCorrection`=400，与此前完全一致），其余角色用 Remote：衰减时间常数随当前偏移长度从 `kRemoteCorrectionTauMinSec`=0.1 s 线性增至偏移 ≥ `kRemoteTauFullOffset`=450 时的 `kRemoteCorrectionTauMaxSec`=0.3 s（偏移衰减变小时时间常数同步变短，尾段不拖长），吸附阈值放大到 `kRemoteMaxCorrection`=900，250~500 单位的纠正滑行而不瞬移；偏移始终衰减到 < `kOffsetEpsilon` 后严格归零（对端静止时不留漂移）。跳帧 > 8 / 帧号回退（重同步）/ 单帧模拟位置跳变 > 500（瞬移）仍直接吸附并清偏移。
  2. **自适应本地输入延迟 D**（`NetBattleSync`，默认 `LocalDelayMode::Auto`）：采样于第 t 帧的本地输入被安排到第 t + D 帧生效，并立即（提前 D 帧）随 `BattleInputPush` 发给服务器；本地预测的第 t 帧用 D 帧之前安排好的输入，所以本地英雄只是晚 D 帧响应按键（输入延迟 D×33 ms），不产生任何本地错误预测。与此同时「输入领先量 + D」保持不变（D 每增 1 帧，领先量减 1 帧并清空富余样本的旧有效起点），服务器看到的输入时刻、迟到余量都不变，而客户端少领先服务器 D 帧——本地对远端预测的窗口缩短 D 帧，对端被回滚拉回的距离随之变小。`shrinkFloor` 的 RTT 下限也扣除 D。
     - **调度与过渡（每个帧号恰好一份输入、发出后不再改写）**：`m_scheduledThrough` 是已安排输入的最大帧号。`NetBattleSync::submitLocalInput(frame, input)` 把采样安排到 `frame + D`：D 增大时中间空出的帧补空输入（缓冲）；D 减小时 `inputReady` 对「生效帧已被占用」的那一帧返回 false，`NetBattleMode` 因此不调用 `ControlManagerCore::advance`（按键状态保留到下一帧采样，不丢不重，与校准期 / 追帧期的既有门控一致）。冗余重发环容量为 `m_redundantInputFrames + D`，重发内容与首次发出逐字节一致；`resync` 把仍在快照帧之后的已发输入放回会话并保持 `m_scheduledThrough`；反馈样本的生效帧按输入帧号（= 推进帧 + D）计。
     - **控制律**（`updateLocalDelay`，每次反馈调用）：平滑 RTT ≤ `m_localDelayRttThresholdMs`(250) 时 D = 0，否则目标 = `ceil((srtt − 250) / 2 / frame_ms)` 封顶 `m_localDelayMaxFrames`(5)；升得快（每 `m_localDelayRaiseIntervalMs`=100 ms 升 1 帧）、降得慢（RTT 加上 `m_localDelayLowerMarginMs`=30 ms 滞回后算出的目标仍低于当前 D 并持续 `m_localDelayLowerHoldMs`=2000 ms 才降 1 帧），始终一次变 1 帧。调试可切 `Auto / Forced(m_localDelayForcedFrames，上限 m_localDelayDebugMaxFrames=10) / Off`。无协议改动。
  3. **实测**（`net_duel_sync_test` 的 `runRemotePullbackSuite`：槽位 0 反复「右跑 0.9 s、停 1.5 s、左跑 0.9 s、停 1.5 s」，槽位 1 的客户端用与 `WorldPresenter` 同一套 `PoseTrack` 显示槽位 0；单向时延 d、抖动 0.2d；回退 = 权威停下后 1.1 s 内显示位置相对已达最远点的回退；back100 = 100 ms 内最大回退距离，越小越像滑行、越大越像瞬移；跳变 = 单个 60 Hz 渲染帧显示位移 > 40 单位的次数）：

     | 单向 / RTT | 方案 | D | 回退 max / avg | back100 max | 跳变 |
     |---|---|---|---|---|---|
     | 150 ms / 344 | 旧（无 D、本地平滑） | 0 | 247.6 / 122.3 | 153.2 | 2 |
     | | 仅远端平滑 | 0 | 247.5 / 122.2 | 99.0 | 0 |
     | | 仅 D | 2 | 210.9 / 103.9 | 130.0 | 2 |
     | | D + 远端平滑 | 2 | 210.9 / 103.9 | 89.4 | 0 |
     | 200 ms / 445 | 旧 | 0 | 320.9 / 175.8 | 199.5 | 43 |
     | | 仅远端平滑 | 0 | 320.6 / 175.6 | 115.2 | 0 |
     | | 仅 D | 4 | 247.6 / 135.9 | 153.2 | 5 |
     | | D + 远端平滑 | 4 | 247.4 / 135.7 | 99.0 | 0 |
     | 250 ms / 567 | 旧 | 0 | 394.3 / 206.6 | 394.3 | 61 |
     | | 仅远端平滑 | 0 | 393.4 / 205.4 | 128.0 | 0 |
     | | 仅 D | 5 | 293.3 / 154.2 | 178.7 | 20 |
     | | D + 远端平滑 | 5 | 292.9 / 154.0 | 107.6 | 0 |

     RTT ≤ 250（单向 100 ms）D 恒为 0，行为与此前完全一致。平滑负责把瞬移变成滑行（back100 −35%~−70%、跳变归零），D 负责缩短回退距离（avg −15%~−25%）；本地英雄在 Auto 下仍满足「稳态 0 次本地错误预测、不被拉回」（movement 套件）。
- 预测规则：远端槽位（及本地槽位无本地输入的帧）预测空输入。`ControlManagerCore` 只在方向 / 按键变化时发令（`CTR_RUN` 仅在方向变化时发出，持续按住不重复），空输入在模拟里等价于「保持当前动作」，因此持续移动几乎不会错预测；只有边缘事件（对端点击攻击、改变方向）才错预测并触发回滚，每次回滚重推约「输入领先量 + 单向时延」帧（领先量自适应，20/60 ms 实测 5–8 帧，连点普攻约 2 次回滚/秒）。不要改成「重复最近一次非空输入」，那会把单次攻击事件重复触发。`RollbackStats` 把错误预测拆成 `localMispredictions`（本地输入被服务器改写，网络正常时应为 0）与 `remoteMispredictions`（对端边缘输入，预期内），`RollbackSession` 会丢弃已落出回滚窗口的输入历史并忽略窗口外的迟到确认。
- 联网调试面板（`NetBattleMode::renderDebugPanel`）最顶部是醒目的 `延迟(RTT): XX ms  抖动: XX ms` 与输入领先量行（`BattleDebugPanel::renderNetLatency`，<100 ms 绿 / <200 ms 黄 / 其后红），`Battle Debug` 窗口在联网模式下同样显示该行（`IBattleMode::netInfo`）；面板还带「模拟延迟」调试滑条（上行 / 下行额外延迟与抖动，默认 0，只在 `NetBattleMode` 内延迟收发战斗消息，同方向保持顺序，用于本机复现高延迟，面板 RTT 会包含它），并统计回滚改写本地 / 对端英雄位置的次数与距离，另有「本地输入延迟」模式（自动 / 固定 / 关闭）与固定帧数滑条，面板与 `Battle Debug` 的网络行都显示当前 D（帧 / ms）与模式。其余显示当前输入领先量（帧 / ms）、测得 RTT 与抖动、服务器累计迟到输入数与最近一次富余帧数，以及最近一秒的回滚 / 重推 / 追帧 / 停顿计数，以及 sim（本地预测推进）、net（确认输入 + 回滚重推 + 对账）、present（表现层）三段的平均 / 最大耗时，另记整场最坏值；一秒窗口内最长渲染帧超过 60 ms 时输出一条限频的英文卡顿日志，无逐帧日志。
- 每 30 帧双方各自计算帧哈希对账（`BattleFrameHash`）；不一致时客户端发 `BattleResyncReq`，battle 下发 `BattleSnapshotPush`（世界快照 + 快照后确认帧）复位。
- 传输暂走 TCP，经 gateway 按 msg_id 范围路由到 service_id 1 的 battle 实例。

客户端联网决斗由 `AxmolFighter-Client/Source/ui/battle/NetBattleMode` 承载：进入后发 `BattleReadyReq`，收到 `BattleStartPush` 解码 `WorldSetup` 并交给 `sim_legacy/rollback/RollbackSession` 引导世界，按「估计服务器帧 + 自适应输入领先量」本地预测；`BattleInputPush` 回带冗余输入、客户端哈希与发送时间戳，`BattleFramesPush` 确认输入、携带输入到达反馈并做哈希对账，不一致发 `BattleResyncReq`、收到 `BattleSnapshotPush` 复位。时钟同步与哈希/冗余/重同步决策集中在无引擎依赖的 `mugen::sim_legacy::net::NetBattleSync`，由 `TestsHeadless/tests/NetBattleSyncTest.cpp` 做无头回环测试。`RollbackSession::tick` 在服务器确认帧领先当前帧（客户端启动阻塞或卡顿后追帧）时仍继续推进，不做无符号减法；`AxmolFighter-Server/battle/tests/net_duel_sync_test.cpp` 用真实 `BattleRoom` + 两个 `NetBattleSync` 客户端、虚拟墙钟、时延与时钟域偏移做端到端回归。表现层外观：镜头跟随实体（本地玩家）使用本机会话时装；对端玩家使用 game 服在创建战斗时下发的外观（`BattlePlayerSpec.appearance` → `BattlePlayerInfo.appearance`，即 `TownAppearance`），`NetBattleMode` 在引导世界后用 `WorldPresenter::setEntityAppearance` / `setEntityPet` 覆盖对端槽位实体。`TownAppearance → FashionAppearance` 的转换集中在 `ui/progress/SessionFashionAppearance` 的 `fashionAppearanceFromTown`，由 `TownSync` 与 `NetBattleMode` 共用。外观只用于表现，不进入 `WorldSetup` / 模拟 / 哈希。

### 消息一览

| msg_id | 方向 | 消息 | 说明 |
|---|---:|---|---|
| 20010 | C→battle | `BattleReadyReq` | 客户端进入战斗界面后通知准备就绪 |
| 20011 | battle→C | `BattleStartPush` | 战斗开始参数（mugen `WorldSetup` + 帧参数 + 玩家列表含外观）；`resume=true` 表示战斗已在进行，紧随一条快照 |
| 20012 | C→battle | `BattleInputPush` | 本地预测输入帧（mugen `PlayerInput`）+ 客户端帧哈希 |
| 20013 | battle→C | `BattleFramesPush` | 广播已确认帧输入（mugen `FrameInput`）+ 服务器帧哈希 |
| 20014 | C→battle | `BattleResyncReq` | 按帧号请求快照重同步 |
| 20015 | battle→C | `BattleSnapshotPush` | 世界快照（帧号 + `server_time_ms`）+ 快照后确认帧；重同步与断线重连共用 |
| 20016 | battle→C | `BattleEndPush` | 战斗结束结果（胜者阵营/原因/玩家结果） |
| 20017 | C→battle | `BattleLeaveReq` | 投降（仅玩家显式点击投降发送；关闭客户端 / 断线 / 切屏不发） |
| 1411 | game→C | `DuelStartPush` | 决斗成立（`battle_id`/`room_id`/对手信息/`class_ids`：全部参战者职业 id，按槽位升序，供客户端预加载技能特效），客户端切换到联网战斗界面并发 `BattleReadyReq` |
| 60000/60001 | game↔battle | `BattleCreateReq/Resp` | 创建战斗（房间/种子/pvp/玩家描述） |
| 60002 | battle→game | `BattleResultReq` | 战斗结果上报（单向推送，game 据此清理绑定与玩家战斗记录） |
| 60003/60004 | game↔battle | `BattleRejoinReq/Resp` | 断线重连：game 把玩家的新 session 改绑到进行中战斗的槽位（RPC；Resp.code 0 成功 / 1 战斗不存在 / 2 已结束 / 3 玩家不在其中） |
| 1205 | game→C | `SelectCharacterResp.rejoin`（`BattleRejoinInfo{battle_id, room_id, class_ids}`） | 账号有进行中的战斗时下发，客户端不进城镇而直接进入战斗界面 |

关键类型在 `game_types.proto`（PB.Types）：`BattlePlayerSpec`（`session_id`/`player_id`/`character_id`/`name`/`class_id`/`slot`/`camp`/`level`/`appearance`；`appearance` 由 game 服用 `town_appearance_from_character` 从角色构造，与城镇外观同一份）、`BattlePlayerResult`（`player_id`/`slot`/`camp`/`win`）。

### 流程

1. **决斗接受**：被邀请方 `DuelRespondReq(accept=1)` → game 生成 `battle_id`/`random_seed`，按双方选中角色构造 `BattlePlayerSpec`（挑战者槽位 0/阵营 2=`EntityCamp::Our`，目标槽位 1/阵营 8=`EntityCamp::Enemy`；双方必须分属互相敌对的阵营位，中立阵营的特效无法命中，世界引导会拒绝）。
2. **创建**：game →(RPC)→ battle `BattleCreateReq`（房间 30002、pvp=true）→ `BattleCreateResp(battle_instance_id)`。
3. **绑定**：game 请求 gateway 将双方 session 绑定到 battle 实例（service_id 1）。
4. **开始**：game 向双方下发 `DuelStartPush`（battle_id + 房间 id + 对手信息），客户端切换到联网战斗界面。
5. **准备**：客户端发 `BattleReadyReq`；全部就绪后 battle 向各就绪槽位发 `BattleStartPush`（WorldSetup/帧参数/玩家列表+外观）。
6. **帧循环**：客户端 `BattleInputPush` 预测输入 ↔ battle `BattleFramesPush` 确认帧，按帧哈希对账，不一致走 `BattleResyncReq`/`BattleSnapshotPush`。
7. **结束**：battle 下发 `BattleEndPush`，并单向通知 game `BattleResultReq`；game 解绑仍在线的 battle 绑定、清理会话与玩家战斗记录，客户端回城镇重新 `EnterSceneReq`。

### 战斗服房间状态机（battle）

`BattleRoom` 由 `BattleCreateReq` 构造：读房间/关卡配置解析 `mapKey` 与 stage/copy（与客户端 `LocalBattleMode` 同一路径），按 `BattlePlayerSpec` 构造 `WorldSetup`（`class_id → type_conversions::toRoleConfigId` 映射 roleId、槽位/阵营/等级、`isAi=false`），再交给 `LockstepAuthority` 引导权威世界。房间状态：

| 状态 | 行为 |
|---|---|
| `WaitingReady` | 等待各槽位 `BattleReadyReq`；全部就绪即进入 `Running`；超时（20s）时若无人就绪则 `Abort`，否则按已有就绪者照常开始（缺席槽位输入按空处理，其客户端稍后发 `BattleReadyReq` 时补发开始参数 + 快照） |
| `Running` | 以 30 Hz 墙钟累加器推进目标帧（`target = elapsed / 33ms`，落后时每 tick 最多追赶 5 帧）；每个 tick 把新确认帧与新增服务器哈希打包成一次 `BattleFramesPush` 发给每个已同步且在线的会话（断线或尚未收到开始参数的槽位不发）；保留约 300 帧的已确认帧历史环供重同步 |
| `Ended` | 权威世界 `outcome()` 产出结果或主动终结（投降/断线/中止）后广播 `BattleEndPush` 并单向上报 game `BattleResultReq`，宽限 3s 后销毁 |

关键机制：

- **哈希对账**：客户端在 `BattleInputPush` 里回带 `client_hashes`，battle 与 `LockstepAuthority::hashAt` 比对，不一致仅记 warn（客户端自行发 `BattleResyncReq`）。
- **重同步**：`BattleResyncReq` → `BattleSnapshotPush{frame=当前帧, world=serializeWorld, frames_after=空}`（快照即当前状态，之后尚无确认帧）。
- **断线**：gateway `SessionOfflinePush` 只标记槽位离线，**不结束战斗**；`BattleLeaveReq` 才判负 `Surrender`。详见下「断线重连」。

### 断线重连

**为什么以前关闭客户端会让对手直接获胜**：关闭应用时 `AppContext::destroy → ScreenManager 析构 → GameScreen::onExit → NetBattleMode::onExit` 会调用 `requestLeave()`，把「离开界面」当成投降发出 `BattleLeaveReq`，battle 立即判 `Surrender`（而不是 15s 的断线宽限）。现在 `onExit` 不再发送，只有玩家点击投降按钮才发。

**语义**

- 关闭客户端 / 断线 / 切屏**都不是投降**。battle 服收到 `SessionOfflinePush` 后保留席位：战斗照常推进；该槽位已排队输入被清空并在下一帧注入一条 `CTR_IDLE`（等价于松开所有按键，`LockstepAuthority::releaseSlot`），之后缺失输入按空处理——角色原地待机而不会保持断线前的跑动。
- 重连宽限 `reconnect_grace_seconds`（`battle.toml` 的 `[server]`，默认 60）。宽限耗尽仍未回来才判负 `Disconnect`，对手获胜。重连成功清零计时。
- 对手不收专门通知；断线者角色停下即可见。战斗在断线期间结束（KO/超时/对手投降/宽限耗尽）时，game 已按 `BattleResultReq` 清掉玩家记录，再次登录正常进城镇。

**game 服**：`GameShared.player_battles`（`player_id → ActivePlayerBattle{battle_id, battle_instance_id, room_id, character_id, class_ids}`）独立于 session：`start_duel_battle` 成功后写入；`BattleResultReq` / battle 实例下线时清除；session 断开（`clear_session_runtime_state`）**不清**。`handle_select_character` 里 `resolve_select_character`：账号有进行中的战斗则强制选回参战角色并执行重连，否则按请求选角：

1. gateway `BindServiceReq` 把新 session 绑到该 battle 实例；
2. RPC `BattleRejoinReq{battle_id, player_id, session_id}`（60003）通知 battle 改绑槽位；失败则回滚绑定。code≠0（战斗不存在 / 已结束 / 玩家不在其中）视为记录过期，丢弃后按普通选角进城镇；gateway/battle 暂不可用则本次进城镇、记录保留；
3. `bind_battle_session` 记录新 session，`SelectCharacterResp.rejoin = BattleRejoinInfo{battle_id, room_id, class_ids}`（`class_ids` 取自开局时存入 `ActivePlayerBattle` 的参战者职业）。

**battle 服**：`BattleRoomManager::rejoin` → `BattleRoom::rejoin(player_id, new_session)` 改绑槽位、清断线计时、标记 `startSent=false`，并更新 session→房间路由（旧 session 之后迟到的离线通知不再影响该槽位）。此刻**不推送**：客户端还停在选角界面，没有注册监听，推送会丢。客户端进入战斗界面发 `BattleReadyReq` 后，房间在 `Running` 状态下对 `startSent=false` 的槽位补发 `BattleStartPush{resume=true}`（同一份 setup、`local_slot`、玩家列表与外观），紧接着发 `BattleSnapshotPush{frame=当前帧, world, server_time_ms}`。同一机制也让开局超时后才入座的迟到槽位同步进当前帧。未同步的槽位不接收 `BattleFramesPush`。

**客户端**：`CharacterLobbyScreen` 收到 `rejoin` 直接 `switchScreen<GameScreen>(NetBattleParams{battle_id, room_id, roleIds})`（`roleIds` 由 `class_ids` 经 `toRoleConfigId` 转换；`DuelStartPush` 同理）。`GameScreen::onPrepareLoad` 在联网模式下对每个 `roleIds` 调 `gameres::addRoleEffects`，与本地副本一样预加载技能特效 Spine。`NetBattleMode` 收到 `resume=true` 的开始参数后只引导帧 0 的世界并置 `m_awaitSnapshot`：此期间不推进、不对账、不开 HUD；快照到达后 `NetBattleSync::resync` 复位到当前帧，并用快照的 `server_time_ms` 调 `resetClock` 直接对齐时钟（估计服务器帧立即落在快照帧附近，目标帧 = 服务器帧 + 输入领先量），之后沿用既有预测/对账路径，绝不从帧 0 重新模拟。

### 结束原因（reason）

`BattleEndPush.reason` / `BattleResultReq.reason` 为 `int32`，取值如下（前两项与 `mugen::sim_legacy::PvpRoundEndReason` 数值对齐）：

| 值 | 枚举 | 含义 |
|---:|---|---|
| 0 | `Ko` | 一方阵营被清空 |
| 1 | `Timeout` | 决斗限时到达（按剩余生命比例判定） |
| 2 | `Surrender` | 客户端 `BattleLeaveReq` 投降 |
| 3 | `Disconnect` | 断线后 `reconnect_grace_seconds` 内未重连判负 |
| 4 | `Abort` | 无人就绪，创建即中止 |

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
- Spine 数据归属在创建时确定（`MgSkeletonData::isExclusive`），不从 `use_count` 推断；共享缓存 key 为骨架 + 规范化 atlas 列表 + scale，切换 View 后 `purgeUnused`：删掉仅被缓存持有的骨架，并对 atlas 页在 `TextureCache` 只剩自身引用时 `removeTextureForKey`（不调用全量 `removeUnusedTextures`）。
- 逻辑文件放 `mugen/avatar/` 根目录（禁止 include axmol/spine）；渲染文件放 `render/` 并整体 `#ifdef RUNTIME_IN_AXMOL`（battle CMake 自动排除）。
- 状态机经 `AvatarComponent::play` 驱动 `MotionPlayer`；渲染 `Avatar` 由 `AvatarPresenter` 跟随（动作变化时 setMotion + seek，漂移超过阈值时 seek 校正）。`MotionState` 是可序列化的播放标量，包含 `.motion` 路径、播放位置和速度。

## 资源加载器（Source/resource, 命名空间 gameres）

- 定位：异步预加载一批资源并驱动进度条。`View` 子类重写 `onPrepareLoad()` 声明要加载的资源；什么都不声明就不会出现加载界面，直接创建正式内容（见下面的“View 加载流程”）。
- `Resource`：资源描述基类，负责“加载什么”和持有加载结果；内置 `TextureResource` / `SpriteFramesResource` / `SpineResource` / `FguiPackageResource` / `AudioResource` / `ConfigResource` / `MapResource`，开发者可以继承它接入自定义类型。`ConfigResource` 在主线程解析全路径、工作线程反序列化；`MapResource` 只解析 `.layer` 的 JSON（`mugen::LayerRuntimeLoader::collectResources`，不建节点）再派生出 Spine/纹理/SpriteFrames/背景音乐子资源。`SpineResource` 按 ResSpine id 构造时，id 必须 `> 0` 才会走"按 id 查表"的路径（0 是"未配置"的常见哨兵值）。
- `ResourceLoaderRegistry`：按 `ResourceType` 注册加载函数（签名 `void(std::shared_ptr<T>, const LoadTaskPtr&)`）和进度权重；`ResourceLoader::add<T>(...)` 按“类型 + key”去重，只能在 `start()` 之前调用；`LoadTask::spawn<T>(...)` 可以从一个资源内部派生子资源（受同一并发上限调度，均分计入父资源进度，不计入总权重），用于组合型资源（`FguiPackageResource` 派生图集纹理、`MapResource` 派生地图引用的各类资源）。
- 进度：`Σ(weight_i * progress_i) / Σ(weight_i)`，权重只由注册表按类型配置（默认 FGUI 包 10、Map 10、Spine 3、Config 2、其余 1）；复杂类型可以调大权重避免进度卡在接近 100% 不动。有任务结束时才触发 `onProgress`；失败的任务也算结束，失败列表可以通过 `getFailedResources()` 轮询。
- 帧预算：主线程上的加载工作（启动任务、`onChildrenDone` 收尾、`runOnWorker` 的 `then`）统一排队，每帧在 `setFrameBudget`（默认 8ms）内执行，超出部分顺延到下一帧，每帧至少执行一项。
- 生命周期：加载函数被调用过的资源（含失败的）由 `ResourceLoader` 持有，**析构时立即**调用 `releaseHold()`（不延迟）。调用方负责把 `ResourceLoader` 持有到真正不再需要这些资源的那一刻——典型用法是 `View` 把它持有到自己销毁为止（见下面的“View 加载流程”），这样加载完成的资源在整个 View 存活期间都不会被 `SpineSkeletonCache::purgeUnused()` 或 `FGUIPackageManager::unload()` 过早回收。需要资源比某个 View 活得更久（常驻资源）时，用 `std::shared_ptr` 让多个持有者共用同一个 `ResourceLoader`，最后一个持有者销毁时才真正释放（`AppContext::globalLoader()` 和 `LaunchView` 就是这么共用的）。
- FGUI 包始终加载描述文件。`FguiPackageResource(path, preloadTextures=true, preloadSpine=true)` 控制是否预热 ATLAS 纹理（随后 `UIPackage::getItemAsset` 接管）和 SPINE 图集页贴图；骨架只在 `fairygui::UIConfig::useSkeletonCache` 为 true 时写入 `GCache`。`preloadSpine==false` 时不预热 Spine 页贴图也不预热骨架。同一 loader 内按路径去重，第一次 add 的开关生效。`FGUIPackageManager::unload` 引用计数归零时按包内 ATLAS/SPINE 清单从 `TextureCache` / `GCache` 精确释放，不调用全量 `removeUnusedTextures` / `clearSkeletonData`。SOUND 等其他项不处理。
- `gameres::addRoleSpine(loader, roleId)`：按角色 id 预热身体 Spine。路径和缩放只来自 `mugen::AvatarPaths::resolveRoleSpine`（`role.resSpineId` → `res_spine`），不再猜测城镇 `_city` 骨架，也不再给 `/hero/` 强制 0.25 缩放。
- `gameres::addRoleEffects(loader, roleId, aiDifficulty=0)`：预热该角色战斗技能会创建的特效 Spine。收集逻辑在 `mugen::sim_legacy::collectRoleEffectSpineIds`：职业角色用 `offlineKit`，怪物用 AI loadout，再沿 `nextSkill` / `action.effectIds` / `effect.nextEffectId` / `hitEffectIds` / 子特效 / 召唤角色展开；每个 `resSpineId` 以 `SpineResource(id)` 加入 loader，和运行时 `MgSkeletonAnimation::createFromCache(id)` 共用缓存 key。

### View 加载流程（Source/ui/core）

- `View::onPrepareLoad()`：在这里通过 `getResourceLoader()`（本 View 专属的加载器，持有到 View 销毁为止）或 `setResourceLoader(外部共同持有的加载器)`（比如 `AppContext::globalLoader()`；本 View 只负责在它还没 `start()` 时调用 `start()`，销毁时只释放自己的引用，不影响其他持有者）添加资源。没有加载器就不会显示加载界面。资源就绪后创建正式内容并调用 `onEnter()`；World / 输入等主线程组装放在 `onEnter`。
- 加载界面统一是 `ui/widgets/common/LoadingLayer`（Common 包里的 `LoadingLayer` 组件），进度显示不是直接跟着真实进度跳动，而是经过 `ProgressSmoother`（纯函数，不依赖引擎）平滑：落后时按指数缓动追赶（带最低速度，保证追得上）；追上后朝着一个比真实进度略高、但不超过 95% 的上限缓慢“爬行”，让玩家感觉一直在动；全部完成后再用较快的匀速冲到 100%。
- 预加载失败时调用 `View::onResourceLoadFailed(failed)`，默认只打印警告并返回 `true`，继续创建正式内容（运行时按老办法自行处理资源缺失，比如 Avatar 身体贴不上就是个空壳，不影响城镇/副本正常进入）。返回 `false` 才算致命。`LaunchView` 覆盖这个函数，让配置表这类核心资源加载失败一律致命。致命时弹出“资源加载失败”对话框，确认后结束程序；View 会一直停留在 Loading 状态，同一个 View 实例只会触发一次。
- `TownView` / `GameView` 在 `onPrepareLoad` 里用 `MapResource` 预热 `.layer` 引用的资源；`GameView` 还会按本地玩家和房间 `monsterIds` 调用 `addRoleEffects` 预热角色特效 Spine。`initTown` / 战斗 `init` 放到 `onEnter`。
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
