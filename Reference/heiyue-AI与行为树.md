# heiyue AI 与行为树参考

> 范围：`heiyue/src` 中的 AEBT 行为树（实体/技能/特效表现层状态机）、behaviac AI（决策层）、`module/fsm` 简单状态机。
> 所有路径相对 `heiyue/src/`，格式 `path:line`。标 **未确认** 的内容无法从 Lua 源确认（通常在 C++ 引擎侧）。标 **【死代码】** 的内容未被加载或已被注释。

---

## 0. 总览：两层结构

| 层 | 实现 | 驱动 | 职责 |
|---|---|---|---|
| 决策层 | behaviac 树 `Entity.xml`，由 C++ `AEEntityAgent` 执行，回调到 Lua 的 `AiAgent` | `EntityRole:update` → `pAgent:update`（`module/entity/EntityRole.lua:1103-1113`） | 选目标、选技能、决定巡逻/追击/警戒位置。**只修改实体状态位**（`dealWithStatus`/`presetSkill`） |
| 表现层 | AEBT 行为树（C++ 节点 `AEBTSelector/Sequence/Parallel/Action/Condition` + Lua 子类） | `EntityBase:update` → `pBehaviorTree:update`（`module/entity/EntityBase.lua:183-185`） | 按实体状态位选分支，播动画、位移、出特效、判定打断、切换下一状态 |

两层之间只有一个耦合点：**实体状态位**（`isXxxStatus()` / `mixStatus` / `abortStatus` / `dealWithStatus`）。AI 写状态位，行为树的 Condition 读状态位；Action 结束时再写下一状态位（例如 `ActionHitUp` → `mixStatus(HitDown)`）。唯一反向调用：`ActionPatrol:execute` 直接调 `pAgent:checkTarget()`（`module/behaviortree/actions/ActionPatrol.lua:54`）。

---

## A. AEBT 行为树

### A.1 节点基类（C++ 绑定）

Lua 源里没有 AEBT 节点的实现，它们都是 C++ 导出类，Lua 只负责创建和继承：

| 类 | 创建点 | 说明 |
|---|---|---|
| `AEBTSelector` | `module/behaviortree/BehaviorManager.lua:15` | 组合节点，表名 `"BTSelector"` |
| `AEBTSequence` | `module/behaviortree/BehaviorManager.lua:17` | 组合节点，表名 `"BTSequence"` |
| `AEBTParallel` | `module/behaviortree/BehaviorManager.lua:13` | 组合节点，表名 `"BTParallel"` |
| `AEBTAction` | `module/behaviortree/actions/ActionBase.lua:5-7` | 叶子（动作）基类，`ActionBase` 用 `class(name, function() return AEBTAction:create() end)` 继承 |
| `AEBTCondition` | `module/behaviortree/conditions/ConditionBase.lua:2-4` | 条件节点基类，`ConditionBase` 继承它 |

从 Lua 侧能看到的 C++ 接口有：`addChild`、`addCondition`（`BehaviorManager.lua:49,55,64`）、`findChild(index)`（`BehaviorTree.lua:89`）、`removeAllChildren`（`EntityRole.lua:935`）、`getState`/`setState`（`BehaviorTree.lua:34`、各 Action）、`registerScriptHandler`/`unregisterScriptHandler`（`ActionBase.lua:65,75`）、`enter`/`exit`/`update`（`BehaviorTree.lua:35,72,78`）。

**装饰节点**：没有独立的装饰节点类型。每个组合节点都可以挂 `condition` 列表，作用相当于前置守卫（`BehaviorManager.lua:51-57`）。

### A.2 返回状态

`EnumBTStatus`（`module/behaviortree/BehaviorTree.lua:2-7`）：

| 值 | 名称 |
|---|---|
| 0 | `Readied` |
| 1 | `Running` |
| 2 | `Success` |
| 3 | `Failure` |

Lua Action 通过 `self:setState(EnumBTStatus.Success)` 主动宣告完成（例如 `ActionDestroy.lua:11`、`ActionMove.lua:82`）。Lua 代码里没有任何地方设置 `Failure`。Action 在 `setState` 之前一直保持 C++ 设定的状态（推测是 `Running`，**未确认**）。

### A.3 Tick 语义

1. `BehaviorTree:update(delta)`（`BehaviorTree.lua:32-62`）只在根节点状态为 `Running` 时调用 `pRootNode:update(delta)`。如果根节点因此变成非 `Running`，只打印一次 ASCII 报警日志（`:40-58`），**不会重启**。第 37-39 行注释掉的就是重启逻辑。所以根节点必须永远保持 `Running`：Selector 根节点靠"总有一个分支条件成立"来维持。
2. C++ 通过 `registerScriptHandler` 回调 Lua：
   - Action：`onScriptHandler(func, delta)`，`func ∈ {"update","enter","exit","dispose"}`（`ActionBase.lua:132-150`）。`update` 会先把 `ActionBase.DT = delta*1000` 累加到 `fTime`（毫秒），再调 `execute`（`:104-109`）。
   - Condition：`func ∈ {"check","enter","exit","dispose"}`，`check` 返回 `execute()` 的布尔值（`ConditionBase.lua:39-53`）。
3. 条件的 `enter`/`exit` 语义：组合节点被选中时调 condition `enter`，分支被离开时调 condition `exit`。几乎所有 Condition 都在 `exit` 里 `abortStatus(对应状态)`（例如 `ConditionHit.lua:19-20`），也就是说"离开分支即清除该状态位"。Selector 每帧按顺序重新检查条件，当优先级更高的分支条件成立时是否会抢占当前 Running 分支，由 C++ 决定（**未确认**；从 ROLE 树把 Death/Hit 放在前面、并依赖 `exit` 清状态来看，应该是会抢占）。
4. `BTParallel` 在每个状态分支里只挂一个 Action，实际等价于"守卫 + 单动作"。`BTSequence` 用于 `Death→Destroy`、`Collect→Destroy`、特效的多段 `AttackEffect→…→ActionDestroy`。
5. Action 的 `enter`/`exit` 会向 BuffPool 发出 `BFEvent.BEHAVIOR_STATE_START/END`，参数是类名（`ActionBase.lua:82-98`）。这是 Buff 系统感知行为状态的钩子。

### A.4 黑板 / 上下文

没有显式的黑板。上下文由以下几部分组成：
- `self.pEntity`（`ActionBase:init`，`ActionBase.lua:57-68`；`ConditionBase:init`，`ConditionBase.lua:10-17`），以及从它取到的 `pAvatar = ComponentAvatar`、`pDisplacement = ComponentDisplacement`（`ActionBase.lua:61-62`）。
- 实体状态位（`isXxxStatus`/`mixStatus`/`abortStatus`/`dealWithStatus`）。
- `entity:getEntityParams()` 临时参数表：`move_pos`（ActionMove 系列）、`hit_id`（连击受击）、`displacement_id`（Jostled）。
- `entity:getSkillManager()`，即 SkillPool：它的当前 slot/slotIndex/modeIndex/stepIndex/pipeIndex/toward 游标，供攻击子树的条件读取（见 A.7）。
- 构造参数 `parameter`：`new(node):init(entity, parameter)`（`BehaviorManager.lua:54,63`）。

### A.5 树的构建

- `BehaviorManager:createBehaviorTree(entity, treeData)`（`BehaviorManager.lua:74-83`）：创建根节点，包成 `BehaviorTree`，然后递归调用 `resolveBehaviorTree`。
- `BehaviorManager:resolveBehaviorTree(parent, childrenData, entity)`（`:45-72`）：对每个子项，先 `create(node)`（只认 3 种组合节点），再为 `condition[]` 逐个 `new(name):init(entity, parameter)` 并 `addCondition`，为 `action[]` 逐个 `new(name):init(...)` 并 `addChild`。如果有 `children` 就递归。注释 `:59` 说明：action 和 children 在语义上二选一。
- `BehaviorManager` 的 `init/dispose/update/draw` 都是空实现（`:21-35`）。

各实体使用的树：

| 实体 | 树常量 | 调用点 |
|---|---|---|
| EntityRole（主角/怪/伙伴/召唤/Boss 通用） | `BEHAVIOR.ROLE` | `module/entity/EntityRole.lua:661` |
| EntityEffect | `BEHAVIOR.EFFECT`（每次创建前改写 action） | `module/entity/EntityEffect.lua:113-114` |
| EntityPortal | `BEHAVIOR.PORTAL` | `module/entity/EntityPortal.lua:145` |
| EntityPet | `BEHAVIOR.PET` | `module/entity/EntityPet.lua:51` |
| EntityObstacle | `BEHAVIOR.OBSTACLE` | `module/entity/EntityObstacle.lua:59` |
| EntityNpc | `BEHAVIOR.NPC` | `module/entity/EntityNpc.lua:43` |
| EntityGoods | `BEHAVIOR.GOODS` | `module/entity/EntityGoods.lua:65` |
| EntityCityRole | `BEHAVIOR.CITY_ROLE` | `module/entity/EntityCityRole.lua:54` |

生命周期：`EntityBase:enter` → `pBehaviorTree:enter()`（`EntityBase.lua:202-204`）；`EntityBase:exit` → `exit()`（`:211-213`）；`EntityRole:unload` 会 `exit()`，并对攻击节点 `removeAllChildren()`（`EntityRole.lua:931-936`）。

**【死代码】**
- `BEHAVIOR.CHARACTER`（`imports/ConstBehaviorTree.lua:64-150`）和 `BEHAVIOR.MONSTER`（`:157-237`）从未被 `createBehaviorTree` 使用。它们引用的 `ConditionCharacterIdle`、`ActionKnock`、`ActionLie`、`ConditionLie`、`ConditionCharacterAttack` 等类在 `actions/`、`conditions/` 中都不存在。`CHARACTER_ATTACK_NODE_INDEX=3`（`:62`）和 `MONSTER_ATTACK_NODE_INDEX=2`（`:155`）也未使用。
- `BEHAVIOR.EFFECT` 定义了两次（`:241-259` 和 `:519-530`），后一次覆盖前一次。
- `_GAME_NEW_SKILL_SYSTEM = false`（`imports/Const.lua:777`），所以 `ConstBehaviorTree.lua:551-653` 替换版 ROLE 树（攻击条件为 `XConditionAttack`，且没有 Controlled 分支）以及 `ConditionBase.lua:58-65` 的 X 系列条件都**不生效**。
- `ConditionAttack.lua` 不在 `ConditionBase.lua:55-117` 的加载列表中，属于死代码（它只被 MONSTER 树引用）。`ConditionActive`（`:55`）和 `ActionActive`（`ActionBase.lua:156`）虽然被加载，但没有任何树引用。`ActionFall`、`ConditionFall` 被加载但未被使用。

### A.6 ROLE 树（生效版本）完整子节点顺序

根：`BTSelector`（`imports/ConstBehaviorTree.lua:264-369`）。索引按 Lua 1 起算，C++ `findChild` 使用 0 起算（见 `:261` 注释）。

| # (C++ idx) | 组合 | 条件（条件为真的依据） | 叶子 | 行 |
|---|---|---|---|---|
| 1 (0) | Sequence | `ConditionDeath`：`isDeathStatus()`（`conditions/ConditionDeath.lua:8-13`） | `ActionDeath` → `ActionDestroy` | `:269-277` |
| 2 (1) | Parallel | `ConditionRevive`：`isReviveStatus()`（`ConditionRevive.lua:5-10`），exit 被注释，不清状态 | `ActionRevive` | `:278-282` |
| 3 (2) | Parallel | `ConditionWake`：`isWakeStatus()`（`ConditionWake.lua:8-13`） | `ActionWake` | `:283-287` |
| 4 (3) | Parallel | `ConditionGetUp`：`isGetUpStatus()` | `ActionGetUp` | `:288-292` |
| 5 (4) | Parallel | `ConditionHitFloor`：`isHitFloorStatus()` | `ActionHitFloor` | `:293-297` |
| 6 (5) | Parallel | `ConditionHitDown`：`isHitDownStatus()` | `ActionHitDown` | `:298-302` |
| 7 (6) | Parallel | `ConditionHitUp`：`isHitUpStatus()` | `ActionHitUp` | `:303-307` |
| 8 (7) | Parallel | `ConditionHitSwitch`：`isHitSwitchStatus()` | `ActionHitSwitch` | `:308-312` |
| 9 (8) | Parallel | `ConditionHit`：`isHitStatus()` | `ActionHit` | `:313-317` |
| **10 (9)** | **Selector** | `ConditionRoleAttack`：`isAttackStatus()`；exit 时 `SkillManager:resetSkill()` 并 `abortStatus(Attack)`（`ConditionRoleAttack.lua:12-24`） | **children 为空，运行时注入技能子树** | `:318-322` |
| 11 (10) | Parallel | `ConditionJostled`：`isJostledStatus()` | `ActionJostled` | `:323-327` |
| 12 (11) | Parallel | `ConditionPatrol`：`isPatrolStatus()` | `ActionPatrol` | `:328-332` |
| 13 (12) | Parallel | `ConditionChase`：`isChaseStatus()` | `ActionChase` | `:333-337` |
| 14 (13) | Parallel | `ConditionAlert`：`isAlertStatus() and not isTobeHitStatus()`（`ConditionAlert.lua:6-14`） | `ActionAlert` | `:338-342` |
| 15 (14) | Parallel | `ConditionPathFinding`：`isFindingStatus()` | `ActionPathFinding` | `:343-347` |
| 16 (15) | Parallel | `ConditionRun`：`isRunStatus() and not (Attack or Jostled)`（`ConditionRun.lua:6-15`） | `ActionRun` | `:348-352` |
| 17 (16) | Parallel | `ConditionWalk`：`isWalkStatus() and not (Attack or Jostled)`（`ConditionWalk.lua:6-15`） | `ActionWalk` | `:353-357` |
| 18 (17) | Parallel | `ConditionRoleIdle`：`isIdleStatus() and not (Attack/Wake/TobeHit/Move/Jostled)`（`ConditionRoleIdle.lua:4-16`） | `ActionIdle` | `:358-362` |
| 19 (18) | Parallel | `ConditionControlled`：`isControlledStatus()` | `ActionControlled` | `:363-367` |

`ROLE_ATTACK_NODE_INDEX = 9`（`:262`）对应第 10 个子节点，也就是攻击 Selector。

优先级含义：死亡 > 复活 > 醒来 > 起身 > 倒地 > 下落 > 浮空 > 受击切换 > 受击 > **攻击** > 推挤 > 巡逻/追击/警戒 > 寻路 > 跑/走 > 待机 > 失控。受击优先于攻击，攻击优先于 AI 移动。

其它树（简表）：
- PORTAL（`:371-422`）：Close > Transfer > Active > Level > Professional > Difficulty > SpecIdle > Key > Task。各条件之间互斥，见 `ConditionPortal*.lua`。
- OBSTACLE（`:424-449`）：`ConditionDestroy` → `ActionDeath`+`ActionDestroy`；`ConditionKnock` → `ActionHit`；`ConditionIdle` → `ActionIdle`。
- NPC（`:451-467`）：`ConditionNpcIdle` → `ActionNpcIdle`；`ConditionNpcSpecIdle` → `ActionNpcSpecIdle`。
- GOODS（`:469-494`）：`Collect` → `ActionCollect`+`ActionDestroy`；`Spurt` → `ActionSpurt`；`Idle` → `ActionIdle`。
- PET（`:496-517`）：`Follow` → `ActionFollow`；`SpecIdle` → `ActionSpecIdle`；`PetIdle` → `ActionIdle`。
- CITY_ROLE（`:532-548`）：`CityRolePathFinding` → `ActionCityRolePathFinding`；`CityRoleIdle` → `ActionIdle`。

### A.7 攻击子树注入（技能 → 行为树）

`SkillPool:loadSkill`（`module/skill/SkillPool.lua` 约 `:40-90`）按技能组（Normal、Crazy、JoyStick、JoyStick_Crazy、Special，配置在 `:60-70`）调用 `resolveSkill` 生成 `childrenData`。然后 `behaviorTree:findChild(BEHAVIOR.ROLE_ATTACK_NODE_INDEX)`（`:85`）找到攻击 Selector，再调 `BehaviorManager:resolveBehaviorTree(attackNode, childrenData, entity)`（`:89`）挂上去。

槽位字符：普通组是 `string.char(64+slot)`，即 `A,B,C…`；暴气组带 `+` 后缀；搓招组是数字加 `+`；Special 组从 `90-#special` 开始，所以末尾是 `…Y,Z`（`SkillPool.lua:61-69,650-656`）。

注入后的层级（每层的条件都与 SkillManager 游标做相等比较，在条件的 enter/exit 中回调 `dealWithCastXxxBegan/Ended`）：

```
AttackSelector (ROLE child 10, ConditionRoleAttack)
└─ BTSelector  [ConditionAttackSlot{skillSlot}]                    SkillPool.lua:674-678
   └─ BTSelector [ConditionAttackSkillStep{slot,slotIndex,modeIndex,stepIndex,skill}]   :800-808
      │   （每个连携索引 × 招式 × 步骤各一个，步骤沿 skill_attack.next_skill 递归，:811-813）
      └─ BTSelector [ConditionAttackPipe{...,pipeIndex=i}]  i = releaseMaxCount..1   :833-852
         ├─ (按下释放) BTSequence [ConditionAttackVectorIndex{vectorIndex=j}]  j=action_ids 方向索引  :902-914
         │     action: AttackRole{actionId, actionIndex, skill} × N（顺序播放）          :910
         └─ (抬起释放 skill:getUpRelease()) BTSelector                                   :862-873
               ├─ BTSequence [ConditionAttackRelease{skill}] → Toward 节点(up_action_ids)
               └─ BTSequence [ConditionAttackPress{skill}]   → Toward 节点(action_ids)
```

- SlotIndex/Mode 两层 Selector 已被注释掉（`SkillPool.lua:714-718,742-746`），它们的条件合并进了 `ConditionAttackSkillStep`。因此 `ConditionAttackSlotIndex`、`ConditionAttackSkillMode` 虽被加载，却不参与构建（**【死代码】**）。
- 条件判断：
  - `ConditionAttackSlot`：`slot == getSkillSlot(true)`（`conditions/ConditionAttackSlot.lua:19-25`）
  - `ConditionAttackSkillStep`：四元组相等（`ConditionAttackSkillStep.lua:28-38`）
  - `ConditionAttackPipe`：五元组相等（`ConditionAttackPipe.lua:29-39`）
  - `ConditionAttackVectorIndex`：`vectorIndex == getSkillToward()`（`ConditionAttackVectorIndex.lua:37-43`，其中 21-36 行被注释）
  - `ConditionAttackPress`：`not skill:canUpRelease()`
  - `ConditionAttackRelease`：`skill:canUpRelease()`
- 卸载：`EntityRole:unload` 对攻击节点 `removeAllChildren()`（`EntityRole.lua:934-935`），`SkillPool:unloadSkill` 删除 SkillBase（`SkillPool.lua:92-105`）。

**特效树注入**：`EntityEffect:dealWithActionTree(action_ids)`（`module/entity/EntityEffect.lua:332-345`）为每个 `action_id ~= -1` 生成 `{node="AttackEffect", parameter={[1]=actionId,[2]=i}}`，末尾追加 `ActionDestroy`。结果写进 `BEHAVIOR.EFFECT.children[1].action` 后再创建树（`:113-114`）。这里改写的是全局表，每次创建前都会覆盖。整棵树是 `Sequence[ConditionEffectAttack] → AttackEffect… → ActionDestroy`：特效播完所有段就自毁。

### A.8 叶子动作类（全部）

基类链：`AEBTAction` → `ActionBase` → {`ActionMove`、`ActionCanBreakBase`、`ActionAttack`} → 具体类。加载列表见 `ActionBase.lua:153-195`。

| 类 | 定义 | 父类 | 功能 / 参数 |
|---|---|---|---|
| `ActionBase` | `actions/ActionBase.lua:5` | AEBTAction | 通用生命周期；`ActionType` 动画名映射 `:11-38`；`fTime` 以毫秒计 `:104-109` |
| `ActionMove` | `actions/ActionMove.lua:3` | ActionBase | AI 移动基类。`init` 计算单帧位移 `velocity*LOGIC_DT*1000*WALK_RATE/RUN_RATE`（`:12-24`）。`execute`：如果处于 Attack 状态则直接 Success（`:26-33`）。`dealWithMove` 朝 `move_pos` 走，到达后切 Idle 动画（`:47-78`）。`dealWithTime`：到达后停留 `fDelayTime` 再 Success（`:80-84`）。撞边界也算完成（`:35-45`） |
| `ActionCanBreakBase` | `actions/ActionCanBreakBase.lua:2`（注意 cname 误写为 `"ActionHit"`） | ActionBase | 受击类基类。当前技能或前一技能是 `BREAK_SLOT`（挣脱）时 `setSuccessStatus(Attack)`（`:10-34`） |
| `ActionAttack` | `actions/ActionAttack.lua:5` | ActionBase | 攻击基类。动画结束处理 `:56-67`（loop 次数）；位移事件处理 `:73-105`（brake/边界 obstruct/地面 floor）；`dealWithTime`：动画结束且超过 `action_delay_time` 后 Success（`:110-115`）；`dealWithControl` 按 control 0/2/3 处理（`:120-157`）；震屏 `:162-179`；特效 spine 递归预加载 `:184-242`；音效 `:248-275`。exit 时销毁 `auto_release==0` 的特效（`:37-50`） |
| `AttackRole` | `actions/AttackRole.lua:7` | ActionAttack | 角色技能动作，读 `action_attack` 表。参数 `{actionId, actionIndex, skill}`（`:30-52`）。预加载特效/spine/音效/变身实体（`:57-140`）。enter：禁止打断、处理 control==1 朝向、PVP 机器人第一段朝向目标（`:200-208`）、设置位置朝向（`:274-297`）、触发 `BEFORE_ROLE_SKILL_ACTION`、播放动画与位移、加 buff、残影、提示、喊招气泡、音效（`:180-269`）。execute 依次做：必杀演出、计时、受击保护、打断窗口 `dealWithInterrupt`（`interrupt_frame` 之后按优先级切换 next skill 或 run，`:390-435`）、超级打断 `dealWithExtraInterrupt`（`:440-482`）、控制、按帧出特效（`:487-534`）、震屏、变身（`:550-563`）、全屏定身 static（`:568-610`） |
| `AttackEffect` | `actions/AttackEffect.lua:2` | ActionAttack | 特效动作，读 `action_attack_effect` 表，参数是 `{[1]=actionId,[2]=index}`（`:18-37`）。按帧生成子特效（`:153-169`），按 `summon_frame` 召唤怪物，召唤物继承难度、血量增幅和等级（`:171-240`）。受击音效按 `sound_type` 选择（`:113-123`） |
| `ActionDeath` | `actions/ActionDeath.lua:2` | ActionBase | 死亡动画和位移（`:26-35`）。计时超过 `ROLE_DEATH_TIME` 后抛出 `ET.GAME_ROLE_DEATH` 并 Success；障碍物用 `OBSTACLE_DEATH_TIME`（`:77-92`）。负责掉落（`:128-186`，掉落物进入 Spurt） |
| `ActionDestroy` | `actions/ActionDestroy.lua:2` | ActionBase | enter 时 `entity:destroy(true)`，execute 时 Success |
| `ActionRevive` | `actions/ActionRevive.lua:3` | ActionBase | enter 时 `dealWithRevive()`，自身永不 Success（由状态切换离开） |
| `ActionWake` | `actions/ActionWake.lua:2` | ActionBase | 播放 Idle 动画，加醒来无敌 buff（Hero 与敌方用不同的 `Const.ROLE_*_WAKE_BUFF_ID`），重置刚性和受击保护，下一帧 Success（`:4-36`） |
| `ActionGetUp` | `actions/ActionGetUp.lua:2` | ActionBase | 播放起身动画。Hero 加 buff 156/154（仅 PVP 生效）。动画完成后 `mixStatus(Wake)`，如果已死则进入 Death（`:4-39`） |
| `ActionHit` | `actions/ActionHit.lua:2` | ActionCanBreakBase | 地面受击：hit 动画加位移、硬直计时 `dealWithTime`（`:128`）、连击 `dealWithDoubleHit`（`:146`）→ HitUp；位移 lie → HitDown（`:107-119`） |
| `ActionHitSwitch` | `actions/ActionHitSwitch.lua:2` | ActionCanBreakBase | 受击切换动画，完成后 abort；再次被击时 `mixStatus(Hit)`（`:25-30`） |
| `ActionHitUp` | `actions/ActionHitUp.lua:2` | ActionCanBreakBase | 浮空。动画完成且位移 air/lie 后 → HitDown（`:29-59`）；空中连击重设位移（`:61-99`） |
| `ActionHitDown` | `actions/ActionHitDown.lua:2` | ActionCanBreakBase | 下落。动画完成且位移 lie 后 → HitFloor（`:37-67`）；连击 hit_type 0/2 → HitUp（`:69-96`） |
| `ActionHitFloor` | `actions/ActionHitFloor.lua:2` | ActionCanBreakBase | 倒地。计时到了之后 → GetUp，已死则 → Death（`:70-78`）；倒地追击 → HitDown/HitUp（`:87-115`） |
| `ActionControlled` | `actions/ActionControlled.lua:2` | ActionCanBreakBase | 失控（被抓等）。动画完成 → HitUp（`:80-91`），位移完成 → HitDown（`:97-109`），计时 `:118`，连击 `:135` |
| `ActionJostled` | `actions/ActionJostled.lua:2` | ActionBase | 被推挤：按 `entityParams.displacement_id` 位移，brake 时 Success（`:11-50`） |
| `ActionIdle` | `actions/ActionIdle.lua:2` | ActionBase | 播放 stand 动画并重置位移。Hero 触发受击血量保护时 → HitDown（`:26-35`） |
| `ActionWalk` / `ActionRun` | `actions/ActionWalk.lua:2` / `actions/ActionRun.lua:2` | ActionBase | 玩家摇杆移动：`dealWithTransform(controlParam, velocity*WALK_RATE/RUN_RATE)`（`Walk:43-48`、`Run:43-48`），脚步音效随动画循环播放，带受击保护 |
| `ActionPatrol` | `actions/ActionPatrol.lua:2` | ActionMove | AI 巡逻移动到 `move_pos`，延时取 `patrol_delay_time`（`:17`）。**每帧调 `pAgent:checkTarget()`，发现目标就 Success**（`:52-60`）。机器人/自动战斗用 Run 动画 |
| `ActionChase` | `actions/ActionChase.lua:2` | ActionMove | 追击移动，延时取 `chase_delay_time`（`:18`），非机器人时面向目标（`:30-37`） |
| `ActionAlert` | `actions/ActionAlert.lua:2` | ActionMove | 警戒游走，延时取 `alert_delay_time`（`:20`），会抛新手事件 `ENTITY_OnAlert`（`:44-46`） |
| `ActionPathFinding` | `actions/ActionPathFinding.lua:2` | ActionBase | 战斗内寻路（自动战斗走向传送门），按 Walk/Run 速率沿路径走，到终点后 Success（`:16-120`） |
| `ActionCityRolePathFinding` | `actions/ActionCityRolePathFinding.lua:2` | ActionBase | 主城角色寻路，逻辑同上（`:14-105`） |
| `ActionFollow` | `actions/ActionFollow.lua:4` | ActionBase | 宠物跟随，使用 `Const.PET_CONFIG` 的边界、加速和防抖参数（`:19-156`） |
| `ActionSpecIdle` | `actions/ActionSpecIdle.lua:2` | ActionBase | 宠物特殊待机，动画完成后 Success |
| `ActionNpcIdle` | `actions/ActionNpcIdle.lua:2` | ActionBase | 待机循环 `action_times` 次后 `mixStatus(NpcSpecIdle)`（`:27-35`） |
| `ActionNpcSpecIdle` | `actions/ActionNpcSpecIdle.lua:2` | ActionBase | 从 `action_name` 中随机一个动作播放，并显示聊天气泡（`:12-19`） |
| `ActionCollect` | `actions/ActionCollect.lua:2` | ActionBase | 拾取：动画完成后弹奖励并 Success（`:20-32`） |
| `ActionSpurt` | `actions/ActionSpurt.lua:2` | ActionBase | 掉落物随机抛射（带重力和弹跳），lie 时 Success（`:16-84`） |
| `ActionTransfer` | `actions/ActionTransfer.lua:2` | ActionBase | 传送门传送动画完成后 Success |
| `ActionPortalActive/Close/Level/Professional/Difficulty/SpecIdle/Key/Task` | `actions/ActionPortal*.lua:2` | ActionBase | 只按 `getSpineAction(status)` 播放对应 spine 动画 |
| `ActionActive` | `actions/ActionActive.lua:2` | ActionBase | **【死代码】**，没有树引用 |
| `ActionFall` | `actions/ActionFall.lua:2` | ActionBase | **【死代码】**，没有树引用 |

受击状态转移链（由 Action 写回的状态位）：`Hit →(连击)HitUp →HitDown →HitFloor →GetUp →Wake →(Idle)`。任何阶段如果已死，都会进入 `Death`。

---

## B. behaviac AI

### B.1 运行时加载器

- behaviac 运行时和 `AEEntityAgent` 都在 C++ 侧。Lua 只调 `AEEntityAgent:create()`（`module/ai/AiAgent.lua:107`）、`registerEntityAgentEventHandler`（`:108`）和 `update(delta)`（`:73`）。
- 导出文件：`imports/behaviac_exported/Entity.xml`（树 `name="Entity" agenttype="EntityAgent" version="5"`，`:4`），元数据在 `imports/behaviac_exported/meta/Closers.meta.xml`。C++ 如何定位和加载这个 XML、加载哪个树名，**未确认**（Lua 中没有 `behaviac` 字样的加载调用）。
- 回调机制：C++ 在执行树中的 Method 节点时回调 `AiAgent:onEntityAgentEvent(funcName)`，Lua 执行 `self[funcName](self)` 并返回 `AIStatus`（`AiAgent.lua:742-749`）。XML 中的方法名是 PascalCase（`CheckAttack`），Lua 中是 camelCase（`checkAttack`），所以 C++ 应该做了首字母小写转换（**未确认**）。
- `AIStatus`（`AiAgent.lua:22-27`）：`AI_INVALID=0, AI_SUCCESS=1, AI_FAILURE=2, AI_RUNNING=3`，与 behaviac `EBTStatus` 的 BT_INVALID/SUCCESS/FAILURE/RUNNING 数值一致。

### B.2 导出树文件

| 文件 | 作用 |
|---|---|
| `imports/behaviac_exported/Entity.xml` | 唯一的 AI 树，所有 AI 角色（怪物、Boss、PVP 机器人、自动战斗主角、伙伴）共用 |
| `imports/behaviac_exported/meta/Closers.meta.xml` | 声明 agent `EntityAgent : behaviac::Agent`，唯一属性 `eStatus: EntityStatus`，默认值 `NoAlert`（`:4-7`） |

所有差异化都来自 `entity_ai` 表参数和 Lua 分支（例如 `isMainRole() and CacheRole:getAutoFight()`）。

### B.3 Agent 类 `AiAgent`（`module/ai/AiAgent.lua:29`）

**属性**

| 名称 | 行 | 说明 |
|---|---|---|
| `pEntity` | `:36,43` | 所属 EntityRole |
| `bIsInit` | `:38,106` | 懒初始化标志 |
| `fChangeTargetDelta` | `:39,89-93` | 仇恨换目标计时（秒），阈值 `Const.CHANGE_TARGET_TIME = 10`（`imports/Const.lua:634`） |
| `checkFuncName` / `checkCount` | `:45-46,743` | 调试用：最近一次回调的函数名 |
| `pEntityAgent` | `:107` | C++ `AEEntityAgent` 实例 |
| `eStatus`（behaviac 侧） | `Closers.meta.xml:6` | `Alert`/`NoAlert` 两态，由 XML 的 Assignment 节点修改，Lua 不可见 |

**方法**

| 方法 | 行 | 返回 / 作用 |
|---|---|---|
| `ctor` / `init(entity)` | `:35-49` | 注册 `ET.PARTNER_CHANGE` 事件 |
| `dispose` / `release` | `:51-63` | 注销事件，删除 agent |
| `update(delta)` | `:65-94` | `getLogicEnable` 为假时直接返回。懒创建 agent，`_GAME_DEBUG_CONTROL_` 为假时 tick behaviac。**嘲讽 buff**（`gBuffRule.BFSneer`）存在时强制目标为施加者并提前返回。否则每 10 秒调 `changeTarget` |
| `draw` | `:96` | 空实现 |
| `onPartnerChange(new, old)` | `:99-103` | 伙伴换人时迁移目标 |
| `initAgent` | `:105-109` | 创建 `AEEntityAgent` 并注册回调 |
| `changeTarget` | `:114-130` | 仇恨：在 `getRecountArray` 中选伤害统计（`getRecount`）最高、且存活、可被命中（`not getHit()`）的角色，然后 `cleanRecount` |
| `checkAttack` | `:133-169` | 死亡返回 FAILURE；被嘲讽且目标存活返回 SUCCESS；目标无效时从 `findTargetForAI` 中随机选一个可命中的敌人；没有敌人时，自动战斗会 `moveToDoor`，然后把目标设为自己并返回 FAILURE |
| `checkAttackEnd` | `:171-178` | 处于 Attack 状态返回 RUNNING，否则 SUCCESS |
| `checkHit` | `:180-186` | 处于 TobeHit 状态返回 SUCCESS，否则 FAILURE |
| `checkHitEnd` | `:188-213` | 受击中返回 RUNNING；没有目标时随机补一个；仍无敌人返回 FAILURE |
| `checkChase` | `:215-286` | 判断目标是否**在** `chase_scope_x/z` 环形区间内：在区间内返回 FAILURE（不需要追），在区间外返回 SUCCESS（需要追）。scope 全为 0 时返回 FAILURE |
| `checkMoveEnd` | `:288-297` | 移动中返回 RUNNING；目标不是自己（巡逻途中发现了敌人）返回 FAILURE；否则 SUCCESS |
| `checkTarget` | `:299-323` | 先把目标重置为自己，再在 `target_scope_x/z`（有符号偏移 self-enemy）内找第一个可命中的敌人，找到返回 SUCCESS |
| `executeRandAttack` | `:325-363` | 非警戒时攻击：没有敌人时（自动战斗走门）返回 RUNNING；`presetSkill("Z", false)` 成功则 `dealWithStatus(Attack)` 并返回 RUNNING，失败返回 SUCCESS |
| `executeFirstAttack` | `:365-399` | 惊醒攻击：朝向目标，`presetSkill("X", false)`，成功后 `dealWithDirection` |
| `executeAttack` | `:401-572` | 主攻击决策，见 B.5 |
| `executeChase` | `:574-599` | 目标点 = 目标位置 ± `chase_scope_x[2]`/`chase_scope_z[2]`（站在目标靠自己一侧的最远攻击距离处），`dealWithStatus(Chase, calcPos(pos))` |
| `executeAlert` | `:601-640` | 已在移动中返回 SUCCESS；否则在 `chase_scope` 区间内随机取偏移（小于自身 radius 时返回 FAILURE），`dealWithStatus(Alert, pos)` |
| `executePatrol` | `:642-668` | 移动中返回 RUNNING；以自身为中心在 `patrol_scope_x/z` 内随机取点，`dealWithStatus(Patrol, pos)` |
| `calcPos(pos)` | `:670-725` | 用 `MapRegion` 的四个边界减去自身半径做钳制；Hero 类型额外补一帧位移防止抖动（`:681-683`）。返回 `{x,z}` |
| `moveToDoor` | `:727-739` | 最后一个传送门处于 Active 时，`PathFindingManager:setFindingPos`，进入 Finding 状态 → 行为树 `ActionPathFinding` |
| `onEntityAgentEvent(funcName)` | `:742-749` | C++ 回调入口 |

创建 AiAgent 的位置：`EntityRole.lua:662-667`（`bAi` 为真且不是水晶）、`EntityRole:reloadSkill` 自动战斗主角（`EntityRole.lua:3670-3676`）、竞技场主角（`scene/game/ArenaScene.lua:131-134`，同时 `setAiData`/`setSkillAiIds`）、跨服竞技场（`scene/game/ArenaCrossServerScene.lua:382`）。

tick 条件：`bAi` 为真、`isCanControl()` 为真，且新手引导没有关闭实体 AI（`EntityRole.lua:1103-1109`）；或者 `isAutoFighting()` 为真（`:1111-1113`）。`isAutoFighting` 的判定（`EntityRole.lua:1132-1142`）：主角、Fight 场景、场景开启并解锁自动战斗、`CacheRole:getAutoFight()` 为真、没有暂停。

### B.4 `Entity.xml` 决策流程

```
Selector(0)
├─ Sequence(10)   precondition: eStatus == Alert                         Entity.xml:6-46
│    custom Condition(34): CheckAttack() == BT_FAILURE   ← 自定义中止条件（语义见下）
│    ├─ Sequence(3): ExecuteAttack() → CheckAttackEnd()                   :21-30
│    └─ IfElse(13): if CheckChase()==FAILURE then ExecuteAlert() else ExecuteChase()   :31-45
└─ IfElse(31)     precondition: eStatus == NoAlert                        :47-119
     if CheckHit()==FAILURE (没被打)                                        :55-59
       then IfElse(8): if CheckTarget()==FAILURE (视野内没有敌人)             :60-65
              then Sequence(32): ExecutePatrol → CheckMoveEnd → ExecuteRandAttack → CheckAttackEnd   :66-83
              else Sequence(36): ExecuteFirstAttack → CheckAttackEnd → eStatus=Alert                 :84-98
       else Sequence(17): CheckHitEnd → ExecuteFirstAttack → CheckAttackEnd → eStatus=Alert          :100-118
```

- `<custom>` 中 Condition(34) 的准确语义（每帧检查的中止条件，还是进入序列前的额外条件）取决于 behaviac 版本，**未确认**。从逻辑推断：`CheckAttack` 返回 FAILURE（没有目标）时整个 Alert 分支不执行或中止。
- Alert 状态没有退回 NoAlert 的 Assignment，也就是说怪物一旦被惊醒就一直保持警戒（在 XML 中没有看到复位节点）。
- `ResultOption="BT_INVALID"` 表示使用方法的返回值作为节点状态。

**典型怪物流程**
1. 初始 `eStatus=NoAlert`。没被打且 `target_scope` 内没有敌人时：巡逻（随机点、`patrol_delay_time` 停留）→ 巡逻移动中 `ActionPatrol` 每帧 `checkTarget`，发现敌人就结束移动（`ActionPatrol.lua:54`）→ `CheckMoveEnd` 因目标不是自己返回 FAILURE，中断 Sequence（`AiAgent.lua:293-295`）；否则继续 `ExecuteRandAttack`，释放 Z 槽（非警戒技能）。
2. 发现敌人或被打时：`ExecuteFirstAttack` 释放 X 槽（惊醒技能），等攻击结束后 `eStatus=Alert`。
3. Alert 状态：`ExecuteAttack` 选技能攻击 → 攻击结束 → 如果在 `chase_scope` 外就 `ExecuteChase` 靠近，在区间内就 `ExecuteAlert` 随机游走（`alert_delay_time` 停留）→ 循环。
4. 行为树执行：`dealWithStatus(Attack)` → ROLE 树第 10 分支按 SkillManager 游标执行 AttackRole；`dealWithStatus(Chase/Alert/Patrol, pos)` → 对应的 ActionMove 子类。

**自动战斗 / PVP 机器人**
- 使用同一棵树。区别：`executeAttack` 在 `isMainRole() and CacheRole:getAutoFight()` 时走按钮模拟分支（`AiAgent.lua:413-439,458-508`）；没有敌人时 `moveToDoor`（`:160-162,338-340`）；移动速率用 RUN_RATE、动画用 Run（`ActionMove.lua:16-21`、`ActionChase.lua:38-44`）；机器人移动时不强制面向目标（`ActionChase.lua:32`）。
- PVP 机器人（`getRoleData():getRobot()`）在 AttackRole 第一段时面向目标（`AttackRole.lua:201-208`），技能选择走怪物分支（按优先级和 CD）。机器人的判定在 `scene/FightScene.lua:706`、`scene/NetworkFightScene.lua:326` 附近（细节**未确认**）。
- 竞技场主角：`bAi=true`，并注入 `aiData.skill_ai_ids`/`crazy_skill_ai_ids`（`ArenaScene.lua:131-146`）。

### B.5 技能选择

**怪物 / 机器人**（`executeAttack` 的 else 分支，`AiAgent.lua:509-565`）
1. 当前没有技能时：第一次调用会用 `skill_priority_level_cd[i][1]` 初始化每个槽的 AI 间隔（`:513-518`）。间隔存在 `SkillPool.fAiSkillCastInterval` 中，每帧减去 `delta*1000`（`SkillPool.lua:115-117`）。
2. 收集间隔已归零的索引；全部都在间隔中时返回 SUCCESS（`:520-528`）。
3. 按 `skill_priority_level[i][1]` 降序排序，同优先级按索引升序（`:531-539`）。
4. 依次调用 `presetSkill(string.char(64+i), true)`，即槽 A、B、C…，`auto=true`。成功就 `dealWithStatus(Attack)`（`:542-548`）。
5. 把**所有同优先级**槽的间隔重置为 `skill_priority_level_cd[i][1]`，没有配置时用 `skill_interval`（`:552-557`）。
6. 已有当前技能时（连招）：`presetSkill(skill:getSlot(), true)`，把同槽的下一段作为 next skill（`:558-564`）。
7. 最后，没有当前技能时 `dealWithDirection` 朝向目标（`:567-569`）。

`presetSkill(slot, auto)`（`SkillPool.lua:361-424`）会调 `SkillBase:isAllowCast(auto)`。`auto` 为真时额外经过 `SkillAi:check()`（`SkillBase.lua:473`）：

`SkillAi`（`module/skill/SkillAi.lua`）由 `SkillBase` 按 `skill_ai_ids` 创建（`SkillBase.lua:162`），`update` 递减 `load_cd`/`check_cd`（`:38-42`）。`check()`（`:44-71`）的顺序：`load_cd` 为 0 → `use_count`（-1 表示无限）→ `check_cd` 为 0 → `composition` → 重置 `check_cd` → 概率 `prob`% → 扣减次数。`composition`（`:103-137`）：`composition[1]` 中的条件必须**全部满足**，`composition[2]` 中**至少一个满足**（-1 视为满足）。条件编号：1 `opp_dis_x`、2 `opp_dis_z`（带一帧位移容差）、3 `opp_status`、4 `opp_combo`（对手连携索引大于 1）、5 `opp_skill_id`、6 `self_hp`% 区间、7 `self_status`（`:104-112`）。状态编号：1 Hit、2 HitUp、3 HitDown、4 HitFloor、5 Wake、6 Attack（`:4-11`）。

**自动战斗主角**（`AiAgent.lua:458-508`）：没有当前技能时按固定顺序 `I,J,K,G,H,B,C,D,1+…12+,A`（注释：奥义 > BUFF 技能 > 技能 > 搓招 > 普攻，`:460-464`）找第一个 `isAllowCast(true)` 为真且槽未禁用的技能，然后 `dealButtonEvent(Slot2Event[slot], nil, true)` 模拟按键。有当前技能时，找同槽下一个连携技能并模拟按键。受击时尝试挣脱槽 `L`（`:417-439`）。神器技能和怒气 AI 另行处理（`EntityRole.lua:1039-1046,1060-1068`）。

### B.6 目标选择

- 候选：`EntityManager:findTargetForAI(camp)`（`module/entity/EntityManager.lua:1848-1860`），条件为存活、`getLogicEnable()`，并且阵营组 `EntityCamp2CampGroup` 不同。调用方还会剔除 `getHit()` 为真的（不可命中的）角色。
- 视野：`checkTarget` 使用 `target_scope_x/z` 有符号区间（`AiAgent.lua:311-315`）。
- 保持和切换：没有目标或目标死亡时随机重选（`:144-157`）；每 10 秒按伤害统计换仇恨（`:89-93,114-130`）；嘲讽 buff 强制目标（`:77-87,138-140`）；伙伴替换时迁移目标（`:99-103`）。
- "目标是自己"（`setTargetTag(self:getTag())`）表示没有目标（`:163,304,341`）。

### B.7 移动

AI 只计算目标点 → `dealWithStatus(Patrol|Chase|Alert, {x,z})`，写入 `entityParams.move_pos`（写入位置**未确认**，由 `ActionMove.lua:50` 读取推断）→ 行为树 ActionMove 子类通过 `dealWithControlParam({quadrant, angle, ratio=0})` 像摇杆一样驱动移动（`ActionMove.lua:63-66`）。到达判定是单帧位移距离（`:53`）；目标点不在 `MapRegion` 内时直接视为完成（`ActionPatrol.lua:8-12`）。

### B.8 计时器汇总

| 计时 | 来源 | 位置 |
|---|---|---|
| 换目标 10 s | `Const.CHANGE_TARGET_TIME` | `AiAgent.lua:89-93`、`imports/Const.lua:634` |
| 巡逻/追击/警戒停留 | `entity_ai.patrol/chase/alert_delay_time[min,max]` 随机（毫秒） | `ActionPatrol.lua:17`、`ActionChase.lua:18`、`ActionAlert.lua:20` |
| 槽位 AI 间隔 | `skill_priority_level_cd` / `skill_interval` | `AiAgent.lua:513-557`、`SkillPool.lua:115-124` |
| 单技能 AI | `skill_ai.load_cd`、`check_cd`、`use_count`、`prob` | `SkillAi.lua:21-71` |
| 随机数 | `AEUtil:GRandomF/GRandomN`（同步种子，带 SYNCSEEDLog） | 各处 |

### B.9 `entity_ai` 表

加载：`db/DBEntity.lua:3`（`tEntityAi = loadlua "entity_ai"`），查询 `DBEntity:getAiData(key)`（`:44`）。取用：`EntityRole:getAIData`（`module/entity/EntityRole.lua:836-873`）。先取 `roleData:getAIId()`；为 0 时从 `entity_role.ai_id` 列表中按 `getAiDifficulty()` 选择，越界时取最后一个；伙伴改用 `getPartnerAiId()`。注释说明即使不受 AI 控制也必须有 AI 数据（`:869`）。

字段（从 `imports/table/entity_ai.lua` 中提取）：`id`、`target_scope_x/z`、`patrol_scope_x/z`、`patrol_delay_time`、`chase_scope_x/z`、`chase_delay_time`、`alert_delay_time`、`skill_interval`、`skill_priority_level`、`skill_priority_level_cd`、`skill_ids`、`skill_ai_ids`、`crazy_skill_ids`、`crazy_skill_ai_ids`、`joystick_skill_ids`、`other_skill_ids`。技能 id 字段供 SkillPool 构造技能槽（`SkillPool.lua:60-70`）。表数据经过 `HACKER_DATA_INIT` 加密包装（`entity_ai.lua:3`）。`DBSkill:getAiData` 已标记为 DEPRECATED（`db/DBSkill.lua:23-24`）。

---

## C. `module/fsm`

- `SimpleFsm`（`module/fsm/SimpleFsm.lua:3-28`）：`register/unregister/getState/transfer(tag,...)/update(dt)`，`transfer` 先调旧状态 `onExit`，再调新状态 `onEnter(...)`。
- `IState`（`module/fsm/IState.lua:3-13`）：属性 `eTag`，钩子 `onLoad/onEnter/onUpdate/onExit/onUnload`。
- 加载于 `module/_init.lua:5-6`。**只用于 UI**：`ui/ViewAbstructClass.lua:11-28`（ViewPage/ViewMenuFsm）、`ui/view/UiFashion/UiFashionApparel.lua:26`、`ui/view/UiFashion/StateFashion.lua:8`。
- **与战斗 BT/AI 没有交互**。战斗中的"状态机"其实是实体状态位加 ROLE 行为树 Selector 优先级（见 A.6）。

---

## D. 索引表

| 类 / 函数 | path:line | 角色 |
|---|---|---|
| `EnumBTStatus` | module/behaviortree/BehaviorTree.lua:2 | BT 状态枚举 |
| `BehaviorTree:update` | module/behaviortree/BehaviorTree.lua:32 | 根节点 tick，结束时只报警 |
| `BehaviorTree:findChild` | module/behaviortree/BehaviorTree.lua:86 | 按 0 起索引取根的子节点 |
| `BehaviorManager:createBehaviorTree` | module/behaviortree/BehaviorManager.lua:74 | 从表构建树 |
| `BehaviorManager:resolveBehaviorTree` | module/behaviortree/BehaviorManager.lua:45 | 递归建节点，也用于技能注入 |
| `ActionBase:onScriptHandler` | module/behaviortree/actions/ActionBase.lua:132 | C++→Lua 动作回调 |
| `ActionBase:enter/exit` | module/behaviortree/actions/ActionBase.lua:82/93 | 发 BFEvent 行为状态事件 |
| `ConditionBase:onScriptHandler` | module/behaviortree/conditions/ConditionBase.lua:39 | C++→Lua 条件回调 |
| `BEHAVIOR.ROLE` | imports/ConstBehaviorTree.lua:264 | 角色树（生效） |
| `BEHAVIOR.ROLE_ATTACK_NODE_INDEX` | imports/ConstBehaviorTree.lua:262 | 攻击节点 idx=9 |
| `BEHAVIOR.EFFECT` | imports/ConstBehaviorTree.lua:519 | 特效树（覆盖 :241） |
| `BEHAVIOR.PORTAL/OBSTACLE/NPC/GOODS/PET/CITY_ROLE` | imports/ConstBehaviorTree.lua:371/424/451/469/496/532 | 其它实体树 |
| `BEHAVIOR.CHARACTER/MONSTER` | imports/ConstBehaviorTree.lua:64/157 | 【死代码】 |
| 新技能系统 ROLE | imports/ConstBehaviorTree.lua:551 | 【死代码】（`Const.lua:777` 值为 false） |
| `EntityRole` 建树 + AiAgent | module/entity/EntityRole.lua:661 | ROLE 树与 AI 创建 |
| `EntityRole:unload` | module/entity/EntityRole.lua:926 | 清空攻击子树 |
| `EntityRole:getAIData` | module/entity/EntityRole.lua:836 | 选 entity_ai 行 |
| `EntityRole:update` AI tick | module/entity/EntityRole.lua:1103 | 调 `pAgent:update` |
| `EntityRole:isAutoFighting` | module/entity/EntityRole.lua:1132 | 自动战斗判定 |
| `EntityRole:updateGodWeaponAi` | module/entity/EntityRole.lua:1039 | 神器 SkillAi |
| `EntityBase:update` BT tick | module/entity/EntityBase.lua:183 | 调 `pBehaviorTree:update` |
| `EntityEffect:dealWithActionTree` | module/entity/EntityEffect.lua:332 | 特效动作序列生成 |
| `SkillPool:loadSkill` 注入 | module/skill/SkillPool.lua:85 | 挂技能子树 |
| `SkillPool:createAttackSlotNode` | module/skill/SkillPool.lua:672 | 槽位 Selector |
| `SkillPool:createAttackSkillNode` | module/skill/SkillPool.lua:770 | 步骤 Selector + SkillBase |
| `SkillPool:createAttackPipeNode` | module/skill/SkillPool.lua:826 | 释放次数通道 |
| `SkillPool:createAttackReleaseTypeNode` | module/skill/SkillPool.lua:862 | 抬起/按下分支 |
| `SkillPool:createAttackTowardNode` | module/skill/SkillPool.lua:902 | 方向序列 → AttackRole |
| `SkillPool:presetSkill` | module/skill/SkillPool.lua:361 | AI/按键预设技能 |
| `SkillBase:isAllowCast` | module/skill/SkillBase.lua:480 | 释放判定（auto 时走 SkillAi） |
| `ConditionRoleAttack` | module/behaviortree/conditions/ConditionRoleAttack.lua:2 | 攻击分支守卫 |
| `ConditionAttackSlot/SkillStep/Pipe/VectorIndex/Press/Release` | module/behaviortree/conditions/*.lua:2 | 技能子树守卫 |
| `ActionMove` | module/behaviortree/actions/ActionMove.lua:3 | AI 移动基类 |
| `ActionCanBreakBase` | module/behaviortree/actions/ActionCanBreakBase.lua:2 | 受击可挣脱基类 |
| `ActionAttack` | module/behaviortree/actions/ActionAttack.lua:5 | 攻击动作基类 |
| `AttackRole:dealWithInterrupt` | module/behaviortree/actions/AttackRole.lua:390 | 连招取消窗口 |
| `AttackRole:dealWithExtraInterrupt` | module/behaviortree/actions/AttackRole.lua:440 | 超级取消窗口 |
| `AttackRole:dealWithEffect` | module/behaviortree/actions/AttackRole.lua:487 | 按帧生成特效 |
| `AttackEffect:dealWithSummon` | module/behaviortree/actions/AttackEffect.lua:171 | 特效召唤 |
| `ActionPatrol:execute` | module/behaviortree/actions/ActionPatrol.lua:52 | BT→AI 反向调用 checkTarget |
| `AIStatus` | module/ai/AiAgent.lua:22 | AI 返回值 |
| `AiAgent:update` | module/ai/AiAgent.lua:65 | behaviac tick、嘲讽、仇恨计时 |
| `AiAgent:onEntityAgentEvent` | module/ai/AiAgent.lua:742 | behaviac 方法分派 |
| `AiAgent:checkAttack/checkTarget/checkChase/checkHit/checkHitEnd/checkMoveEnd/checkAttackEnd` | module/ai/AiAgent.lua:133/299/215/180/188/288/171 | 条件方法 |
| `AiAgent:executeAttack/FirstAttack/RandAttack/Chase/Alert/Patrol` | module/ai/AiAgent.lua:401/365/325/574/601/642 | 执行方法 |
| `AiAgent:calcPos` / `moveToDoor` / `changeTarget` | module/ai/AiAgent.lua:670/727/114 | 辅助 |
| `EntityManager:findTargetForAI` | module/entity/EntityManager.lua:1848 | 敌人候选 |
| `SkillAi:check` / `checkComposition` | module/skill/SkillAi.lua:44/103 | 单技能 AI 门槛 |
| `Entity.xml` | imports/behaviac_exported/Entity.xml:4 | 唯一 AI 树 |
| `Closers.meta.xml` | imports/behaviac_exported/meta/Closers.meta.xml:4 | EntityAgent 元数据 |
| `DBEntity:getAiData` | db/DBEntity.lua:44 | entity_ai 查询 |
| `SimpleFsm` / `IState` | module/fsm/SimpleFsm.lua:3 / module/fsm/IState.lua:3 | 仅 UI 用 |
