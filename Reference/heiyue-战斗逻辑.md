# heiyue 战斗运行时逻辑参考

本文说明 heiyue（Cocos2d-x Lua）战斗在**运行时**怎么跑：一帧里各对象按什么顺序更新，技能从按键到扣血经过哪些步骤，受击状态怎么切换，Buff 怎么结算，帧同步怎么驱动。目标是让移植到 C++ 的工程师不用再读 Lua。

相关文档（本文不重复其内容）：
- [heiyue-结构.md](heiyue-结构.md)：目录、模块加载、**§4 帧循环**、§5 战斗对象图、§7 文件索引。
- [heiyue-战斗配置.md](heiyue-战斗配置.md)：各表字段。skill_attack / skill_hit / action_attack / buff_base / entity_* / map_room，以及 §7 扩展属性、§8 槽位。
- [heiyue-AI与行为树.md](heiyue-AI与行为树.md)：AEBT 节点、**§A.6 ROLE 树分支顺序**、behaviac AI。

所有路径都相对 `heiyue/src/`。Lua 源文件实际是 UTF-8 编码，用 `Get-Content -Encoding utf8` 读取即可；若按 GBK 读反而会出现乱码。时间单位：`delta` 以秒为单位（逻辑帧 `LOGIC_DT = 1/30`，见 `scene/GameManager.lua:10`），大多数计时器写成 `delta * 1000`，按**毫秒**累计（`ENCRYPT_CONST._1000`）。

---

## 0. 怎么查

| 想查什么 | 先看 |
|---|---|
| 一帧里谁先更新 | 结构.md §4，再看本文 §1 |
| 技能为什么没放出来 | `SkillPool:dealWithButton`（`module/skill/SkillPool.lua:268`），再看 `SkillBase:isAllowCastInternal`（`module/skill/SkillBase.lua:424`） |
| 动作第 N 帧出特效、震屏、定身 | `AttackRole:execute`（`module/behaviortree/actions/AttackRole.lua:349`） |
| 为什么没打中 | `EntityEffect:onCollisionEvent`（`module/entity/EntityEffect.lua:348`）→ `dealWithHitX`（`:721`）→ `EntityRole:dealWithBeHitBefore`（`module/entity/EntityRole.lua:3039`） |
| 伤害数值 | `SkillHurt:calculateDamage`（`module/skill/SkillHurt.lua:108`） |
| 受击以后怎么倒地、起身 | `module/behaviortree/actions/ActionHit*.lua`、`ActionGetUp.lua`、`ActionWake.lua` |
| Buff 的生命周期 | `BuffPool:addBuff`（`module/buff/BuffPool.lua:380`），再看 `BuffBase:update`（`module/buff/BuffBase.lua:217`） |
| 联机 | `module/sync/SyncManager.lua` |

命名约定：
- **slot** 是字符串槽位，例如 `"A"` 普攻、`"B"/"C"/"D"` 技能、`"1+"` 搓招、`"A+"` 曝气版本（`SkillPool.lua:57-81`）。
- **skillBase** 指当前正在施放或已预设的 `SkillBase`（`EntityRole.pSkillBase`）。

---

## 1. 一帧时序

全局调度链见结构.md §4，这里只写三点要紧的：
- 逻辑帧 30Hz。
- 慢放时，`MapManager:update(delta*SlowScale)` 用缩放过的 delta 驱动整张地图。
- **碰撞检测 `AECollision:update` 排在所有实体更新之后**（`module/map/MapEntity.lua:84`）。所以命中回调（`dealWithHitX`）发生在本帧所有实体逻辑跑完以后，不在某个实体的 update 里。

### 1.1 EntityManager:update（`module/entity/EntityManager.lua:229-436`）

按组顺序遍历 `LogicList`：Role → Effect → Npc → Model → Obstacle → CityRole → Pet → Goods → Portal。对每个组：
1. 如果 `not getSuspend() and not getStop()`，调用 `x:update(delta)`。
2. 如果 `getDestroy()`：
   - Role：清掉控制实体引用、从 `LogicMap` 删除、`delete`、移除所属 Pet（`:239-252`）。
   - Effect：如果是预加载对象，回收到池里（`recoverPreloadEffect`，`:272-279`）；否则 `delete`。
3. 如果 Role 的 `getBufferEnable()` 为真，把它挪到 `BufferList`（跨房间保留、临时下场的角色），`:253-258`。
4. 最后扫一遍 `BufferList`：`getLogicEnable()` 为真的角色放回 `LogicList`，已销毁的删除（`:416-435`）。

列表采用原地遍历：删除当前元素时下标不自增，只把上界 `j` 减 1。上界 `j = #LogicList` 在循环开始前就取好了，所以本帧新加入（追加到表尾）的实体**不会**在本帧更新，要到下一帧才更新。

### 1.2 EntityRole:update（`module/entity/EntityRole.lua:1049-1130`）

每个角色每帧按下面的顺序执行：

| # | 步骤 | 行 | 说明 |
|---|---|---|---|
| 1 | `pSkillManager:update` | :1053 | 各 SkillBase 的 CD 与 SkillAi 计时，以及 AI 施法间隔（§6） |
| 2 | `updateGodWeaponSkill` / `updateGodWeaponAi` / `updateAngerAi` | :1057-1070 | 神器技能 CD；自动战斗或 AI 时自动释放神器和怒气技能 |
| 3 | `BuffPool:update` | :1073 | 仅当 `getLogicEnable()` 为真（§11） |
| 4 | `SpecialAbilityPool:update` | :1077 | 特殊能力 |
| 5 | `pHurtNum` / `pCombo:update` | :1080-1086 | 伤害数字和连击计时 |
| 6 | `fSkillInterval -= DT` | :1088 | 旧系统字段 |
| 7 | MP（TP）自然回复 | :1090-1092 | `1000*delta*(MP_INCREASE_BASIC_VALUE + MP_INCREASE_VALUE[职业])*MPRecoveryScale`，基础值为 0.005（`imports/Const.lua:276`） |
| 8 | `dealWithSummon` | :2446 | 召唤物寿命到期后 `setHp(0)` 并进入 Death |
| 9 | `dealWithFreeze` / `dealWithStatic` | :2436/:2441 | `fFreezeTime`、`fStaticTime` 按毫秒递减，得到 `bFreeze` / `bStatic` |
| 10 | `dealWithCrazy` | :2464 | 曝气期间持续扣 EP，EP 为 0 时退出曝气并触发 `AFTER_CRAZY` |
| 11 | `dealWithRage` | :2520 | 怪物狂暴倒计时，结束时加 `time_rage[3]` 中的 buff |
| 12 | `dealWithAngerFreezeTime` / `dealHitProtectUpdate` | :3838/:4051 | 怒气冻结；PVP 受击保护 |
| 13 | `pAgent:update` | :1103-1113 | AI 实体（`bAi` 且可控），或自动战斗中的主角 |
| 14 | `updateBodyShake` / `movedCheck` / `hpChangeCheck` / `epChangeCheck` / `actionStatusCheck` | :1116-1120 | 表现层检测和状态计时 |
| 15 | **`EntityBase.update`** | :1127 | 见下 |
| 16 | `verifyMd5` | :1129 | 反作弊 |

`EntityBase:update`（`module/entity/EntityBase.lua:167-190`）：
1. 如果 `bFreeze or bStatic`，**直接 return**，于是行为树、位移、碰撞体更新全部暂停（顿帧和定身的实现就是这一步）。步骤 1–14 照常运行，所以冻结期间 Buff 和 CD 仍在走。
2. 依次取出 `tControlEvent` 队列，调用 `dealWithEvent`。联机时输入从这里进入；单机时输入直接调用，见 §5.1。
3. `pBehaviorTree:update(delta)`：执行 ROLE 树（AI 文档 §A.6）。
4. 按添加顺序遍历组件的 `update`。角色的组件依次为 Displacement → Avatar → Decorator → Collision → Title（添加顺序见 `EntityRole.lua:620-640`）。

### 1.3 EntityEffect:update（`module/entity/EntityEffect.lua:274-302`）

1. 如果本帧之前有命中（`iHitCount ~= 0`），把 `iHitCount` 清零，并把 `fHitInterval` 重置为 `hit_interval`。这就是多段命中的间隔（§8.4）。
2. `EntityBase.update`：执行 EFFECT 行为树和各组件。
3. `dealWithFreeze`：特效有自己的 `fFreezeTime`，但这一步排在 `EntityBase.update` **之后**，因此冻结从下一帧才开始生效。
4. 如果处于冻结，return；否则依次执行：
   - `dealWithHitCondition`：按命中次数销毁特效。
   - `dealWithFollow`：跟随释放者。
   - 若已销毁，调用 `dealWithNextEffect`。
   - `fHitInterval` 递减。

---

## 2. 进关与刷怪

### 2.1 场景层级

`SceneBase` → `GameScene`（`scene/GameScene.lua`）→ `FightScene`（`scene/FightScene.lua`）→ 各玩法子类，例如：
- `scene/game/PlotScene.lua`（剧情和主线）
- `DimensionDoorScene`
- `PVPScene`
- `ArenaScene`
- `NetworkFightScene`（`scene/NetworkFightScene.lua`）

### 2.2 进场流程

1. `FightScene:processData`（`scene/FightScene.lua:194`）：`DBMap:getRoomData(iRoomId)` 取得 `tRoomData`，并得到 `room_type`、`battle_rule_type`、`battle_rule_param`。
2. `GameScene:init` 调用 `loadMap`（`scene/GameScene.lua:157,625`）。`loadMap` 内部调用 `handleFormEntityData` / `handleLoadEntity`（`:682,940`），后者先 `pauseAllRole`，再依次加载 Role、NPC、Obstacle、Goods、Portal。
3. `FightScene:handleFormMonsterData`（`:490-532`）为 `map_room.monster_ids` 中每个大于 0 的 id 生成 configData，内容包括：
   - AI 难度：`getRoomAiDiffficulty`
   - 掉落：`monster_drop_goods`
   - 血条：`monster_hp_bar`
   - 类型等级：`getRoomMonsterLevels`
   - 坐标：`monster_pos_x/z`
   - 朝向：`monster_vector_x`
4. `FightScene:handleLoadMonster`（`:566-604`）对每只怪执行：
   - `new EntityRoleData`，设置 AI 难度、房间等级和血条增幅。
   - `EntityManager:addRole(id, nil, data, true)`。第三个参数 `ai=true`，表示怪物都挂 AiAgent。
   - 按 `typeLevel[roleType]` 调用 `setLevel`。
   - `setEntityPositionInfoAndEnter`（`GameScene.lua:950`）：设置 vector、toward、position、origin，再调用 `load()`（加载属性和技能，见 §3），最后 `enter()`。
   - 若是 Boss，置 `bHaveBoss`。
5. `GameScene:enter`（`:172`）：镜头对准控制角色，启动 StoryManager，`setExpectRoomState(Room_Init)`，最后调用 `EntityManager:update(0)`。
6. `FightScene:enter`（`:288`）：`processRoomBuff`（房间 `actor_buff_ids`，`:1424`）。

### 2.3 房间状态机

状态枚举在 `global/GlobalBusinessEnum.lua:152-190`，状态名表在 `:191`。

- **推进方式**：`setExpectRoomState` 把目标状态加入队列（`scene/GameScene.lua:245`）。`updateCheckRoom`（`:286`）等待 `ROOM_STATE_INTERNAL` 毫秒，并询问 StoryManager 是否要插剧情；之后才切换状态，调用 `RoomStateFuncName[state]`。同一个状态只会进入一次（`RecordCache`）。
- **FightScene 各状态的函数**（`:1003-1096`）：
  ```
  Room_Init → Room_Ready(resumeAllRole, 开放操作) → Room_Enter → Room_Ready_Spine(is_warning: WARNING / WARNING_BOSS 动画, Boss 动画期间 pause)
  → Room_Tip(open_tips / scene_name) → Room_Process(战斗中)
  → Room_Fight_Victory / Room_Fight_Failure → Room_Fight_Balance(gameVictory/gameFailure) → Room_Fight_Finish → Room_Fight_End(普通房: openPortal + GoGoGo + 自动传送) → Room_End
  ```
- **每帧检查**：`FightScene:update`（`:336`）在 `GameScene.update` 之后依次执行下面几项。

| 检查 | 行 | 条件与结果 |
|---|---|---|
| `updateCheckKO` | :813 | 非普通房、处于 Process、有 Boss。`checkKO`（:1297）在所有 Boss 都死亡时成立，随后 `executiveKO`（:1473）：`CameraManager:startSlow()` 进入慢放，己方无敌，清除剩余敌人 |
| `updateCheckRoleDeath` | :847 | 控制角色处于 DeathStatus 且死亡动画已结束。能复活就 `enterReviveState`，否则 `gameFailure` |
| `updateCheckResult` | :879 | 处于 Process，且不在复活中，也不在 KO 慢放中。`checkPassRoom` 成立 → Victory；`checkTimeOut` 成立 → Failure |
| `updateCheckTime` | :946 | 累加 `fGameTime` 和自动传送计时 |

- **清场判定**：`checkWipeOutEnemys`（`:1250`）要求不存在 `isEnemy()` 且 `roleType ∈ [2,4] ∪ [7,9]` 的角色（Monster、Elite、Boss，以及三种矿）。注意这里看的是**角色是否存在**，不是是否死亡：死亡的角色要等 ActionDeath 销毁以后才算清掉。

### 2.4 刷怪波次（battle_rule）

`EnumBattleRule` 的取值：None=0、Clear=1、Defense=2、Survive=3、Chasm=4。

- **Clear**：限时为 `map_stage.open_time`，清场即胜利（`scene/game/PlotScene.lua:81,133-139,435`）。
- **Defense（波次）**：
  - `StageHelper.createRoomModel`（`helper/StageHelper.lua:124-146`）把 `battle_rule_param` 当作**房间 id 列表**。每个房间的 `monster_ids` 构成一波（`monsterTurnList[turn]`），index 接在主房间怪物之后顺延。
  - 每次清场时，`PlotScene:checkPassRoom`（`:432-451`）检查 `iCurTurn >= iMaxTurn`：成立则胜利；不成立则 `pMainFightView:startCounter()` 开始 UI 倒计时。
  - 倒计时结束时，UI 调用 `startHandleTurnMonster`（`ui/view/UiFight/UiFightTypePlot.lua:492` → `PlotScene.lua:356`），执行 `iCurTurn++`，然后重新 `handleFormMonsterData` / `handleLoadMonster`。
  - 防守关不做 KO 判定（`:410-414`）。
- **Survive**：`fLimitTime = battle_rule_param[1]`。`fGameTime >= fLimitTime` 或清场即胜利（`:90,448`）。
- 房间是否已探索、机关（Machine）是否已被释放，由 `ViewFightManager` 记录。已探索的房间不再刷普通怪（`PlotScene.lua:302,313-315`）。

### 2.5 过房间

普通房到达 Fight_End 后开门。`portalCollisionCallBack` 置位 `bPortalTransferPermit`，然后 `GameScene:executiveTransfer`（`:429`）按 `PortalTransferType` 处理：Room 类型调用 `SceneManager:changeMap()`，Stage 或 Camp 类型向服务器发请求。`is_pass_room` 标记的角色会通过 BufferList 保留到下一个房间（`scene/FightScene.lua:759`）。

---

## 3. 战斗对象图

### 3.1 实体类型

| 类 | 文件 | 说明 |
|---|---|---|
| EntityBase | `module/entity/EntityBase.lua` | 位置、速度、朝向、组件、控制事件队列；freeze 和 static 的短路判断 |
| EntityRole | `module/entity/EntityRole.lua` | 玩家、怪物、召唤物、机关、水晶（`role_type`，配置文档 §4.1） |
| EntityEffect | `module/entity/EntityEffect.lua` | 技能特效，同时也是**攻击判定载体**：有 `hit_id` 时才会加碰撞组件 |
| EntityObstacle / EntityGoods / EntityPortal / EntityPet / EntityNpc | 同目录 | 障碍、掉落物、传送门、宠物、NPC |
| EntityAttribute | `module/entity/EntityAttribute.lua` | 属性表，由 EntityManager 按 tag 管理。**特效共享其所属角色的属性对象**（`EntityEffect.lua:118`，引用计数） |
| EntityExtraState | `module/entity/EntityExtraState.lua` | 8 种额外状态开关 |

### 3.2 EntityRole:init 的组装顺序（`EntityRole.lua:536-727`）

1. `EntityBase.init`，然后 `DBEntity:getRoleData(roleId)` 读出 `tEntityData`。
2. `tAiData = originClone(getAIData(entityData, data))`：按 AI 难度从 `entity_ai` 中选行（`:836`）。
3. 初始状态：`eEntityStatus = Idle`；阵营 `eCamp = camp or monster_camps`；敌对阵营 `eHostileCamp = EntityHostileCamp[camp]`。
4. 初始化 `iHitCount`、`fFreezeTime`、`fStaticTime`、`fSummonTime=-1`、`fRigidity = entityData.rigidity`（浮空值）以及 `bCrazy=false`。
5. `time_rage` 为狂暴设置：`fTimeRage = [2][1]`，`tRageBuff = [3]`。
6. 技能组表 `skillData[Normal/Crazy/JoyStick/JoyStick_Crazy/Special]` 来自 `entity_ai` 的 `skill_ids`、`crazy_skill_ids`、`joystick_skill_ids`、`other_skill_ids`。玩家的奥义（SUA–SUC）另外追加到 Normal 和 Crazy 组，并补上 AI id 和优先级 100（`:600-613`）。
7. `setSkillIds(skillData, true)`（`:3376`）：把旧的二维结构转换成 `[slot][index][mode] = {skill_id}`。
8. 组件依次添加：`ComponentDisplacement`、`ComponentAvatar`（英雄用 `AvatarMainRole`）、`ComponentDecorator`、`ComponentCollision`、`ComponentTitle`。
9. `pAttribute = EntityManager:addAttribute(tag)`。
10. 依次创建 `SkillPool`、`BuffPool`、`SpecialAbilityPool`、`SkillHurt`。
11. `pEntityExtraState = EntityManager:addExtraState(tag)`；为每个神器技能 AI 创建 `SkillAi`。
12. `pBehaviorTree = BehaviorManager:createBehaviorTree(self, BEHAVIOR.ROLE)`；`bAi` 为真且不是水晶时创建 `AiAgent`。
13. 其余运行时字段：`pSkillBase=nil`、`bAllowInterrupt=true`、`bAllowExtraInterrupt=false`，保护 buff 的 id（155 浮空保护、154 白框、173 受击保护），以及怒气相关字段。

`EntityRole:load(hp, ep)`（`:883`）负责加载属性（`loadAttribute`，`:816`，公式见配置文档 §4.4）和技能（`SkillPool:loadSkill`，§6.1），并调用 `BuffPool:loadBuffs`（`module/buff/BuffPool.lua:152`：自带、芯片、额外 buff 等缓存池）。`enter`（`:785`）注册碰撞监听（`:790`）。

### 3.3 属性

`EntityAttribute` 有三层：
- `tBasicAttribute`：基础值。
- `tOverlayAttribute`：Buff 叠加值。
- `tExtendAttribute`：100–115 号扩展属性（`EntityAttribute.lua:4-23`，含义见配置文档 §7）。

取值规则：
- `getATK = basic + overlay`（`:260`），DEF、MATK、MDEF 相同。
- `getMaxHp = basic HP + ADD_MAXHP`（`:243`）。
- `getMaxMp` 返回常量 `MAX_MP_VALUE`。

HP、MP、EP 存在角色上（`setHp` 等，`EntityRole.lua:1258-1310`），不在属性表里。

### 3.4 额外状态（`EntityExtraState.lua:3-12`）

| 状态 | 作用 |
|---|---|
| Durance 禁锢 | `isCanMove=false` |
| Palsy 麻痹 | `isCanMove=false` |
| Stun 眩晕 | `isCanMove=false`、`isCanControl=false`，技能被禁 |
| Silence 沉默 | 技能被禁 |
| SuperArmor 霸体 | 受击时不切换状态，§10.3 |
| Invincible 无敌 | 可被闪避技能躲开，§8.3 |
| Stealth 隐匿 | — |
| Frozen 冰冻 | `isCanMove=false`、`isCanControl=false` |

- `isCanMove` = 非 Durance、Palsy、Stun、Frozen（`:134`）。
- `isCanControl` = 非 Stun、Frozen（`:145`）。
- 只有 `module/buff/xstatus/Buff*.lua` 会写这些状态。例如 SuperArmor 和 Invincible 用引用计数 `addSuperArmorRef` / `addInvincibleRef`（`BuffPool.lua:706-718`）。

---

## 4. 角色状态

`eEntityStatus` 是**位掩码**（`EntityRoleStatus`）。`isXxxStatus()` 用 `AEUtil:AND` 判断某一位（`EntityRole.lua:1770-1950`）。

状态组合：
- `isTobeHitStatus` = GetUp | HitFloor | HitDown | HitUp | HitSwitch | Hit（`:1842`）。
- `isCanBreakStatus` 与上面相同，但不含 GetUp（`:1851`）。挣脱技能只能在这些状态下使用。

写状态的入口有两个：
- **`dealWithStatus(status, ...)`**（`:2055-2123`）：外部请求切换状态。
  - 已处于 Death：直接返回 false。
  - `Hit`：先把状态重置为 `Idle|Hit`，写入 `tEntityParams.hit_id` 和 `hit_counts=1`，速度清零，并 `hitProtectInit`。
  - `Attack`：OR 上 Attack 位。
  - `Death`：状态直接设为 Death，写入 `death_displacement_id`。
  - `Patrol` / `Chase` / `Alert` / `Walk` / `Run`：只有当前**恰好为 Idle** 时才 OR 上，否则返回 false。所以攻击中和受击中都不能移动。
  - `Idle`：只有处于移动状态且不在攻击中时，才恢复为 Idle。
- **`mixStatus(status)`**（`EntityBase.lua:795`）：行为树叶子之间直接 OR 上后续状态，例如 HitUp → HitDown → HitFloor → GetUp → Wake。
- `abortStatus` 用 XOR 清掉一位（`:789`）。

ROLE 树的每个分支挂着 `ConditionXxxStatus` 条件，按优先级选出第一个满足条件的分支，大致顺序是 Death > 各受击 > Attack > 移动 > Idle。具体顺序以 AI 文档 §A.6 为准。某个状态位被清掉后，下一帧就会落到其它分支。移植时注意：
- 受击叶子**不会**清掉 Hit 位本身，它们用 `mixStatus` 追加下一个阶段的位，由 ROLE 树的优先级决定走哪个分支。旧位何时被清除**未确认**，推测在 ROLE 树的条件或 decorator 的 exit 中处理，详见 AI 文档。
- 进入 Attack 分支的前提是 `pSkillBase ~= nil`，并且 slot 条件匹配（§6.2）。

---

## 5. 施法通路

### 5.1 玩家输入 → 事件

```
触摸/键盘 → ControlManager (module/touch/ControlManager.lua)
  update(:419)            每逻辑帧: 摇杆按住 → CTR_RUN/CTR_WALK；普攻键按住且 fAttackInterval==0 → CTR_ATKA（按住连打）
  onControlEvent(:804)    → dealWithJoyStick(:711) 搓招识别 → SyncManager:checkSwallowControl(:830)
                            联机: 收集到上传队列并吞掉 (SyncManager.lua:490-545)
                            单机: funcControlListener = EntityManager:onControlEvent (scene/SceneManagerExternal.lua:46)
  EntityManager:onControlEvent(EntityManager.lua:2081) → 暂停自动战斗 1 秒 → controlEntity:dealWithEvent(event, param)
```

**搓招识别**（`dealWithJoyStick`，`ControlManager.lua:711-802`）：
- 当摇杆 `ratio ≥ 0.5` 时，把角度量化为 4 个方向，`index = floor((floor(angle/45)+1)/2)%4+1`。
- 方向变化时，逐条推进每个指令序列 `KeyCodeJoy[i]` 的匹配进度 `tJoyStickTouch[i]`。方向不符的序列进度清零。每匹配一步就把 `fJoyStickInterval` 重置为 `JOYSTICK_WAIT_TIME`，超时后全部清零（`:428-431`）。
- 按下普攻键（`CTR_ATKA`）时，若某条序列已完整匹配，事件替换为 `KeyCodeJoyAttack[i]`（`CTR_JOYn`），参数使用匹配完成时记录的摇杆参数。
- 按下 B/C/D 时，若有完整匹配，事件替换为 `CTR_JOYB/C/D`（搓改，slot 为 `"B_2"` 等）。

**`EntityRole:dealWithEvent`**（`EntityRole.lua:2131-2187`）：
1. 清除寻路。`not isCanControl()` 时返回。
2. 若存在可控特效（`pControlEffect`，`entity_effect.control=1`），事件交给特效处理，神器键除外。
3. 被传送门推开（Jostled）时返回。
4. 神器键调用 `dealWithGodWeaponSkill`，`CTR_ATKQ` 调用 `dealWithAnger`。
5. 其余事件先写入 `tControlParam = param`。
   - `EventRole2Status[event] == Attack` 时，调用 `dealButtonEvent`（`:2359`）：
     - 死亡时返回。
     - PVP 中禁用奥义 I/J/K。
     - 怒气变身收尾期间返回。
     - 调用 `pSkillManager:dealWithButton(event, param, bUseAi)`。成功后 `dealWithStatus(Attack)`。
   - `Run` 类事件调用 `SkillPool:dealWithInterruptExtraBehavior(Run)`（`SkillPool.lua:172`，设置技能的 `bNextRunStatus`），再 `dealWithStatus(Run)`。

### 5.2 事件 → slot

- `Attack2Param`（`EntityManager.lua:69-99`）是 event 到 slot 字符串的映射：ATKA 到 `"A"`，ATKB 到 `"B"`，ATKF 到 `"F"`（闪避），JOY1–12 到 `"1+"`–`"12+"`，JOYB 到 `"B_2"`，I/J/K 为奥义，L 为挣脱，M/N/O 为搓招按键版。
- 键盘映射见配置文档 §8。

### 5.3 SkillPool:dealWithButton（`SkillPool.lua:268-353`）

1. **抬起事件**（`press_type == pressUp`）：给下一个技能或当前技能 `setIsUpTouch(true)`，用于蓄力技能，然后返回。
2. **普攻转冲刺**：`slot=="A"`，同时 `CanSprintAttack` 配置开启，且（正在跑步，或当前技能是冲刺槽里非末段的技能）时，slot 改为 `SPRINT_SLOT`。
3. **搓招**：
   - 取 `"n+"` 技能，曝气时取 `"n++"`。
   - 找不到技能时退回普攻 `"A"`。
   - 找到时先触发 `BFEvent.BEFORE_PREPARESKILL`，再看 `isAllowCast(false)`，不能放也退回普攻。
4. **曝气键**：已经在曝气中或正在放曝气技能时，返回 false。
5. **曝气中**：如果存在 `slot.."+"` 版本，改用该版本。
6. 如果当前不在 Attack 状态，`resetSkill()` 清理残留。
7. 调用 `presetSkill(slot, bUseAi)`。

### 5.4 SkillPool:presetSkill（`:361-432`）：预约下一招

1. `nextSkill = getFightSkill(slot)`（`:1016`）：
   - 如果当前技能与 slot **同槽**：
     - 当前技能有多次使用（`cd_count>1`）且还有剩余次数，则继续使用当前段。
     - 否则沿 step 往后推一段；已是最后一段时，`slotIndex+1`、`step=1`。这就是**连携**，例如普攻 A1→A2→A3。
   - 如果**不同槽**，从 `[slot][1][mode][1]` 开始。
   - `mode` 取值：1 为普通，2 为搓改（`_2`）；也可能来自实体当前的 `CurSkillChange`。
2. `setIsUpTouch(false)`，`setSkillTime(0)`；`isAllowCast(auto)` 为真时记录摇杆参数（只对搓招类技能生效）。
3. 不能放时返回 false；能放时触发 `BEFORE_PREPARESKILL`。
4. 挂到实体上：

| 情况 | 结果 |
|---|---|
| 当前没有技能 | `setSkillBase(nextSkill)` 立即生效 |
| 同槽，`getAllowInterrupt()` 为真且 `nextSkill:isPriority(cur)` | 立即替换 |
| 同槽，其余情况（闪避除外） | `cur:setNextSkillBase(next)`，**缓存为下一招**，由当前动作到达中断帧时接上（§7.3） |
| 异槽，允许中断且优先级够 | 立即替换 |
| 异槽，其余情况 | 缓存为下一招 |

- `isPriority`（`SkillBase.lua:502`）：`sorder == -1`、对方 `sorder == -1`，或 `self.sorder >= other.sorder` 时为真。
- `setSkillBase`（`EntityRole.lua:2828`）：把 `bAllowInterrupt` 和 `bAllowExtraInterrupt` 置为 false。刚放过挣脱技能时，本次按键会被丢弃。

### 5.5 AI / 自动战斗

AiAgent 的详细逻辑见 AI 文档 §B。攻击入口是 `AiAgent:executeAttack`（约 `module/ai/AiAgent.lua:400-570`）：

- 朝向目标设置 `controlParam`（`:446-454`）。
- **自动战斗的主角**：
  - 受击中时尝试挣脱 `"L"`。
  - 没有当前技能时，按 `I,J,K,G,H,B,C,D,1+…12+,A` 的顺序找第一个 `isAllowCast(true)` 为真的槽，调用 `dealButtonEvent(Slot2Event[slot], nil, true)`（`:461-481`）。
  - 已有技能时尝试按连携下一段。
- **怪物**：
  - 每个槽有 `fAiSkillCastInterval[i]`（初值为 `skill_priority_level_cd`）。
  - 在间隔已到 0 的槽中，按 `skill_priority_level` 从高到低排序。
  - 对每个槽调用 `presetSkill(string.char(64+i), true)`，其中 `auto=true` 会触发 SkillAi 的检查。成功后 `dealWithStatus(Attack)`，并把同优先级的所有槽的间隔重置（`:510-557`）。
  - 已有技能时，用同槽 `presetSkill` 接连携（`:559`）。

---

## 6. SkillPool / SkillBase

### 6.1 技能池构建：`SkillPool:loadSkill`（`SkillPool.lua:57-90`）

- slot 字符串的生成方式：
  - Normal 组：`string.char(64+i)`，即 A、B、C…
  - Crazy 组：同样的字母再加 `"+"`。
  - JoyStick 组：`"<n>+"`；JoyStick_Crazy 组：`"<n>++"`。
  - Special 组：从 `90-#special` 开始取字母，所以排在 Z 前面（Sprint 为 `"Y"`）。
  - 第 6 组及以后：`"%s"..分隔符..index`。
- 数据结构 `tPool[slot][slotIndex][modeIndex][stepIndex] = SkillBase`：
  - `slotIndex`：连携第几招。
  - `modeIndex`：1 普通，2 搓改。
  - `stepIndex`：沿 `skill_attack.next_skill` 递归展开的段（`createAttackSkillNode`，`:770-814`）。
- 同时生成挂在 ROLE 树 **攻击节点**（`BEHAVIOR.ROLE_ATTACK_NODE_INDEX`）下的子树，由 `BehaviorManager:resolveBehaviorTree` 解析：

```
BTSelector [ConditionAttackSlot slot]                      createAttackSlotNode :672
 └ BTSelector [ConditionAttackSkillStep slot,idx,mode,step]  createAttackSkillNode :800
    └ BTSelector [ConditionAttackPipe pipeIndex=N..1]        createAttackPipeNode :826  (N = cd_count 次数)
       ├ (按下释放) BTSequence [ConditionAttackVectorIndex j]  createAttackTowardNode :902
       │     action: AttackRole(actionId=action_ids[j][1]), AttackRole(action_ids[j][2]) ...
       └ (skill_type==1 抬起释放) BTSelector
             ├ BTSequence [ConditionAttackRelease] → up_action_ids
             └ BTSequence [ConditionAttackPress]   → action_ids
```

- 各条件节点（`module/behaviortree/conditions/ConditionAttack*.lua`）检查当前 skillBase 的 slot、index、mode、step、pipe、toward 是否与本节点相同。
- **enter / exit 钩子**是技能生命周期的主干：
  - `ConditionAttackPipe:enter` 调用 `SkillPool:dealWithCastPipeBegan`（`SkillPool.lua:555`）。
  - `exit` 调用 `dealWithCastPipeEnded`（`:596`）。
- 每个槽里**最后一招的每个 mode 的最后一段**会 `setFinally(true)`（`:689-694`）。

### 6.2 生命周期

```
presetSkill → EntityRole.pSkillBase = skill (或 cur.pNextSkillBase = skill)
dealWithStatus(Attack) → ROLE 树进入攻击分支 → ConditionAttackSlot/Step/Pipe 匹配
 ConditionAttackPipe:enter → dealWithCastPipeBegan(:555)
   ├ 新的一招首段: BuffPool BEFORE_NEXT_SKILL
   ├ skill:castBegan()                      SkillBase.lua:818
   │   dealWithCoolDown  开始 CD (cd 或 pvp_cd × ColdTimeScale)
   │   dealWithConsume   扣晶体 / MP(TP) / EP (曝气中不扣 MP/EP)，触发 USE_TP / USE_EP
   │   dealWithDirection 摇杆 8 向 → 选 action_ids[toward] (:597)
   │   同槽其它 mode 同步进 CD；连携第 2 招以后把 CD 加到槽首技能上 (GamePad 显示)
   │   selectSkillPipe / expectSkillPipe / reduceSkillRelease  (多次使用计数)
   │   SKILL_COLD_START、SKILL_CAST_BEGIN 事件；beginSkill 记入 tSkillRunning
   │   checkAndChangeSkillGroup / checkAndChangeSkillChange (skill_change_system)
   ├ BuffPool BEFORE_CASTSKILL；SpecialAbilityPool BEFORE_CASTSKILL
 AttackRole × n (§7) 依次执行
 ConditionAttackPipe:exit → dealWithCastPipeEnded(:596)
   ├ BuffPool AFTER_CASTSKILL；(末段) AFTER_NEXT_SKILL；SpecialAbility AFTER_CASTSKILL
   ├ skill:castEnded()  SKILL_CAST_ENDED
   └ 若 pSkillBase 仍是本技能 → dealWithNextSkillBase() 切到缓存的下一招 (SkillBase.lua:561)
```

- **Attack 位何时清除**：技能序列执行完、且没有下一招时，攻击分支返回 Success，Attack 位被清除，`pSkillBase` 置空。具体由攻击节点的 decorator 处理（**未确认**，见 AI 文档 §A.6）。
- **强制打断**：`EntityRole:forcedInterrupt`（`:2787`）调用 `SkillPool:forcedInterrupt`（`SkillPool.lua:187`）：
  - 用 `clearSkillEffectsByInterrupt` 清掉该技能的特效（按技能 id 和释放者 tag 匹配，`:205`）。
  - 清空缓存的下一招，`setSkillBase(nil)`。
  - 受击（§10）和眩晕（`BuffStun.lua:29`）都会调用它。

### 6.3 冷却与次数

- `SkillBase:update`（`:229`）：当 `bTiming` 为真时，`fColdTime -= DT`。CD 走到 0 时：
  - 重置 `ColdMaxTime`。
  - `addSkillReleaseCount()`：次数 +1，未满则继续下一轮 CD（`:990`）。
  - 触发 `SKILL_COLD_END`。
- **次数制（`cd_count`）**：`iSkillReleaseMaxCount = cd_count`，未配置或配 -1 时为 1。`isCooling()` 只在**次数用完且 CD>0** 时为真（`:320`），即"先扣次数，后进 CD"。每用一次调用一次 `reduceSkillRelease`。
- `addColdTime`（Buff 用于加减 CD，`:794`）、`cleanColdTime`（`:804`），以及 `SkillPool:resetCoolDownTime`（`:153`）。
- `SkillPool:updateRunningSkill`（`:1135`）把仍在冷却的技能留在 `tSkillRunning`，并记录 BASE_SLOTS 中哪些槽在冷却（供 Buff 查询）。

### 6.4 能否释放：`isAllowCastInternal`（`SkillBase.lua:424-478`）

判断依次为：
1. `skill_attack.type == -1`（普通技能）时：受击中只允许挣脱，挣脱也要求处于可挣脱状态。
2. 沉默或眩晕时不能放。
3. 槽位被禁用（`slotIsDisabled`）时不能放。
4. `isCooling()` 时不能放。
5. MP、EP、晶体不足时不能放（`:328-363`）。曝气键 `"E"` 在曝气中始终不能放。
6. `isAutoCast` 为真且存在 SkillAi 时，要求 `pSkillAi:check()` 通过。

`isAllowCast`（`:480`）不满足时，若英雄处于 Idle 或移动，会触发 `startBodyShake` 抖动提示。

### 6.5 SkillAi 闸门（`module/skill/SkillAi.lua:44-71`）

`check()` 依次判断：
1. `load_cd` 已到 0（初始延迟）。
2. 剩余使用次数：`use_count` 为 -1 表示无限次。
3. `check_cd` 已到 0。
4. `checkComposition`（`:103`）：`composition[1]` 中的检查**全部**满足（AND），并且 `composition[2]` 中**至少一个**满足（OR，-1 表示总是满足）。检查函数的编号为：
   - 1：`opp_dis_x`；2：`opp_dis_z`。区间两端各放宽一帧的移动距离。
   - 3：`opp_status`（按位匹配）。
   - 4：`opp_combo`（对手正在打连携第 2 招以后）。
   - 5：`opp_skill_id`。
   - 6：`self_hp%`。
   - 7：`self_status`。
5. 通过以上条件后才设置 `fCheckTime = check_cd`，然后 `GRandomF(0,100) < prob`。成功则 `use_count--`。

---

## 7. AttackRole：施法叶子

每个 `AttackRole` 对应一行 `action_attack`（`module/behaviortree/actions/AttackRole.lua`，基类为 `ActionAttack.lua`，再上一层是 `ActionBase.lua`）。

- **帧与时间换算**：`fInterval = 1000*LOGIC_DT / (aciton_scale_time × ActionScale)`，即每帧的毫秒数（`:41,218`）。
- `fTime` 在 `ActionBase:update` 中每帧加 `delta*1000`（`ActionBase.lua:104`）。
- 配置中的"第 N 帧"会换算成 `fTime >= fInterval*N`，也就是逻辑帧数，并随动作速率缩放。

### 7.1 enter（`AttackRole.lua:180-269`）

1. `ActionAttack.enter`：`fTime=0`，清空特效和震屏记录。随后触发 Buff `BEHAVIOR_STATE_START`（`ActionBase.lua:82`）。
2. `setAllowInterrupt(false)`，`setAllowExtraInterrupt(false)`。
3. `control==1` 时，按摇杆参数设置方向和朝向；PVP 机器人第一段会自动转向目标。
4. `setActionPosition`（`:274`）：
   - `action_pos_type` 为 0 时，移动到地图相对坐标；为 1 时，移动到绝对坐标。
   - `action_orientation` 为 0 时朝左，为 1 时朝右。
5. 触发 Buff `BEFORE_ROLE_SKILL_ACTION`。
6. 播放 spine 动作 `actionData.action`（按 loop 配置，回调为 `onAnimationEvent`），设置 time scale 和影子。
7. **位移**：`pDisplacement:resetDisplacement()`，然后 `setDisplacement(displacement_id, onDisplacementEvent)`（§12）。
8. `buff_ids`：`addEntityBuff(id, baseSkillId)`，在 exit 时移除。这是"动作期间 buff"，例如动作自带霸体。
9. 残影（ghost）、提示条、喊招气泡、音效。

### 7.2 execute（`:349-371`）：每帧依次执行

| 步骤 | 函数 | 内容 |
|---|---|---|
| 1 | `dealWithSkillSpine` :539 | `fTime >= display_spine_frame` 时执行一次 `CameraManager:startFreeze(display_spine_ids)`，播放全屏必杀动画（§13） |
| 2 | `dealWithTime` (ActionAttack :110) | 动画播完（`onAnimationEvent` "complete" 且循环次数满足）后 `fTime` 置 0，再等 `action_delay_time` 毫秒，之后状态为 **Success**，序列进入下一个 AttackRole |
| 3 | `dealHitProtect` :376 | 英雄的受击保护已触发时，强制结束动作并 `mixStatus(HitDown)` |
| 4 | `dealWithInterrupt` :390 | 见 §7.3 |
| 5 | `dealWithExtraInterrupt` :440 | 见 §7.3 |
| 6 | `dealWithControl` (ActionAttack :120) | `control` 为 0 时摇杆可自由移动，速度为 `control_velocity`（此时 displacement 必须是 -1）；为 2 时只改方向；为 3 时可移动但不改朝向 |
| 7 | `dealWithEffect` :487 | 对每个 `effect_ids[i]`，在 `fTime >= fInterval*effect_frames[i]` 且尚未创建时生成特效，见 §7.4 |
| 8 | `dealWithShake` (ActionAttack :162) | 对每个 `camera_frame[i]`，触发一次 `CameraManager:startShaker(camera_id[i])` |
| 9 | `dealWithTransformEntity` :550 | 到 `transform_frame` 时 `dealWithTransformEntity(action_id, transform_type)` 变身 |
| 10 | `dealWithStatic` :568 | 定身，见 §13.2 |

**位移事件**（`ActionAttack:onDisplacementEvent`，`:73`）：
- `"brake"`：速度归零。无限循环动作（`loop==-1`）遇到它就结束。
- 撞墙（`left/right/top/bottom`）时看 `obstruct`：0 表示穿越（返回 true，不修正坐标）；1 表示结束动作并 `setObstruct(true)`；-1 表示停在墙边。
- `"floor"` 或 `"lie"` 且 `floor==0` 时，结束动作。

### 7.3 中断窗口

**普通中断**：`dealWithInterrupt`，`:390-435`。
- `interrupt_frame == -1` 时永远不能中断。
- `fTime <= fInterval*interrupt_frame` 时尚未到窗口。
- 到窗口后：
  - 如果有缓存的下一招 `pNextSkillBase`（经过 `correctCrazySkill`，曝气结束后回落到普通版），并且"同槽"或"异槽且下一招优先级 ≥ 当前"，就执行 `dealWithNextSkillBase()`：`pSkillBase` 换成下一招，重新选 pipe，然后本动作 Success。这时 ROLE 树的攻击条件匹配到新的 step 或 slot，进入新子树。
  - 没有下一招时，如果按了跑步（`bNextRunStatus`），本动作 Success。
  - 最后 `setAllowInterrupt(true)`，此后 `presetSkill` 可以直接替换当前技能（§5.4）。

**至尊中断**：`dealWithExtraInterrupt`，`:440-482`。
- 从 `interrupt_extra_frame` 起，`setAllowExtraInterrupt(true)`。
- 异槽时要求 `isSuperPriority`：`sorder_control_type` 包含 1（`IgnoreOrder_InterruptFrame`）且允许普通中断，或包含 2（`IgnoreOrder_InterruptExtraFrame`）且允许至尊中断。满足时无视 sorder 直接接招。挣脱、闪避一类技能靠这条路径。

### 7.4 生成特效（`dealWithEffect`，`:487-534`）

1. `EntityManager:addEffect(effectId, Neutral, ownerTag)`（`EntityManager.lua:1094`）：优先从预加载池 `popPreloadEffect` 取对象。
2. `setCustomPosition(effect, role)`（`EntityEffect.lua:552`）：按 `position_type`、`relative_position` 和朝向定位。
3. `dealWithFollow`。
4. `setSkillInfo{skillId, baseSkillId(槽首技能), skillSlot, skillAttributeTag}`：伤害公式和 Buff 过滤都靠这个字段。
5. `setEffectCreatorType(EntityRole)`。
6. 如果 `extend_role_vec==1`，使用 `custom_vec` 作为方向。
7. `effect:enter()`：注册碰撞；非预加载的 `binding` 调用会重新注册监听（`EntityEffect.lua:210-231`）。然后 `dealWithControl()`（可控特效，§5.1）。
8. 生命周期：
   - `auto_release==0`：动作 exit 时销毁（`ActionAttack.lua:37-50`）。
   - `auto_release==1` 且跟随角色：挂到 `EntityLifecycleArray`，随角色一起释放。
   - `auto_release` 为 2 或 3：按命中次数销毁（§8.4）。

### 7.5 exit（`:302-344`）

1. 触发 `AFTER_ROLE_SKILL_ACTION`。
2. `setAllowInterrupt(true)`，`setAllowExtraInterrupt(false)`。
3. 恢复动画速率。
4. **重置位移**。
5. 移除 `buff_ids`，隐藏残影，停止循环音效。

### 7.6 AttackEffect（特效自身的动作）

EFFECT 树为 `AttackEffect × n` 再接 `ActionDestroy`（`EntityEffect.lua:332-346`），对应 `entity_effect.action_ids → action_attack_effect`。

- `enter`（`AttackEffect.lua:81`）：按释放者的 ActionScale 计算帧长，播放动画，设置 `displacement_id`（特效飞行），音效按受击者的 `sound_type` 选择 `sound_id2`。
- `execute`（`:145`）依次执行 `dealWithTime`、`dealWithControl`、`dealWithEffect`、`dealWithShake`、`dealWithSummon`：
  - `dealWithEffect`：通过 `dealWithEffectById` 生成子特效。
  - `dealWithSummon`（`:171`）：按 `summon_id` 召唤角色。
- 所有动作跑完后执行 `ActionDestroy`，特效被销毁，随后在 update 中触发 `next_effect_id`（§1.3）。

---

## 8. 特效、碰撞与命中

### 8.1 碰撞体

`ComponentCollision`（`module/component/ComponentCollision.lua`）：
- `registerCollisionListener` 创建 C++ 对象 `AECollider(AECollision, type, tag, camp, hostileCamp)`（`:52`）。
- 每帧 `update` 调用 `pCollider:updateVerticesSync(spinePath, curAction, avatarTime, x, y+z, scaleX*towardX, scaleY)`（`:38`）。碰撞形状来自 **spine 动画当前帧的包围框 attachment**，由 `AESpineColliderManager:readSpineColliderFromFile` 预读（`util/engine/SpineManager.lua:135`）。
- 投影平面为 `(x, y+z)`，即屏幕平面。
- C++ 侧 `AECollision:update` 检测相交后，回调 `onCollisionEvent(event, data)`。按阵营过滤的具体规则在 C++ 里，**未确认**。

Lua 侧（`dealWithCollision`，`:82-132`）：
1. 联机时，如果碰撞体注册和碰撞发生在同一同步帧，**丢弃本次碰撞**（`:85`），这是为了保证确定性。
2. **Z 深度过滤**：只有 `|z_self - z_other| < radius_self + radius_other` 时才算碰撞（`:101-102`）。2.5D 横版中"同一条线"的判定就在这里。
3. 记录接触点 `tContactPoint`，用于决定受击特效和伤害数字的位置。
4. 每个对方 tag 维护一个 None → Began → Continue → End 状态机。C++ 事件码 0 为开始，1 为持续，其余为结束。离开深度范围时补发 End。

### 8.2 特效碰撞分派：`EntityEffect:onCollisionEvent`（`EntityEffect.lua:348-394`）

- End 事件忽略；对方 `getLogicEnable()` 为假、或特效已没有所属角色时忽略。
- **对方是水晶**：`CrystalBeHit()`（`EntityRole.lua:3552`）返回真时，只生成受击特效。
- **对方是敌方角色**（`camp` 属于 `belongRole.hostileCamp`）：
  - `hit_target` 为 Friend 或 FriendAndHit 时跳过。
  - 否则 `dealWithHitX(entity)`，并且当对方**不在闪避技能中**时施加 `debuff_id`（`dealWithDeBuff`，加到对方的 BuffPool）。
- **对方是友方或自己**：
  - `hit_target` 为 Enemy 时跳过。
  - 为 FriendAndHit 时也执行 `dealWithHitX`。
  - `dealWithBuff`：对象是自己时加 `buff_id`，否则加 `buff_all_id`。
  - `dealWithSameCampCollision`：对友方触发 BEFORE_HIT 和 AFTER_HIT，以及 `specialability_id` / `specialability_all_id`（`:788-830`）。
- **对方是障碍物**，且攻击方属于我方阵营：`dealWithHitX` 加上 `dealWithObsturct`。

Buff 施加细节：`dealBuff` 调用 `buffPool:addBuffForApplicator(id, nil, targetTag=nil, baseSkillId, imposerTag=释放者tag, skillAttributeTag, …)`（`:506-521`）。因为 `targetTag` 为 nil，`TargetEnemy` / `TargetTeammate` 类的 buff 从这里**不会生效**；debuff 在配置上应写成 `target=Self`（相对受击者的池），BuffPool 的分派见 `BuffPool.lua:887-951`。

### 8.3 dealWithHitX：一次命中的完整阶段（`EntityEffect.lua:721-785`）

```
dealWithHitX(enemy):
  if bDestroy / fHitInterval>0 / hit_id==-1 / (hit_counts~=-1 且 iHitCount>=hit_counts) / enemy 死亡 / not enemy.bBeHitEnable → return
  if hit_interval == -1:                     -- 单次命中型: 每个目标只打一次
      if #tHitEnemyTagArray >= hit_counts → return
      if enemy.tag ∈ tHitEnemyTagArray → return        ← 命中去重
      append enemy.tag
  iHitCount += 1
  if enemy:skillDodge(self) → return          -- EntityRole.lua:2979: 无敌 且 hit_extra_control[1]==0 且 非必中
                                              --   若同时在闪避技能中 → dealWithDodge (EVADE_SUCCESS, "闪避"字)
  if enemy 是角色 and hit_must==0:            -- 属性闪避
      rate = clamp((dodge+ADD_DODGE − (hit+ADD_HIT))/100, 0, 0.5)   SkillHurt.lua:227
      if rate*100 >= GRandomF(0,100) → enemy:dealWithDodge(self,true) (ATTACK_MISS, "MISS") ; return
  attacker:dealWithHitBefore                  -- 空
  isHit = enemy:dealWithBeHitBefore(attacker, effect)     EntityRole.lua:3039
  if isHit and hit_type ~= -1:
      attacker:dealWithHitBegan               -- Buff/SA BEFORE_HIT (:2899)
      hurt,crit = enemy:dealWithBeHitBegan    -- 算伤害+扣血+受击状态 (:3129, §9/§10)
      attacker:dealWithCalAnger               -- 怒气
      enemy:dealWithBeHitEnded                -- SA AFTER_TOBEHIT, 伤害数字, 连击, 受击回 EP, Buff AFTER_TOBEHIT (:3291)
      attacker:dealWithHitEnded               -- DPS, 命中回 EP, SA/Buff AFTER_HIT (:2932)
  enemy:dealWithBeHitAfter / attacker:dealWithHitAfter   -- 清临时字段
  if isHit and not bDestroy → dealWithHitEffect(enemy)   -- 受击特效 (:401)
```

**`dealWithBeHitBefore`**（`EntityRole.lua:3039-3103`）判定是否命中：
- 死亡且开启了"禁止鞭尸"、或 `logicEnable=false` 时返回 false。
- 记录伤害数字的位置 `pKnockCollisionPoint`。
- 起身中（GetUp）且 `hit_extra_control[2]==0` 且非必中时返回 false。
- `setBeHitEffect`，触发 Buff `BEFORE_TOBEHIT`。
- `hit_type==-1`（无伤害也无硬直）时返回 true，但不会进入伤害阶段。
- 处于 Death、GetUp、Wake 时返回 false。**Wake 是起身后的无敌窗口**。
- 机关（Machine）每次命中 `iHitCount-1`，为 0 时死亡。
- `hit_condition` 的取值：
  - 0：不能命中躺在地上的目标（`HitFloor` 且 y==0）。
  - 1：不能命中浮空的目标（HitDown 或 HitUp）。
  - 2：两者都不能命中。

**受击特效**（`dealWithHitEffect`，`:401-452`）：
- 受 `hit_effect_interval` 节流（该字段目前恒为 0）。
- 对每个 `hit_effect_ids`，如果同一受击者身上已有同 id 的特效就复用，否则新建；新建的特效没有 next 时绑定受击者。
- 位置取 `(接触点x, 接触点y − enemy.z, enemy.z − 1)`。
- 继承 skillInfo、创建者类型和神器 id。受击特效自己也可以带 `hit_id`，这就是二次判定和爆炸扩散的做法。

### 8.4 命中间隔与次数

| 配置 | 行为 |
|---|---|
| `hit_interval == -1` | 每个目标只命中一次（按 tag 去重）；最多 `hit_counts` 个目标（-1 表示不限） |
| `hit_interval > 0` | 不按目标去重。**一帧内**可以打到所有重叠的目标，因为 `fHitInterval` 只在下一帧 update 时才重置（`EntityEffect.lua:275-278`）。之后要等 `hit_interval` 毫秒才能再打。`hit_counts` 限制总命中次数，但 `iHitCount` 每帧会清零，所以实际上限制的是**单帧**命中数（**未确认**是否为有意设计） |
| `auto_release` 为 2 或 3 且 `hit_interval==-1` | 命中目标数达到 `hit_counts` 后销毁。为 2 时不触发 next_effect，为 3 时触发（`:633-652`） |

---
## 9. 伤害公式

入口是 `EntityRole:dealWithBeHitBegan`（`EntityRole.lua:3129`），它先算 `addition`，再调用 `SkillHurt:calculateDamage(effect, addition)`（`module/skill/SkillHurt.lua:108-209`）。**这套公式里没有元素或属性克制**，只有 `hit_restrain` 这个伤害许可开关（§9.3）。

```
-- 0) 等级加成 addition   (EntityRole.lua:3141-3164)
if 公平模式:        addition = (角色等级 + 装备技能等级×步长) × SKILL_HURT_DEFAULT_ADDITION
elif 有 skillAttribute (玩家技能):
     leaf.hurt_type==1 → addition = ((技能等级−1)×步长 + 解锁等级) × SKILL_HURT_DEFAULT_ADDITION
     leaf.hurt_type==2 → addition = 角色等级 × SKILL_HURT_DEFAULT_ADDITION
else:               addition = 角色等级 × SKILL_HURT_DEFAULT_ADDITION
-- SKILL_HURT_DEFAULT_ADDITION = 0 (imports/Const.lua:614) ⇒ addition 恒为 0

-- 1) 攻防类型 (hitData = skill_hit[effect.hit_id]; A = 攻击方属性(特效共享所属角色), D = 受击方属性)
hurt_type: 0 物理 → atk=A.ATK,  def=D.DEF
           1 魔法 → atk=A.MATK, def=D.MDEF
           2 自适应 → A.ATK>=A.MATK ? 物理 : 魔法
           3 真伤 → rate = 1
PVP: atk = floor(atk×(1+A.PvpATK)); def = floor(def×(1+D.PvpDef))
     (真伤时 atk/def 为 nil，PVP 下这里会报错 —— 源码缺陷，移植时跳过)

-- 2) 基础
rate      = atk/(atk+def)          (atk+def==0 → 0)                          :212
standHurt = getStandardHurt(A)                                                :42
   英雄:   A.ATK + skill_hurt[lv].hurt
   召唤物: 递归取最终主人的 standHurt
   其它:   A.BasicHurt + skill_hurt[max(1,floor(lv/10))].monster_hurt
hurt = standHurt × rate × (PVP ? pvp_hurt_rate : hurt_rate) × (1+addition)

-- 3) 暴击
critRate  = clamp((A.crit + A.ADD_CRIT − D.critDef − D.AVOID_CRIT)/100, 0.01, 1)          :217
critMul   = clamp(1.5 + (A.critHurt + A.ADD_CRIT_HURT − D.critHurtDef − D.ADD_CRIT_HURT_DEF)/100, 1.5, 2.5)  :237
if critRate×100 >= GRandomF(0,100): hurt ×= critMul; crit = true

-- 4) 增减伤
hurt ×= (1 + A.ADD_HURT) × (1 − D.AVOID_HURT)
if effect 是神器技能 或 CapabilityTrigger 产生: hurt ×= (1 + A.ADD_ARTIFACT_HIT)

-- 5) 浮动与取整
hurt ×= (99 + 0.02×GRandomF(0,100)) / 100        -- 0.99 ~ 1.01
hurt = max(hurt, 0); return floor(hurt), crit
```

注意：
- 随机数都来自同步种子 `AEUtil:GRandomF`。
- 调用顺序固定为：闪避 → 暴击 → 浮动；有 buff 时还有 buff 的概率判定。联机时这个顺序必须一致。
- **没有最小伤害**。结果为 0 也照样走完受击流程，`hurt≥0` 由 `max(hurt,0)` 保证。

### 9.1 扣血：`modifyHp(-hurt, effect)`（`EntityRole.lua:1510-1578`）

1. 扣血时如果 `bBeHitEnable=false`，直接返回。KO 后己方无敌就是这样实现的（`FightScene.lua:1488-1492`）。
2. 回血时：有 `BFChill`（寒气）则禁止回血；有 `BFHealingChange` 则回血量乘以 `(1+Σparam[1])`。
3. `checkHurtPermit(effect, Permit_Hp)` 不通过时，不扣血，但照常显示。
4. **护盾** `calcShieldAndHp`（`:1482`）：
   - 先算 `hp2 = hp × ShieldConsumeScale`。
   - 护盾值大于 `|hp2|` 时，全部由护盾吸收。若 `BFShield` 配了 `param[4]`，则按层数扣：每次受伤减一层，最后一层用完时清空护盾。
   - 护盾不足时护盾破裂，剩余伤害 `hp + shield` 扣到血上。
5. `hp = clamp(hp+Δ, 0, maxHp)`，并且不低于 `HpLock`（锁血 buff）。
6. HP≤0 时触发 `BEFORE_DEATH`，可用于免死类 buff。刚死亡时：
   - 如果不在受击中也不在死亡中，`dealWithStatus(Death)`。受击中的角色由受击叶子负责转入死亡。
   - 播放 `ko_effect`，处理变身关联，退出怒气变身。
7. 未死亡时触发 `HP_CHANGE`。

`dealWithBeHitBegan` 的替代扣血分支：有 `BFEpReplaceHp` 或 `BFTpReplaceHp` 时，这次伤害改扣 EP 或 TP（`:3178-3188`）。

### 9.2 Buff 伤害（DOT）

- `BuffBase:getAttackValue`（`module/buff/BuffBase.lua:984`）返回 `SkillHurt:calculateBuffDamage(施加者 or 自身, param_value[1], addition) × iRepeat`。
- `calculateBuffDamage` 的公式是 `floor(standHurt × param × (1+addition))`（`SkillHurt.lua:82`）：**不计防御，不计暴击，也不浮动**。
- 结算入口是 `EntityRole:dealBuffDamage`（`:3344`），它调用 `modifyHp(attackValue)`。由于这里没有取反，伤害类 buff 的 `param_value` 应当配**负数**（**未确认**，需要看表中数据）。

### 9.3 伤害许可（`checkHurtPermit`，`:2801`）

`entity_role.hit_restrain` 是一个三元组，三个下标分别是 `Permit_Attack`（攻击方能否造成伤害）、`Permit_Hp`（受击方是否真的掉血）和 `Permit_HurtNum`（是否显示伤害数字）。

判定规则：`攻击方[Permit_Attack] × 受击方[对应项] > 0` 时许可。配 -1 等同于 1。

### 9.4 能量

- **攻击方命中回 EP**（非曝气时）：`energy × EPRecoveryScale × (目标是 Boss ? 1.5 : 1)`（`:2937-2941`）。
- **受击方回 EP**（非曝气时）：`min(100×hurt/maxHp, 100) × CRAZY_FROM_HURT_VALUE(15) × EPRecoveryScale`（`:3313-3316`）。
- **连击经验**：`effect.combo_exp × ParameterExp`，加到攻击方的 `pCombo` 上（`:3306-3310`）。

---

## 10. 受击状态机

### 10.1 进入受击（`dealWithBeHitBegan` 后半段，`EntityRole.lua:3202-3273`）

**霸体**（`SuperArmor` 激活）：
- 只扣血，不冻结，不改方向，不改变状态。
- 如果在地面且已死亡，进入 Death。否则只调用 `hitProtectInit`。

**非霸体**：
1. **顿帧**：
   - `freeze_time_control_effect==0` 时，特效冻结 `freeze_time`。
   - `freeze_time_control_role==0` 时，攻击者冻结 `freeze_time`。
   - 受击者在 `freeze_time_delay` 毫秒后冻结 `freeze_time`，用 `REGLOGICTIMER` 延迟执行。
2. **朝向**：受击者的 vectorX 和 towardX 都设为特效朝向的反方向，即面向攻击来源。
3. **硬直时间**：
   - 当 `fStiffTime==0` 或不在 HitFloor 中时，设为 `stiff_time × (1+ADD_FLOOR_TM)`。
   - 如果 `entity_role.hit_stiff_time ~= -1`，改用它，同样乘 `(1+ADD_FLOOR_TM)`。
4. **已在受击中**：
   - 写入新的 `tEntityParams.hit_id`。Boss 和 Hero 死亡时不写。
   - 若浮空值已耗尽（`isRigidity()`），`hit_counts+1`。
   - `updateHitProtectTime`。
   - 当前受击叶子在下一帧 `dealWithDoubleHit` 中读取新的 `hit_id`，这就是**连段追击**。
5. **不在受击中**：已死亡则进入 Death；否则先 `forcedInterrupt()` 打断技能，再 `dealWithStatus(Hit, hitDataId)`。

**实际硬直**：`getStiffTime`（`:1224`）读取时，若浮空值已耗尽，按 `fStiffTime − fatigue × hit_counts` 递减。浮空连段打得越久，硬直越短。

### 10.2 浮空值（rigidity）与重量（weight）

- `fRigidity` 初值为 `entity_role.rigidity`。`isRigidity()` 在 `fRigidity<=0 且 表值>0` 时为真，表示"浮空保护已触发"（`:1762`）。
- 追击时各叶子调用 `dealWithWeight(hit_rigidity)`（`:2413`）：
  - `fRigidity -= hit_rigidity`。
  - 一旦耗尽，每次受击 `fVelocityY -= weight × hit_counts`，让目标加速下落。
  - 英雄会同时加上浮空保护 buff 155、白框 buff 154；在受击保护路径下加 173。
- `ActionWake` 把浮空值恢复为表值（`ActionWake.lua:25`）。

### 10.3 各叶子的转移

以下都是 `module/behaviortree/actions/` 下的 `ActionCanBreakBase` 子类。它们每帧先检查挣脱：当前或上一个技能是 `BREAK_SLOT` 时，`setSuccessStatus(Attack)`，清空位移和硬直（`ActionCanBreakBase.lua:10-34`）。

```
                  hit_type 0 (击退)                         hit_type 1 击倒 / 2 击飞
Hit ──────────────────────────────────────────────┐        │
 │ enter: hit 动画; 位移 = entity.hit_displacement_id      │ 动画完 且 entity.hit_displacement_id==-1
 │   (-1→skill_hit.displacement_id; 0→无; n→仅 type0 用)   ▼
 │ 动画完 + 位移 brake + fTime>=stiffTime → HitSwitch   HitUp ──(位移 air/lie 且动画完)──► HitDown
 │ 位移 "air"(y>0 且下落) 且动画未完 → HitDown           │ 追击: type0→air_displacement_id; type1→立刻 HitDown;
 │ 追击(dealWithDoubleHit): 地面 type0 重播 hit;          │       type≠1 → dealWithWeight(hit_rigidity)
 │   空中 type0 → air_displacement_id; type1/2 → HitUp   ▼
 ▼                                                     HitDown ──(位移 lie 且动画完)──► HitFloor
HitSwitch ─(动画完)→ 清 HitSwitch 位；死亡则 Death        │ 追击: type0/2 且浮空值未耗尽 → HitUp (再次挑起)
 │ 期间再次受击 → Hit                                      ▼
                                                       HitFloor (倒地)
                                                        │ 动画完 + 位移 brake/lie → fTime 清零计时
                                                        │ fTime >= stiffTime → GetUp (死亡→Death)；stiffTime=0
                                                        │ 追击: type1 → HitDown；type0/2 且浮空值未耗尽 → HitUp
                                                        │       (两者都会重设 stiffTime)
                                                        ▼
                                                       GetUp  enter: 英雄加 buff 156(起身保护,PVP)、154
                                                        │ 动画完 → Wake (死亡→Death)
                                                        ▼
                                                       Wake   enter: 英雄加 ROLE_HERO_WAKE_BUFF_ID=201(无敌)，
                                                              怪物为 -1；恢复浮空值；英雄重置受击保护
                                                              execute: 立即 Success → 回到 Idle 分支
```

各叶子的代码位置：
- `ActionHit.lua:13-196`
- `ActionHitUp.lua:12-99`
- `ActionHitDown.lua:18-96`
- `ActionHitFloor.lua:12-119`
- `ActionHitSwitch.lua:4-30`
- `ActionGetUp.lua:4-39`
- `ActionWake.lua:4-36`

这些叶子里：
- 位移事件 `"floor"` 在浮空值已耗尽时返回 true，于是 `ComponentDisplacement` 不再反弹，直接把速度清零（§12）。
- 撞墙事件返回 false，由组件把位置修正到墙边。

### 10.4 受击中还能做的事

- **挣脱**：`"L"` 槽的技能能在 `isCanBreakStatus` 下施放（`SkillBase.lua:432`）。施放后叶子检测到 BREAK_SLOT 就转入 Attack。
- **受击保护**（英雄）：`hitProtectInit`、`dealHitProtectUpdate`、`getHitProtectData().isExecuted` 为真时，强制 `mixStatus(HitDown)`（`ActionHit.lua:74`，`AttackRole.lua:376`）。阈值逻辑在 `EntityRole.lua:4019-4076`，具体数值**未确认**。

---

## 11. Buff

### 11.1 数据与类

- `buff_base` 每行对应一个 buff，其中 `rule_id` 指向 `buff_rule.class_name`，即 Lua 类名。
- 类文件：
  - `module/buff/xstatus/*.lua`：状态类，列表见 `BuffPool.lua` 的 `tStatusBuff`。
  - `module/buff/xbasic/*.lua`：数值类，列表见 `tXbasicBuff`，约在 `:1000-1133`。
- 加载时生成 `gBuffRule["BF"..Name] = rule_id`（`BuffPool.lua:1137-1147`）。
- 子类只需要重写 `setLogicEnter`、`setLogicExit`、`setLogicUpdate`、`setLogicOnBegin`、`setLogicOnEnd` 几个钩子（`BuffBase.lua:596-618`），例如：
  - `BuffSuperArmor`：在 `setLogicEnter` 里 `addExtraState(SuperArmor)` 并增加引用计数，在 `setLogicExit` 里减引用，计数归零时移除状态。
  - `BuffStun`：进入时加 Stun，调用 `forcedInterrupt`，速度缩放设为 0；退出时恢复移速。
  - `BuffBurn`：进入时调用 `dealBuffDamage`。

### 11.2 创建：`BuffPool:addBuff`（`BuffPool.lua:380-459`）

1. 实体 `logicEnable=false` 时返回。
2. `buffCheck`（`:369`）要求以下四项都不成立：
   - 被免疫：`tBuffImmunePool[rule]` 存在，或 `[-1]` 存在（全免）。
   - 该 buff id 还在 CD 中。
   - 身上有 `BFImmuneDebuff` 且本 buff 的 `buff_type` 为 3 或 4。
   - `area_setting` 场景过滤不通过。
3. 概率：`probability`；若开启 `probability_repeat`，则为 `probability × 已有层数`。满足 `GRandomF(0,100) < p` 才继续。
4. 查找同 `(rule_id, sub_type)` 的已有 buff：
   - **不存在，或 `sub_type==-1`**：`new(class_name):init(pool, entity, id)`，依次设置绑定技能、前置技能、施加者 tag、施加者技能 tag、来源和神器信息，放进池里，再调用 `setExecute()`。
   - **已存在**：仅当 `old.priority <= new.priority` 时执行 `buff:reset(newData)`，这就是**叠加和刷新**（§11.4）。
5. `cd`（或 `cd_pvp`）不为 0 时记录 buff CD；随后触发 `ADD_BUFF`。

**`init`**（`BuffBase.lua:102-144`）：
- `began` / `ended` 两个字段映射到事件回调 `onBeginEvent` / `onEndEvent`。
- 读取 `param_value`、`param_value2`、`condition_param`、`interval`、`times`、`repeat_max`、`inner_cd`、`binding`、`destroy_type`。
- 创建 spine 并挂到角色的 buff 节点（`enter`，`:505`）。

**`setExecute`**（`:408`）按 `execute_type` 分三种：
- 1：立即激活，并执行 `onEvent(ENTER)`，也就是 `setLogicEnter`。
- 2：激活，但等间隔或次数到了才执行。
- 3：不激活，要等某个事件触发才激活。

### 11.3 每帧 tick：`BuffBase:update`（`:217-267`）

BuffPool 每帧遍历所有 buff，删除已 `bDestroy` 的，然后调用 `setBuffCd`（`:121-139`）。**计时单位是秒**（直接累加 `delta`）。

每个 buff 的 update：
1. 实体已死亡、`iRepeat==0`、未激活或已退出时，跳过。
2. 按 `times` 和 `interval` 分支：

| times | interval | 行为 |
|---|---|---|
| -1（无限） | >0 | 每隔 `interval` 秒执行一次 `ONCE_UPDATE`，即 `setLogicUpdate`；若配置了 `inner_cd` 会再节流 |
| -1 | 0 | 每帧执行 `ONCE_UPDATE` |
| 0 | >0 | 纯持续时间：到 `interval` 时 `removeRepeat()` 去掉一层 |
| >0 | >0 | 每 `interval` 秒执行一次 `ENTER`，`iTimes++`；`iTimes >= times` 时 `removeRepeat()` |
| >0 | 0 | 每帧执行 `ENTER`，满次数后移除一层 |
| times<-1 或 interval<0 | — | 不 tick |

**事件触发** `BuffPool:trigger(event, param)` 会广播给每个 buff 的 `trigger`（`BuffBase.lua:151-202`）。buff 只响应自己的 `began` / `ended` 事件，并且：
- `event_param[1]` 用于过滤目标。0 表示不过滤；`TargetSelf` 要求目标是自己；其它值要求 `targetCamp` 等于该值。
- `binding=1` 时，要求 `skillInfo.skillId == 绑定技能 id`，也就是技能专属 buff。
- 满足条件后记录目标、技能、TP 等上下文，处理 `bind_special_ability_id`，把 `bActivation` 置为 true，再调用回调。
- `onBeginEvent`（`:575`）：`checkCondition`（即 `BuffConditionCheck`，`module/buff/BuffCondition.lua`）通过后执行 `setLogicOnBegin`；若 `event_param[2]==1` 且没有配 `ended`，执行完就 exit（一次性）。

完整事件表见 `BuffPool.lua:2-75`（BFEvent）。本文提到的触发点汇总如下：
- PREPARESKILL、CASTSKILL：§5–6
- HIT、TOBEHIT：§8
- COLD_START、COLD_END：§6.3
- HP_CHANGE、BEFORE_DEATH：§9.1
- CRAZY：§1.2
- ROLE_SKILL_ACTION：§7
- BEHAVIOR_STATE_START、BEHAVIOR_STATE_END：每个行为树叶子的 enter / exit，只转发给 `BFAddByState`（`BuffPool.lua:609`）

### 11.4 叠加与重置：`reset(buffData)`（`BuffBase.lua:337-406`）

| reset_type | 层数 | times 计数 | interval 计时 |
|---|---|---|---|
| 0 | 不变 | 不变 | 不变 |
| 1 | 不变 | 重置 | 重置 |
| 2 | 不变 | 重置 | 不变 |
| 3 | 不变 | 不变 | 重置 |
| 4 | +1 | 不变 | 不变 |
| 5 | +1 | 不变 | 重置 |
| 6 | +1 | 重置 | 不变 |
| 7 | +1 | 重置 | 重置 |

- 层数 +1 通过 `addRepeat()` 完成，上限为 `repeat_max`（`:270`）。
- 如果新旧 buff 的 id 不同，先对旧 buff 执行 `setLogicExit`，再在后面对新数据执行 `setLogicEnter`。护盾每次都会重新执行 enter，也就是重设护盾值。
- 持续伤害类（`buff_rule.buff_type==1`）重置时，只有当剩余次数少于新值时才采用新的 times 和 interval。

### 11.5 移除

- `removeRepeat(removeAll, delCount, isForce)`（`:292`）：每去掉一层执行一次 `onEvent(EXIT)`，即 `setLogicExit`。`remove_repeat_all=1` 时一次去掉所有层。层数为 0 时调用 `exit()`。
- `exit()`（`:540`）：有消失动画时先播放动画，播完后再销毁；否则直接 `bDestroy=true` 并执行 `EXIT`。
- `BuffPool:removeBuff(id, removeAll)`（`:534`）：只剩一层时直接 exit，否则 `removeRepeat`，然后触发 `REMOVE_BUFF`。
- 还有 `destroyBuff`（`:557`，退出场景时用）和 `destroyBuffByRule`（`:576`）。
- 另有几种按规则移除的 buff：`BuffRemoveById`、`ByRule`、`ByType` 等。

### 11.6 谁会挂 buff

| 来源 | 位置 |
|---|---|
| 角色自带、芯片、养成、额外 | `BuffPool:loadBuffs`（`:152`），`EntityRole:addExtBuff`（`EntityRole.lua:3778`） |
| 房间 | `FightScene:processRoomBuff`（`FightScene.lua:1424`，`actor_buff_ids`） |
| 动作期间 | `action_attack.buff_ids`（§7.1） |
| 特效命中 | `entity_effect.buff_id`（给自己）、`buff_all_id`（给友方）、`debuff_id`（给敌方）（§8.2） |
| 系统 | 起身保护 156、白框 154、浮空保护 155、受击保护 173、Wake 无敌 201（§10），狂暴（§1.2），拾取掉落物（`EntityGoods.lua:153`） |
| Buff 自己 | `BuffAddBy*` 系列，例如 Applicator、State、Counter、Detector，由事件或条件触发再挂新 buff |
| 特殊能力 | `SpecialAbilityPool`（`module/specialAbility/`），`buff_base.bind_special_ability_id` 可以反过来挂特殊能力 |

`addEntityBuff(id, bindSkill, source)`（`BuffPool.lua:316`）按 `buff_base.target` 分派到 Self、TeamMember、EnemyCamp、Boss、MonsterElite 或 WholeCamp。`addBuffForApplicator`（`:887`）还支持 TargetEnemy、TargetTeammate、TargetSelf，这几种需要传入 targetTag。

---

## 12. 位移

实现在 `module/component/ComponentDisplacement.lua`，数据来自 `action_displacement`。`setDisplacementData`（`:548-601`）写入以下初始值：
- **速度**：`vel = (vectorX×velocity[1], velocity[2], vectorZ×velocity[3])`，其中 x、z 两个分量要乘朝向符号，写入实体的 ForceVelocity。
- `tVelocityTime = velocity_time[3]`：各轴匀速段的时长（毫秒）。-1 表示无限；0 表示不移动。
- `tAcceleration` 和 `tAccelerationTime`：各轴的加速度，以及加速持续的时长。
- `iGravity = gravity`：0 或 1。角色重置后默认为 1，特效默认为 0。
- `fBounces = bounces`：落地反弹系数。
- **追踪位移**（`is_trace > 0`，只对角色生效）：用 `findTargetInSector(radius, angle)` 找目标，按 `trace_velocity` 计算直线飞向目标的速度，z 分量要除以 ZRATE。

每帧 `updateLogicDisplacement`（`:144-291`）的计算：
- 时间：`dt = delta×1000×动作速率`；`fUpdateTime` 按 dt 累加。
- x、z 轴（`calculateVelocity`，`:394`；`calculateDisplacement`，`:447`）：
  - 在加速时间内，`v += vector×a×dt`。
  - 位移取梯形积分：`offset = 0.5×(v0+v1)×t_acc + v1×(dt−t_acc)`。
  - 超过 `velocity_time` 后速度归零。
  - `velocity_time==-1` 时一直按这条式子计算。
- y 轴（`calculateGravity`，`:417`）：`v += a×dt`；除非 `y==0 且 v==0`，否则 `v += iGravity × GRAVITY × delta`，其中 `GRAVITY = -0.0022`（`imports/Const.lua:207`）。
- z 轴的位移最后再乘 `ZRATE = 0.55`（`:515`），这是纵深方向的透视压缩。
- 禁锢类状态（`getCannotMove`）会把 x、z 的加速度乘以 VelocityScale；y 不受影响，以保证被定住的角色仍能落地。

**事件**（回调给当前动作叶子；叶子返回 true 表示"我处理了，不要做默认修正"）：

| 事件 | 条件 | 默认处理 |
|---|---|---|
| `brake` | 三个方向速度都为 0 | — |
| `air` | y>0 且 vy<0（开始下落） | — |
| `floor` | y<0 且 vy < -BOUNCES(0.2) 且 `fBounces>0` | 未被处理时反弹 `vy = -vy×fBounces`；被处理时速度清零 |
| `lie` | 落地且速度小于阈值，或原本就在地面且 vy==0 | 速度清零，y 置为 0 |
| `left` / `right` / `top` / `bottom` | 用半径探测点 `pos ± radius` 查 `MapRegion` 边界 | 未被处理时贴墙：`x = left+radius` 等 |

- 撞墙检测的顺序：位移量较大的轴先检测（`:258-267`）。
- 主城和营地使用 `correctEntityPosition`，走另一套逻辑。
- 最后把 `offset` 写成实际位移（`setOffset`），供障碍物修正使用。障碍物的修正在 `EntityRole:dealWithObsturct`（`EntityRole.lua:2024`）：按包围盒把角色推回障碍物的 x 边界；若角色在障碍物 x 范围内，就把 z 推到 `obstacle.z ± (r1+r2)`。

角色之间不做推挤（除非 `Jostled` 传送门推开），靠 Z 深度和半径来判定碰撞。

绘制插值：`draw`（`:293`）在 60Hz 下用 `ForecastPosition` 朝逻辑位置平滑追赶，只影响表现，不影响逻辑。

---

## 13. 镜头、冻结（hitstop）与联机同步

### 13.1 三种"停顿"

| 机制 | 触发 | 作用范围 | 实现 |
|---|---|---|---|
| **顿帧 freeze** | `skill_hit.freeze_time*`（§10.1） | 单个实体：攻击者、特效、受击者分别控制 | `fFreezeTime`（毫秒）；`EntityBase:update` 在冻结期间跳过行为树和组件（`EntityBase.lua:168`）；特效见 `EntityEffect.lua:282-286` |
| **定身 static** | `action_attack.static_target`（`AttackRole.lua:568`） | 0：只有敌方；1：自己 + 敌方阵营，持续 `static_time`；2：同 1，但时长为 `display_spine_frame_count` 帧 | `fStaticTime`；判定方式同 freeze。`static_reset_time` 之后才允许再次触发 |
| **必杀演出** | `display_spine_frame` / `display_spine_ids` | 全屏 UI spine（双层数组，按组依次播放） | `CameraFreeze`（`module/camera/CameraFreeze.lua`）只负责播放，**不暂停逻辑**；暂停靠 `static_target=2` 配合 |
| **慢放** | Boss 全灭 KO（`FightScene:executiveKO`） | 整个地图 | `CameraSlow`（`module/camera/CameraSlow.lua:25-77`）：0.5 秒内从 1 降到 0.1，保持 1 秒，再用 1 秒恢复到 1。`MapManager:update(delta×SlowScale)` 缩放逻辑 delta |

- 震屏：`CameraManager:startShaker(camera_id)`（`module/camera/CameraManager.lua:71`）。只有当前没在震、或新震屏的 `level` 更高时才会替换。
- 镜头跟随：`updateFocus` / `updateView`，都在绘制帧里执行（`:143-156`）。

### 13.2 帧同步（`module/sync/SyncManager.lua`）

- 服务器按 30 帧每秒推送 `FightFrameOperatesInfo`，里面包含 `frame_id`、`time_passed`、`role_updates[{role_id, action_infos[{event_type, control_params{quadrant, angle×1000, press_type}, cur_frame, role_hp}]}]`。
- 客户端的更新模式（`eUpdateMode`）和释放帧策略见文件头注释 `:12-23`。默认策略 2 是"逐步追帧"：积压帧越多，一次释放的帧越多。

流程：
1. **上传**：`ControlManager` 的输入在 `checkSwallowControl` 被截获，`collectInputControl`（`:504`）按 `cur_frame = iSyncFrame-1` 打包，附带本地 HP 快照。`update` 在逻辑前或逻辑后（`eUploadOperateMode`）调用 `uploadControl`，**每帧至少上传一个空操作**（`:442-479`）。
2. **下发**：`addOutputControl`（`:405`）把收到的帧放进待执行队列。正在处理帧时，或 `frame_id` 超前时，先放进缓存。
3. **执行**：`processSyncFrame`（`:278-330`），每帧执行 `fixFrameLen` 个同步帧，每个同步帧：
   - `executeFrameOperate`（`:359`）：把每个角色的操作用 `role:addControlEvent(event, params)` 放进控制事件队列（`EntityBase.lua:950`）。这些事件要等 `EntityBase:update` 里才被消费，所以本地输入和远端输入都是**延迟到同步帧才生效**。
   - `saveRoleHpWithFrame`，`iSyncFrame++`。
   - `handler(delta)` 即 `LayerMap:updateMap`，推进一次完整的逻辑帧。
   - 一次追多帧时，额外调用一次 `LogicTimerTrigger:update`。
4. **校验**：`checkHp`（`:698`）比较本地和远端在同一帧的 HP；结束时上报 SYNCSEED 日志的 MD5（`:689-694`）。

确定性要点：
- 随机数只用 `AEUtil:GRandomF/N`，种子来自 `setSyncBegin(…, randomSeedArr)`（`:586`）。
- 所有累加都经过 `AEUtil:FixPoint`。
- 碰撞在注册的同一帧不生效（§8.1）。
- 定时器统一用 `REGLOGICTIMER`，同步第 1 帧时重置（`:284`）。
- 回放工具：`tool/NetworkFightPlayback/`。
- 网络层（`src/net/`）只负责收发 protobuf，与战斗逻辑无关。

---

## 14. 端到端示例：一次普攻从按下到掉血

以玩家单机按 J 键为例，普攻槽为 `"A"`，第 1 段的 action 带一个特效，特效的 `hit_id` 指向击退命中。

```
[帧 N 逻辑帧开头] ControlManager:update / onKeyPressed
  KeyCodeAttack → CTR_ATKA → onControlEvent(:804) → dealWithJoyStick(无搓招) → checkSwallowControl=false
  → EntityManager:onControlEvent(:2081) → EntityRole:dealWithEvent(:2131)
  → dealButtonEvent(:2359) → SkillPool:dealWithButton(:268) slot="A"
  → presetSkill("A")(:361): getFightSkill → tPool["A"][1][1][1]; isAllowCast ✓ (CD/TP/EP/沉默/眩晕)
     → BEFORE_PREPARESKILL；pSkillBase==nil → setSkillBase(skill)
  → dealWithStatus(Attack) : eEntityStatus |= Attack
[帧 N MapEntity → EntityManager:update → EntityRole:update → EntityBase:update]
  ROLE 树选中攻击分支 → ConditionAttackSlot("A") → Step(1,1,1) → Pipe(1)
   Pipe:enter → dealWithCastPipeBegan → castBegan: 进 CD、扣 TP/EP、选方向 action_ids[1]
             → BEFORE_CASTSKILL (buff/SA)
   → ConditionAttackVectorIndex(1) → AttackRole(action_ids[1][1]):enter
      播动作; setDisplacement(前冲); 动作 buff_ids 生效; setAllowInterrupt(false)
[帧 N+k] AttackRole:execute: fTime >= fInterval×effect_frames[1]
   → EntityManager:addEffect → setCustomPosition → setSkillInfo → effect:enter (注册 AECollider)
[帧 N+k+1] 特效 update: EFFECT 树 AttackEffect 播放、特效位移；ComponentCollision 更新 spine 包围框
   本帧末 AECollision:update → ComponentCollision:dealWithCollision (Z 深度过滤, 接触点)
   → EntityEffect:onCollisionEvent (敌方) → dealWithHitX(:721)
      去重/间隔 ✓ → skillDodge ✗ → 属性闪避 roll ✗
      → dealWithBeHitBefore ✓ (BEFORE_TOBEHIT)
      → 攻击者 dealWithHitBegan (BEFORE_HIT)
      → 受击者 dealWithBeHitBegan: calculateDamage → modifyHp(-hurt) (护盾/锁血)
           顿帧: 攻击者/特效/受击者 setFreezeTime(freeze_time)
           转向、fStiffTime=stiff_time；forcedInterrupt()；dealWithStatus(Hit, hit_id)
      → dealWithBeHitEnded: 伤害数字、连击、受击回 EP、AFTER_TOBEHIT
      → 攻击者 dealWithHitEnded: 命中回 EP、AFTER_HIT
      → 受击特效 hit_effect_ids；再由 effect.debuff_id 给受击者挂 buff
[帧 N+k+2 …] 攻击者和受击者都在 freeze 中，EntityBase:update 被短路（buff/CD 照走）
[freeze 结束] 受击者 ROLE 树进入 Hit 分支 → ActionHit: hit 动画 + 击退位移
   → 动画完 + brake + fTime>=stiffTime → HitSwitch → Idle
   攻击者 AttackRole 到 interrupt_frame: 若已按第二下(缓存 pNextSkillBase=A 段2) → dealWithNextSkillBase
   → AttackRole Success → Pipe:exit(AFTER_CASTSKILL, castEnded) → ROLE 树匹配 Step(A,2,…) 继续
   否则动画完 + action_delay_time → 序列结束 → 攻击分支结束 → Attack 位清除、pSkillBase=nil (见 §6.2 未确认处)
```

联机时，第一段改为：上传后等服务器回包，在 `processSyncFrame` 中执行 `addControlEvent`，然后在该同步帧的 `EntityBase:update` 里调用 `dealWithEvent`。其余步骤相同。

---

## 15. 函数索引

| 函数 | 位置 | 一句话 |
|---|---|---|
| `EntityManager:update` | module/entity/EntityManager.lua:229 | 按组更新实体，处理销毁、预加载回收和 BufferList |
| `EntityManager:addRole` | module/entity/EntityManager.lua:621 | 创建角色并加入逻辑列表 |
| `EntityManager:addEffect` | module/entity/EntityManager.lua:1094 | 创建特效，优先从预加载池取 |
| `EntityManager:onControlEvent` | module/entity/EntityManager.lua:2081 | 单机输入入口，转给控制角色 |
| `EntityBase:update` | module/entity/EntityBase.lua:167 | freeze/static 短路 → 控制事件 → 行为树 → 组件 |
| `EntityBase:addControlEvent` | module/entity/EntityBase.lua:950 | 联机输入入队 |
| `EntityRole:init` | module/entity/EntityRole.lua:536 | 组装组件、池、行为树和 AI |
| `EntityRole:load` | module/entity/EntityRole.lua:883 | 加载属性、技能和 buff |
| `EntityRole:update` | module/entity/EntityRole.lua:1049 | 角色每帧逻辑（§1.2） |
| `EntityRole:getStiffTime` | module/entity/EntityRole.lua:1224 | 硬直按 fatigue 递减 |
| `EntityRole:calcShieldAndHp` | module/entity/EntityRole.lua:1482 | 护盾吸收 |
| `EntityRole:modifyHp` | module/entity/EntityRole.lua:1510 | 扣血和回血总入口，含死亡处理 |
| `EntityRole:isRigidity` | module/entity/EntityRole.lua:1762 | 浮空值是否耗尽 |
| `EntityRole:isTobeHitStatus` | module/entity/EntityRole.lua:1842 | 是否处于任一受击状态 |
| `EntityRole:dealWithObsturct` | module/entity/EntityRole.lua:2024 | 障碍物推回 |
| `EntityRole:dealWithStatus` | module/entity/EntityRole.lua:2055 | 状态切换规则 |
| `EntityRole:dealWithEvent` | module/entity/EntityRole.lua:2131 | 控制事件分派 |
| `EntityRole:dealButtonEvent` | module/entity/EntityRole.lua:2359 | 攻击键 → SkillPool |
| `EntityRole:dealWithWeight` | module/entity/EntityRole.lua:2413 | 扣浮空值，耗尽后加速下落，加保护 buff |
| `EntityRole:dealWithFreeze/Static` | module/entity/EntityRole.lua:2436/2441 | 顿帧和定身计时 |
| `EntityRole:dealWithCrazy` | module/entity/EntityRole.lua:2464 | 曝气期间扣 EP |
| `EntityRole:forcedInterrupt` | module/entity/EntityRole.lua:2787 | 打断当前技能 |
| `EntityRole:checkHurtPermit` | module/entity/EntityRole.lua:2801 | hit_restrain 伤害许可 |
| `EntityRole:setSkillBase` | module/entity/EntityRole.lua:2828 | 设置当前技能，关闭中断 |
| `EntityRole:skillDodge` | module/entity/EntityRole.lua:2979 | 无敌与闪避技能免疫 |
| `EntityRole:dealWithBeHitBefore` | module/entity/EntityRole.lua:3039 | 命中条件判定 |
| `EntityRole:dealWithBeHitBegan` | module/entity/EntityRole.lua:3129 | 伤害、扣血、顿帧、硬直、进入受击 |
| `EntityRole:dealWithBeHitEnded` | module/entity/EntityRole.lua:3291 | 伤害数字、连击、受击回 EP |
| `EntityRole:dealWithHitEnded` | module/entity/EntityRole.lua:2932 | 攻击方回 EP，AFTER_HIT |
| `EntityRole:dealBuffDamage` | module/entity/EntityRole.lua:3344 | DOT 扣血 |
| `EntityEffect:init` | module/entity/EntityEffect.lua:62 | 特效组装；有 hit_id 才加碰撞 |
| `EntityEffect:update` | module/entity/EntityEffect.lua:274 | 命中间隔、冻结、跟随、next 特效 |
| `EntityEffect:onCollisionEvent` | module/entity/EntityEffect.lua:348 | 按敌方、友方、障碍物分派 |
| `EntityEffect:dealWithHitEffect` | module/entity/EntityEffect.lua:401 | 生成受击特效 |
| `EntityEffect:dealBuff` | module/entity/EntityEffect.lua:506 | 特效挂 buff |
| `EntityEffect:dealWithHitCondition` | module/entity/EntityEffect.lua:633 | 按命中次数自毁 |
| `EntityEffect:dealWithHitX` | module/entity/EntityEffect.lua:721 | 单次命中的完整流程 |
| `ComponentCollision:dealWithCollision` | module/component/ComponentCollision.lua:82 | Z 深度过滤和碰撞状态机 |
| `ComponentDisplacement:updateLogicDisplacement` | module/component/ComponentDisplacement.lua:144 | 速度积分、重力、落地、撞墙事件 |
| `ComponentDisplacement:setDisplacementData` | module/component/ComponentDisplacement.lua:548 | 载入 action_displacement，含追踪位移 |
| `SkillPool:loadSkill` | module/skill/SkillPool.lua:57 | 构建技能池和攻击子树 |
| `SkillPool:dealWithButton` | module/skill/SkillPool.lua:268 | 按键 → slot 修正（冲刺、搓招、曝气） |
| `SkillPool:presetSkill` | module/skill/SkillPool.lua:361 | 立即替换或缓存下一招 |
| `SkillPool:dealWithCastPipeBegan/Ended` | module/skill/SkillPool.lua:555/596 | 技能开始和结束的钩子 |
| `SkillPool:getFightSkill` | module/skill/SkillPool.lua:1016 | 连携推进 |
| `SkillPool:forcedInterrupt` | module/skill/SkillPool.lua:187 | 清理技能和特效 |
| `SkillBase:update` | module/skill/SkillBase.lua:229 | CD 与次数恢复 |
| `SkillBase:isAllowCastInternal` | module/skill/SkillBase.lua:424 | 能否释放 |
| `SkillBase:isPriority / isSuperPriority` | module/skill/SkillBase.lua:502/515 | 打断优先级 |
| `SkillBase:dealWithNextSkillBase` | module/skill/SkillBase.lua:561 | 切换到缓存的下一招 |
| `SkillBase:dealWithDirection` | module/skill/SkillBase.lua:597 | 8 方向选 action 组 |
| `SkillBase:castBegan` | module/skill/SkillBase.lua:818 | CD、消耗、事件 |
| `SkillAi:check` | module/skill/SkillAi.lua:44 | AI 施法闸门 |
| `SkillHurt:calculateDamage` | module/skill/SkillHurt.lua:108 | 技能伤害公式 |
| `SkillHurt:calculateBuffDamage` | module/skill/SkillHurt.lua:82 | buff 伤害公式 |
| `ActionAttack:onDisplacementEvent` | module/behaviortree/actions/ActionAttack.lua:73 | 攻击动作对撞墙和落地的处理 |
| `AttackRole:enter/execute/exit` | module/behaviortree/actions/AttackRole.lua:180/349/302 | 施法叶子 |
| `AttackRole:dealWithInterrupt` | module/behaviortree/actions/AttackRole.lua:390 | 中断帧与接招 |
| `AttackRole:dealWithEffect` | module/behaviortree/actions/AttackRole.lua:487 | 按帧生成特效 |
| `AttackRole:dealWithStatic` | module/behaviortree/actions/AttackRole.lua:568 | 定身 |
| `AttackEffect:execute` | module/behaviortree/actions/AttackEffect.lua:145 | 特效动作、子特效、召唤 |
| `ActionHit / HitUp / HitDown / HitFloor` | module/behaviortree/actions/ActionHit*.lua | 受击叶子与追击 |
| `ActionGetUp / ActionWake` | module/behaviortree/actions/ActionGetUp.lua:4 / ActionWake.lua:4 | 起身与无敌窗口 |
| `ActionCanBreakBase:execute` | module/behaviortree/actions/ActionCanBreakBase.lua:17 | 挣脱检测 |
| `BuffPool:addEntityBuff` | module/buff/BuffPool.lua:316 | 按 target 分派 |
| `BuffPool:addBuff` | module/buff/BuffPool.lua:380 | 创建或叠加 buff |
| `BuffPool:removeBuff` | module/buff/BuffPool.lua:534 | 移除一层或全部 |
| `BuffPool:addBuffForApplicator` | module/buff/BuffPool.lua:887 | 带施加者信息的分派 |
| `BuffBase:trigger` | module/buff/BuffBase.lua:151 | 事件过滤与回调 |
| `BuffBase:update` | module/buff/BuffBase.lua:217 | interval 和 times 的 tick |
| `BuffBase:reset` | module/buff/BuffBase.lua:337 | reset_type 规则 |
| `BuffBase:getAttackValue` | module/buff/BuffBase.lua:984 | DOT 数值 |
| `FightScene:handleLoadMonster` | scene/FightScene.lua:566 | 刷怪 |
| `FightScene:updateCheckResult` | scene/FightScene.lua:879 | 胜负检查 |
| `FightScene:checkWipeOutEnemys` | scene/FightScene.lua:1250 | 清场判定 |
| `FightScene:executiveKO` | scene/FightScene.lua:1473 | Boss 全灭后慢放 |
| `GameScene:updateCheckRoom` | scene/GameScene.lua:286 | 房间状态机推进 |
| `PlotScene:checkPassRoom` | scene/game/PlotScene.lua:432 | 按 battle_rule 判胜 |
| `PlotScene:startHandleTurnMonster` | scene/game/PlotScene.lua:356 | 防守关下一波 |
| `StageHelper.createRoomModel` | helper/StageHelper.lua:86 | 房间模型与波次 |
| `ControlManager:dealWithJoyStick` | module/touch/ControlManager.lua:711 | 搓招识别 |
| `ControlManager:onControlEvent` | module/touch/ControlManager.lua:804 | 输入出口（同步截获） |
| `AiAgent:executeAttack` | module/ai/AiAgent.lua:~400 | AI 和自动战斗选技能 |
| `CameraManager:startShaker / startFreeze / startSlow` | module/camera/CameraManager.lua:71/87/109 | 震屏、必杀演出、慢放 |
| `SyncManager:processSyncFrame` | module/sync/SyncManager.lua:278 | 执行同步帧 |
| `SyncManager:executeFrameOperate` | module/sync/SyncManager.lua:359 | 操作 → addControlEvent |
| `SyncManager:collectInputControl / uploadControl` | module/sync/SyncManager.lua:504/442 | 采集和上传本地操作 |

