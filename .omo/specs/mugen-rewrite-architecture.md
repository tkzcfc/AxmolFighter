# mugen 重写：架构契约（Binding Architecture Contract）

> 本文件约束 `.omo/plans/mugen-rewrite.md`。**每个执行者开始任何 todo 之前，都要读 §0，以及 todo 中引用的章节。**
> - 旧代码、旧文档（包括 `Source/mugen/**/README.md`）与本文冲突时，以本文为准。
> - 本文与参照工程的战斗**语义**冲突时，以参照工程语义为准。此时在 notepad 记录差异，并请编排者更新本文。
> - 路径相对仓库根 `D:\work\AxmolFighter`。`Client` 指 `AxmolFighter-Client`，`Tools` 指 `AxmolFighter-Tools`，`Config` 指 `AxmolFighter-Config`。

---

## §0 全局规则（所有 todo 必须遵守）

### 0.1 先读 AGENTS
动手前先读：
- `AGENTS.md`
- `AxmolFighter-Client/AGENTS.md`
- `AxmolFighter-Client/Source/mugen/AGENTS.md`（todo 2 会按本文重写它）
- `AxmolFighter-Tools/AGENTS.md`
- `AxmolFighter-Config/AGENTS.md`

### 0.2 读参照工程的方式
1. 先读 `Reference/heiyue-结构.md`、`heiyue-战斗逻辑.md`、`heiyue-战斗配置.md`、`heiyue-AI与行为树.md` 中**与当前 todo 相关的章节**。
2. 再**只读**这些文档引用到的 `heiyue/src/...lua:行号` 附近的代码。
3. **禁止**整体扫描 `heiyue/src`；`heiyue/` 只读不写。
4. Lua 源文件是 UTF-8，PowerShell 用 `Get-Content -Encoding utf8` 读取。

### 0.3 移植原则
- 战斗语义与参照工程**逐行对齐**，不要"改进"玩法。
- 参照工程 Lua 里明显的 bug（例如真伤在 PVP 下报错）写进 notepad，按文档建议处理。

### 0.4 代码规则
- **注释约束**：`AxmolFighter-Client/Source/**` 和新写的转换器 C++ 源码中，代码注释禁止出现参照产品名（中文名、拼音、英文名，包括 `heiyue`），也禁止出现盘符路径或计划文档路径。注释只描述代码含义。Import 阶段的 Lua 脚本本来就需要参照源路径参数，不受此限制。
- 注释可以写中文；**日志、错误、断言文本一律英文**。
- 客户端使用 C++20。类的私有成员使用 `m_` 前缀。纯数据 struct（组件、配置行、状态）的公开字段不加前缀。
- **不写防御性判空**。只有 `ECSManager::tryGet<T>()` 和 `Config::find<T>()` 的返回值可能为空。
- **不加兼容层或 shim**，接口可以直接改。项目尚未发布。
- `Source/mugen/core/` 与 `Source/mugen/sim/` 的限制：
  - 禁止 include axmol、spine、imgui、rapidjson 的头文件；
  - 禁止使用 `float` 和 `double`（注释和 `toFloatForRender()` 这类明确给渲染用的转换函数除外）；
  - 禁止 `rand()`、系统时间、按指针地址排序；
  - 会被序列化、或会影响逻辑遍历顺序的状态里，禁止使用 `std::unordered_map` 和 `std::unordered_set`；
  - 禁止 `std::function`；回调统一用函数指针表或 `enum + switch`。
- 运行时依赖 axmol 的代码只放在 `Source/mugen/render/**`（整体包在 `#ifdef RUNTIME_IN_AXMOL` 内）和 `Source/ui/**`。
- 新增源文件后，客户端必须重新 configure：在 `AxmolFighter-Client` 下执行 `axmol build -p win32 -c`（即 `gen_project.bat`）。
- 提交前对改动过的 C++ 文件跑一遍 `AxmolFighter-Client/format_code.ps1`。

### 0.5 本计划不碰的部分
- 不修改 `AxmolFighter-Server`、`AxmolFighter-Editor`、`AxmolFighter-UI`。
- 战斗服在本计划期间**允许编译失败**，下一阶段重写。

### 0.6 Git 约定
- 只在子仓库 `AxmolFighter-Client`、`AxmolFighter-Client/Content`（存放 config.bin / avatar.bin）、`AxmolFighter-Tools`、`AxmolFighter-Config` 的分支 `mugen-rewrite` 上提交。
- 仓库由子模块组成，**不使用 git worktree**，直接在当前检出上工作。
- 每个 todo 完成并验证后提交一次，按"影响到的子仓库"分别提交。提交信息格式为 `type(scope): summary`，英文。
- **不 push，不改根仓库的子模块指针**，不使用 `--no-verify`。

---

## §1 目录与命名空间

```
AxmolFighter-Client/Source/mugen/
  core/                     命名空间 mugen；不依赖引擎
    math/                   Fixed、FixedVec2/3、FixedMath、Random、DamageBox（整数 AABB，保留）
    reflect/                MG_REFLECT 宏、类型特征、visitor 协议
    serialize/              ByteBuffer（大端，保留）、BinaryArchive（反射驱动）、Hash
    ecs/                    ECSManager（演进）、实体句柄、ComponentPool、Singleton、System
    bt/                     BTDef / BTInstance / BTRunner / BTRegistry（定义与实例分离）
    io/  utils/             保留
    StdC.h  MacroDefinition.h
  conf/                     命名空间 mugen::conf
    tables/*.h              按领域拆分的配置结构体（MG_REFLECT）
    ConfigTables.h          MG_CONFIG_TABLES(X)：表登记的唯一来源
    ConfigRefs.h            MG_CONFIG_REFS(X)：表间引用声明（转换器用）
    Config.h/.cpp           运行时加载 config.bin，按 id 二分查找
    BattleConst.h           战斗常量（Fixed 字面量），取自参照工程 Const.lua
    GameDef.h               枚举：状态位、额外状态、BFEvent、ControlEvent、槽位等
    LayerLoader.*           保留（.layer 解析）
  avatar/                   保留：MotionPlayer、avatar/data（.motion / .box / avatar.bin）
  render/                   仅客户端，#ifdef RUNTIME_IN_AXMOL
    spine/ ...              保留
    battle/                 新增：表现层 Presenter（§9）
  sim/                      命名空间 mugen::sim；战斗逻辑，不依赖引擎
    World.*                 世界、tick 流水线、快照与哈希
    Components.h            MG_COMPONENT_LIST(X)：组件登记的唯一来源
    Singletons.h            MG_SINGLETON_LIST(X)
    role/ skill/ tree/(actions, conditions) effect/ collision/ hit/ buff/ ability/
    motion/(位移、地图区域) ai/ room/ input/ event/ spawn/
AxmolFighter-Client/Source/ui/battle/   LocalBattleMode、ControlManager（键盘→控制事件）、BattleDebugPanel（ImGui）
AxmolFighter-Client/TestsHeadless/      无头测试工程（§10）
```

- 删除 `core/expr`、`core/fsm`（todo 3），以及 `core/Object.*`、`MG_DEFINE_SERIALIZABLE*`、`SerializableHelper.h`、`core/math/Vec2.*`、`Vec3.*`（todo 11）。
- **占位约定**：开发过程中，尚未移植的行为树叶子统一注册为 `kUnimplementedLeaf`，尚未移植的 Buff 规则统一映射为 `kUnportedRule`（首次遇到时按 id 输出一次英文日志）。不允许出现其他形式的占位。到 todo 30 和 F1 时，战斗数据引用到的占位数量必须为 0。
- `GameWord` 重命名为 `sim::World`。

---

## §2 数值与确定性

### 2.1 Fixed（`core/math/Fixed.h`）
- **表示**：`struct Fixed { int64_t raw; }`，Q44.20，`kFracBits = 20`，`kOne = 1 << 20`。
- **运算**：`+ - * /`、一元负号、比较、`+=` 等。
  - **乘法**：使用 128 位中间值，`(int128)a * b >> 20`（算术右移，向负无穷截断）。
    - MSVC x64 用 `_mul128` / `__shiftright128`。
    - clang/gcc 用 `__int128`。
    - 两套实现需要单元测试证明**逐位一致**。
  - **除法**：`((int128)a << 20) / b`，向零截断。MSVC 用 `_div128`；不可用时用 128/64 长除法。
- **构造与转换**：
  - `Fixed::fromInt(int64)`、`Fixed::fromRaw(int64)`、`Fixed::ratio(int64 num, int64 den)`。
  - 字符串字面量 `"0.0022"_fx`：`consteval` 十进制字符串解析，**只用整数运算**，四舍五入到 Q20。**禁止**从浮点字面量构造 Fixed。
  - 取整：`floor()`、`ceil()`、`trunc()`、`roundHalfUp()`、`toInt()`（向零截断）。
  - `toFloatForRender()` 只允许在 render/ui 层调用。
- **向量**：`FixedVec2`、`FixedVec3`（x, y, z），提供分量运算、`lengthSq`、`length`（确定性 sqrt）。

### 2.2 FixedMath（`core/math/FixedMath.*`）
- `sqrt`：在 raw 上做整数开方（128 位）。
- `sinDeg` / `cosDeg` / `atan2Deg`：查表加线性插值。
  - 表由同目录脚本 `FixedTables.gen.lua` 用系统 `lua` 一次性生成为整数数组 `FixedTables.inc`，生成结果提交入库。
  - 运行时**不做**浮点计算。

### 2.3 Random（`core/math/Random.*`）
- 保留 xoshiro256**，用 splitmix64 播种，状态 4×u64 可反射。
- API 对齐参照工程的 `AEUtil:GRandomF/GRandomN`：
  - `Fixed randomF(Fixed min, Fixed max)` 返回 `[min, max)`，取 20 位随机小数；
  - `int32 randomN(int32 min, int32 max)` 返回 `[min, max]`。
- **唯一实例**放在世界单例 `RngState` 中。逻辑层禁止创建临时 `Random`。
- 表现层（音效随机等）使用自己的 RNG，不能消耗模拟层的 RNG。

### 2.4 时间
- **逻辑帧**：30Hz。参照工程 `LOGIC_DT = 0.03333332` 秒，定义为 `kLogicDtSec = "0.03333332"_fx`，`kLogicDtMs = "33.33332"_fx`。
- **计时器**：参照工程中按 `delta*1000` 累加的毫秒计时器，全部用 Fixed 毫秒累加；按秒累加的（例如 Buff）用 Fixed 秒。
- **慢放**：慢放倍率作用在本帧 dt 上（`dt = kLogicDtSec * slowScale`），与参照工程 `MapManager:update(delta*SlowScale)` 一致。
- **世界时钟**：帧号与累计时间存放在单例 `WorldClock` 中，参与快照和哈希。

---

## §3 反射与序列化

### 3.1 MG_REFLECT（`core/reflect/Reflect.h`）
```cpp
struct SkillAttackConfig {
    int32_t id = 0;
    std::vector<std::vector<int32_t>> actionIds;
    Fixed pressTime;
    MG_REFLECT(SkillAttackConfig, id, actionIds, pressTime)
};
```
- **宏展开**：
  - 展开为 `template <class V> static void mgReflect(V& v, T& self)` 及其 const 版本，按声明顺序调用 `v.field("name", self.name)`；
  - 生成 `static constexpr std::string_view kMgTypeName`；
  - 最多支持 128 个字段。
- **继承**：`MG_REFLECT_DERIVED(T, Base, ...)` 先访问基类字段。数据结构尽量不用继承。
- **支持的字段类型**：
  - `bool`、`int8..64`、`uint8..64`、`enum`（按底层类型处理）；
  - `Fixed`、`FixedVec2`、`FixedVec3`、`std::string`；
  - `std::vector<T>`、`std::array<T,N>`、`std::optional<T>`；
  - `std::variant<Ts...>`（先写 index 再写值）、`std::map<K,V>`（有序）；
  - 嵌套的反射结构、实体句柄 `Entity`。
  - **不支持** `float`、`double`、指针、`unique_ptr`、无序容器，遇到时用 `static_assert` 报错。

### 3.2 Visitor
| Visitor | 位置 | 用途 |
|---|---|---|
| `BinaryWriter` / `BinaryReader` | core/serialize | 基于 ByteBuffer，大端；容器先写 u32 计数；variant 先写 u8 index；optional 先写 u8 标志 |
| `Hasher` | core/serialize | 64 位 xxh64（或 FNV-1a 64），对 BinaryWriter 的规范字节流做哈希 |
| `SchemaHasher` | core/reflect | 对"类型名 + 字段名 + 类型标签"递归哈希，得到 schemaHash |
| `LuaReader` | Tools 转换器 | §6 |
| `Inspector` | ui/battle | ImGui 只读检视器，客户端调试用 |

### 3.3 ByteBuffer 修复
- `ByteBuffer(ptr, 0)` 释放未初始化指针；
- `resize` 只拷贝 `m_position` 之前的字节，导致截断；
- `writeString` 把长度截断为 u32 时没有检查。

---

## §4 ECS（在现有 `core/ecs` 上演进为守望先锋式）

### 4.1 实体句柄
- `struct Entity { uint32_t value; }`：index 占 20 位，generation 占 12 位，`value == 0` 表示无效。
- index 回收使用 FIFO 空闲表（保证确定性）。过期句柄查询结果为"不存在"。

### 4.2 ECSManager（保留类名，重写内部）
- **实体记录**：`slots`（generation、alive、创建序号、签名 `std::bitset<64>`），以及 `order`（按创建序存放的存活实体列表）。
- **组件**：每种组件是纯数据 struct 加 `MG_REFLECT`，必须可拷贝，**不能**含 `unique_ptr` 或裸指针。
- **组件池** `ComponentPool<T>`：sparse（index → dense）加 dense（`vector<T>` + `vector<Entity>`）。
- **类型 id**：由 `sim/Components.h` 中 `MG_COMPONENT_LIST(X)` 的顺序决定，编译期固定。
- **API**：
  - `create()` / `destroy(e)`：destroy 只打标记，在 `flushDestroyed()` 时真正回收；
  - `alive(e)`；
  - `add<T>(e, T)`、`remove<T>(e)`；
  - `tryGet<T>(e)`：返回值可为空；
  - `get<T>(e)`：断言存在；
  - `has<T>(e)`。
- **单例**：`singleton<T>()`，由 `MG_SINGLETON_LIST(X)` 登记，存放 RNG、时钟、慢放、地图区域、房间状态、表现事件队列、逻辑定时器等全局状态。
- **遍历**：
  - `each<Ts...>(fn)` 按 `order` 遍历；
  - **开始遍历时取定上界**，本帧新创建的实体不参与本帧遍历（与参照工程 `EntityManager:update` 一致）；
  - 遍历期间可以创建实体，也可以给实体打销毁标记。
- **System**：无状态。`struct System { virtual void update(sim::World&) = 0; }`，执行顺序由 World 固定。
- **快照**：
  - `serialize(ByteBuffer&)` 按以下顺序写出：slots、order、空闲表、各组件池（按类型 id 顺序，写 `count + (index, 组件)`）、各单例；
  - `deserialize` 写入一个空的 manager。恢复后再序列化，得到的字节必须完全相同；
  - `clone()`：深拷贝，用于回滚；
  - `hash()`：对序列化字节做哈希。
- **删除**：Object 全局注册表、`printf` 日志、字符串查组件、isReady / isDeserialized 机制。
- `MG_GET_COMPONENT` 宏删除，统一用 `tryGet` / `get`。

---

## §5 行为树（定义与实例分离）

### 5.1 结构
- **BTDef**（不可变、可共享）：
  - DFS 顺序的节点数组 `BTNodeDef { type: Selector|Sequence|Parallel|Action, firstChild, childCount, firstCond, condCount, leafTypeId, paramIndex }`；
  - 条件数组 `BTCondDef { condTypeId, paramIndex }`；
  - 参数池 `params`：模板参数决定的 variant，由 sim 层定义。
- **BTInstance<LeafState>**（值类型，放在组件里）：
  - 每个节点的状态：`status`（`Readied|Running|Success|Failure`，int8）、`currentIndex`（int16，-1 表示无）、Parallel 运行集（位集或小数组）；
  - 每个条件的 `status`；
  - 每个叶子的 `LeafState`：`std::variant<std::monostate, ...>`，由 sim 层定义，可反射。
- **BTRegistry**：`leafTypeId → {onEnter, onUpdate, onExit}`，`condTypeId → {check, onEnter, onExit}`。都是函数指针，签名统一为 `(BTCtx&, const Param&, LeafState&)` 或 `(BTCtx&, const Param&)`。
- **BTDefCache**：按 key 缓存 BTDef。组件只保存 `defKey` 加 `BTInstance`，快照不包含拓扑；恢复时按 key **用配置确定性地重建** BTDef。

| 树 | key 构成 |
|---|---|
| ROLE 树 | 模板（ROLE / CITY）+ 技能组来源（entity_ai id + 曝气 / 搓招组集合） |
| EFFECT 树 | effect id |

### 5.2 语义（逐行平移现有 `core/bt`，它已与参照工程 C++ AEBT 对照一致）
1. 组合节点挂条件列表。`enter` 时按顺序逐个 `check`，通过一个就 `enter` 一个；遇到第一个失败就停止，组合节点进入失败。
2. 每次 `update` 先对所有条件只做 `check`。任意一个失败时，退出正在运行的子节点，**返回 Success**（不是 Failure）。
3. **Selector**：
   - `enter` 时按优先级找第一个能 enter 的子节点；
   - 子节点运行期间**不重新检查**更高优先级的兄弟节点（不抢占）；
   - 子节点 Success 后，从 `currentIndex + 1` 开始**环形轮转**，尝试其他兄弟节点（不含刚成功的那个）；都进不去则返回 Success；
   - 子节点返回 Failure 时**忽略**，Selector 保持 Running。Debug 下记一次 `MG_LOG_W`，不断言。
4. **Sequence**：
   - 子节点 Success 后 enter 下一个，下一个 enter 失败则返回 Success；
   - 子节点 Failure 视为 Running（与参照一致）。
5. **Parallel**：
   - `enter` 时 enter 全部子节点，至少有一个 Running 就算 Running；
   - 子节点结束（成功或失败）就移出运行集；
   - 运行集为空时返回 Success，**永不**返回 Failure。
6. **exit**：先退出正在运行的子节点，`currentIndex` 置为 -1，**状态置为 Readied**，再按**逆序**退出所有处于 Running 的条件。这是参照工程的顺序，与旧 mugen 的顺序不同。
7. **叶子**：
   - `onEnter` 无返回值，enter 后状态为 Running；
   - 叶子只能通过 `onUpdate` 的返回值改变状态。
8. **根节点**：根不再 Running 时**不自动重启**，只输出一次 `MG_LOG_E`（参照工程只报警）。
9. **ROLE 树切换分支的机制**（不要另加强制退出）：
   - 状态位改变后，当前分支的守卫失败 → 分支返回 Success；
   - 根 Selector 从下一个兄弟开始轮转，找到新的分支；
   - 条件的 `exit` 清除自己对应的状态位（`abortStatus`）。
   - **例子**：受击时 `dealWithStatus(Hit)` 把状态重置为 `Idle|Hit` → Attack 守卫失败 → `CondRoleAttack.exit` 执行 `resetSkill` 和 `abortStatus(Attack)` → 根节点轮转到 Hit 分支。

### 5.3 测试
在 TestsHeadless 中为第 1–9 条逐条编写单元测试，包括 enter/exit 调用顺序日志断言。

---

## §6 配置（C++ 结构体即 schema）

### 6.1 整体流程
- **Import**（保留 Lua，系统 `lua`）：参照源表 → `Config/table/<kind>.lua`。**所有数据变形都只在这一段做**：展平、camelCase、修正拼写、合并分表、补齐默认值。
- **Pack**（纯 C++，`Tools/config_converter`）：
  - `Config/table/*.lua` → `Client/Content/mugen/config/config.bin`；
  - `.box` / `.motion` → `avatar.bin`。

### 6.2 表登记
`conf/ConfigTables.h` 中的 `MG_CONFIG_TABLES(X)` 是唯一来源，形如：
```cpp
X(skill, SkillAttackConfig, KeyById)
X(equip, EquipConfig, KeyByIdAndOccupation)
...
```
运行时和转换器都从这里展开。

### 6.3 转换器读表规则（严格）
- 用 `luaL_dofile` 读入行数组，每一行按反射字段逐个 `lua_getfield`。
- **字段双向严格匹配**：Lua 行里有、结构体里没有的字段 → 错误；结构体里有、Lua 行里没有的字段 → 错误。
- 类型规则：
  - **int**：接受 Lua 整数，或数值上恰好为整数的浮点数；带小数的值报错。错误信息要带路径，例如 `skill[id=920000].actionIds[2][1]`。
  - **Fixed**：接受任意 number，`llround(v * 2^20)`。
  - **string / bool / enum / vector / array / 嵌套结构**：形状必须精确匹配。
- **id**：不允许重复，同一张表按 id（或复合键）排序后写出。
- **引用检查**：`conf/ConfigRefs.h` 中的 `MG_CONFIG_REFS(X)` 声明引用关系，例如 `X(skill, actionIds, action)`；`-1` 和 `0` 视为"空"。
  - 打包输出每类悬空引用的数量和前 5 个样例；
  - 战斗主链路（skill→action→effect→action_effect→skill_hit→displacement→buff→buff_rule）存在悬空引用时，打包失败；
  - 其余悬空引用只告警。
- **config.bin 文件头**：`magic "MGCF"`、`version`、`schemaHash`（§3.2）。运行时 schemaHash 不一致就拒绝加载，日志写 `config.bin schema mismatch, re-run config_converter`。
- **scaffold 子命令**：`config_converter scaffold <kind>` 扫描该表的所有行，推断每个字段的类型（int / Fixed / string / bool / 各层数组深度），打印出结构体草稿。

### 6.4 运行时
- `Config::find<T>(key)` 返回 `const T*`，可能为空，不打日志。
- `Config::get<T>(key)` 找不到时断言并输出 `MG_LOG_E`。
- 数据存储为按 key 排序的 `std::vector<T>`，查找用二分。

---

## §7 模拟层（sim）

### 7.1 World 的一帧（`World::tick(const FrameInput&)`），按参照工程顺序
1. `WorldClock.frame++`。清空表现事件队列：上一帧的事件已经被 Presenter 取走，或者已经写入录像。
2. **逻辑定时器**：运行 `LogicTimers`，对应参照工程的 `REGLOGICTIMER` 和 `LogicTimerTrigger:update`。
   - 定时器的负载用 variant 表示，不能是闭包；
   - 例如受击者延迟 `freeze_time_delay` 冻结。
3. 把本帧每个玩家的 `PlayerCommand` 转成控制事件，放进对应角色的 `ControlEventQueue` 组件。
4. **相机逻辑**：更新慢放倍率，得到本帧 `dt`。
5. **实体组更新**，按组的顺序：**Role → Effect → Obstacle → Goods → Portal**。
   - 每个组都**按实体主序**执行，即一个实体完整更新完再到下一个，与参照工程 `EntityManager:update` 一致。
   - 销毁处理：实体在自己那一次迭代里 update 之后，如果带有销毁标记，就在同一位置被移除。
   - 移除动作复刻 `EntityManager.lua:229-436`，例如特效的回收。
6. **场景更新**：房间状态机检查，对应 `FightScene:update`。
7. **碰撞更新**（§8），把命中回调同步派发给 `hit/`。
8. `flushDestroyed()`，然后递增世界哈希序号（不改变状态）。

### 7.2 角色单帧流水线（`role::update`，严格对照 `EntityRole.lua:1049-1130` 和 `EntityBase.lua:167-190`）
```
skill::poolUpdate → buff::poolUpdate(logicEnable) → ability::poolUpdate → (HurtNum/Combo 只发表现事件)
→ MP 回复 → summon → freeze/static 计时 → crazy → rage → hitProtect → ai::update(条件同参照)
→ [EntityBase] if freeze||static: return
   → 消费 ControlEventQueue (dealWithEvent) → BT update → 组件阶段: displacement → motion(step + 采样碰撞框) → collision 体更新
```
特效的流水线对照 `EntityEffect.lua:274-302`。注意其中冻结生效的时机。

### 7.3 坐标约定（与参照工程一致）
- **位置**：`position = (x, y, z)`。
  - x：水平方向；
  - y：高度，地面为 0，受重力影响；
  - z：纵深。
  - 屏幕平面坐标为 `(x, y + z)`。
- **朝向**：`towardX ∈ {-1, 1}` 表示面朝方向；`vector`（x、z）表示移动方向。
- **位移表**：`velocity[1..3]` 依次对应 x、y、z。纵深方向的位移最后乘 `ZRATE = 0.55`，对应 `ComponentDisplacement.lua:515`。
- **`.box`（DamageBox，整数）**：
  - `pos.x`、`size.x` → 水平方向；
  - `pos.z`、`size.z` → 屏幕竖直方向；
  - `pos.y`、`size.y` → 纵深厚度。**保留字段，判定时忽略**（§8）。

### 7.4 状态与数据
- **实体状态**：`EntityRoleStatus` 位掩码，配合 `dealWithStatus`、`mixStatus`、`abortStatus` 和 `isXxxStatus` 组合判断。这是**唯一**的状态来源，不再引入 `currentKind` 之类的第二套状态。
- **额外状态**：8 种，用引用计数实现（`EntityExtraState.lua`）。
- **属性**：三层（basic / overlay / extend 100–115）。HP、MP、EP 存放在角色上。
- **"池"类数据**：SkillPool、BuffPool、SpecialAbilityPool 在本项目中是**组件数据**（值类型的数组、表、游标），配合 `skill::`、`buff::`、`ability::` 命名空间下的自由函数。不要再写成持有指针的对象。
- **跨实体引用**：一律用 `Entity` 句柄，或参照工程中的 tag 等价物。
- **逻辑事件**（BFEvent 触发、命中回调）：同步函数调用，与参照工程一致。
- **表现事件**：写入单例队列 `PresentationEvents`。
  - 每个事件带 `(frame, entity, seq)`；
  - 事件类型：Sound、CameraShake、DisplaySpine、HurtNumber、Ghost、Bubble、Tips、RoomStateChanged、Victory、Failure 等；
  - 模拟层**从不**直接调用渲染或音频。

### 7.5 输入
- **`PlayerCommand`**：`{ controlEvent: CTR_*, quadrant, angle×1000(int), pressType }`，与参照工程同步协议同构（`SyncManager.lua`）。
- **`FrameInput`**：`frame` 加每个玩家的命令列表。录像的格式就是 FrameInput 序列。
- **客户端识别**：摇杆量化、普攻按住连打、搓招识别都在客户端 `ui/battle/ControlManager` 完成，对照 `ControlManager.lua:419, 711-802`。模拟层只接收已经识别好的 CTR 事件。

---

## §8 碰撞（`sim/collision/`）

### 8.1 碰撞体来源
- 每个带碰撞体的实体，在组件阶段由 MotionPlayer 的当前时间，从 `.box` 时间轴采样整数框。
- 本地框到世界框的变换：
  - 水平方向：`x = pos.x + towardX * box`，按朝向镜像；
  - 屏幕竖直方向：`y + z + box.pos.z`；
  - 包含缩放（复用 `avatar/DamageBoxTransform.h`，改为 Fixed 版本）。
- 结果写入组件 `ColliderState`，参与快照。

### 8.2 判定
1. **2D AABB**：在屏幕平面 `(x, y+z)` 上做矩形相交，**忽略** box 的深度字段（pos.y、size.y），但不删除这两个字段（以后可能把深度放进 `.box`）。
2. **深度过滤**：`|z_a − z_b| < radius_a + radius_b`，radius 取自实体配置（role / effect / obstacle 的 `radius`），对照 `ComponentCollision.lua:82-132`。
3. **接触点**：取两个矩形交集的中心，替代 Box2D 的 manifold 接触点。
4. **接触状态机**：每个（碰撞体，对方）对维护 `None → Began → Continue → End`。离开深度范围时补发 End。
5. **注册帧过滤**：碰撞体在哪一帧注册，那一帧发生的碰撞一律丢弃，**本地也同样执行**，对照 `ComponentCollision.lua:85`。
6. **执行时机**：碰撞在**所有实体更新之后**进行（§7.1 第 7 步）。遍历顺序为碰撞体实体的创建序 × 对方实体的创建序。

### 8.3 参照工程框形状的说明
参照工程的碰撞多边形均为 spine boundingbox 的标准矩形。导出工具在 todo 11 中增加"非矩形多边形"检测报告，用来证实这一点。

---

## §9 表现层

### 9.1 Presenter 职责（`Source/mugen/render/battle/`，仅客户端）
- `WorldPresenter` 持有 `entity → Node` 的映射；读取模拟层状态加上 `PresentationEvents`，**绝不写回** sim。
- `AvatarPresenter`：按实体的 MotionPlayer 状态（motion 文件、动作名、entry、时间）驱动 `Avatar`（`setMotion` 加 `seek`）。
  - 位置在上一逻辑帧和当前逻辑帧之间插值，渲染为 60Hz，逻辑为 30Hz。
- `MapPresenter`：使用 `LayerRuntimeLoader` 和 `VirtualCamera`。
- `CameraDirector`：镜头跟随、震屏（`action_camera`）、必杀演出（display spine）、慢放表现。
- `SoundPlayer`：播放音效，使用表现层自己的 RNG。
- `HurtNumber`：伤害数字。
- `DebugDraw`：调试绘制碰撞框、深度半径、地图区域。

### 9.2 客户端驱动层（`Source/ui/battle/`）
- **LocalBattleMode**：固定步长累加器，每帧最多追 4 个逻辑帧。
  - 每个逻辑帧依次执行：采集 ControlManager 输出 → `world.tick()` → presenter 消费事件。
  - 支持把 FrameInput 录像保存到 `AxmolFighter-Client/replays/*.mgrp`（调试开关；该目录需加入 Client 的 `.gitignore`）。
- **BattleDebugPanel**（ImGui）：
  - 反射检视器：查看选中实体的所有组件；
  - 行为树当前运行路径；
  - 世界哈希；
  - 暂停、单帧步进、设置等级、选择房间。
- **离线入口**：命令行参数 `--offline-room=<roomId>`、`--offline-role=<roleId|class>`、`--autotest-frames=N`。
  - 跳过登录，直接进入战斗；
  - 跑完 N 帧后打印 `world hash <frame> <hex>`，然后以退出码 0 退出；
  - 用于没有服务器时的 QA 和手动验收。
- **系统命令**：复活、暂停等非角色命令，以及主城远端玩家的傀儡更新，都只通过 `FrameInput.systemCommands` / `FrameInput.puppetUpdates` 进入模拟层。UI 不能直接写组件。

---

## §10 测试与验收

### 10.1 无头测试工程 `AxmolFighter-Client/TestsHeadless/`
- 独立的 CMake 工程。编译 `Source/mugen/{core,conf,avatar,sim}`，排除 `render/`，定义 `RUNTIME_IN_AXMOL=0`。
- 测试框架为 doctest，头文件取自 `$env:AX_ROOT/3rdparty/doctest/doctest.h`。
- 当 `RUNTIME_IN_AXMOL=0` 时，`MG_LOG_*` 要输出到 stderr（修改 `core/StdC.h`）。
- **入口**：`pwsh AxmolFighter-Client/TestsHeadless/run_headless_tests.ps1 [-Filter <doctest filter>]`，负责 configure、build Release 并运行。
- **场景测试辅助** `ScenarioHarness`：
  - 加载真实的 `Content/mugen/config/config.bin` 和 `avatar.bin`；
  - 创建 World、生成角色或房间；
  - 按帧注入 `PlayerCommand`；
  - 断言状态位、HP、实体数量、组件字段等。
  - 每个玩法 todo 至少提供 2 个场景测试：一个正常路径，一个边界或失败路径。
- **命令行工具 `mugen_sim_cli`**：
  - `replay <file> [--hash-every N]`：重放录像并打印哈希；
  - `run-room <roomId> --frames N --script <cmds>`：用于确定性测试和 QA 取证。

### 10.2 规则检查（`TestsHeadless/check_rules.ps1`，每个 todo 都要通过）
- `rg` 检查以下内容：
  - `sim/` 和 `core/` 中没有 axmol、spine、imgui 的 include；
  - `sim/` 和 `core/` 中没有 `float`、`double`、`std::function`、`unordered_map` 或 `unordered_set`（注释除外，由脚本过滤）；
  - `AxmolFighter-Client/Source/` 下没有参照产品名：`heiyue`、`黑月`，以及英文名，英文名由脚本内置；
  - 日志宏参数中没有中文。
- 脚本输出违规的 `文件:行`，有违规就返回非 0 退出码。

### 10.3 客户端构建
- 在 `AxmolFighter-Client` 下执行 `axmol build -p win32`（即 `build.bat`），退出码必须为 0。
- 新增或删除了文件时，先执行 `axmol build -p win32 -c`。

### 10.4 手动验收清单
到达里程碑时，编排者把验收步骤写入 `.omo/evidence/milestones/M<n>.md`，内容包括操作步骤和预期现象，供用户用 `run.bat Release` 手动验收。
