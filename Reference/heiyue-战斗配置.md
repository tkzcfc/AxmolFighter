# heiyue 战斗配置表参考

> 对象：`heiyue/src/imports/table/*.lua`（只读参考源）。
> 路径约定：文中 `path:line` 都相对 `heiyue/src/`。行号取自当前仓库快照。
> 标记：**未使用** 表示在 `imports/table` 之外 grep 不到读取点；**未确认** 表示有同名读取，但无法确定读的就是这张表，或语义没法从代码里确定。
> 源码是 UTF-8 编码。PowerShell 下用 `Get-Content -Encoding utf8` 读。

---

## 0. 怎么读表

### 0.1 文件格式

每张表都是一个 Lua 模块，`return <表名>`。有两种写法：

1. **加密格式**：绝大多数战斗表都是这种，例如 `skill_*`、`action_*`、`buff_base`、`entity_*`、`map_room*`、`map_stage`。
   - 文件开头是一串共享子表 `local __rtN = { __real_value = { [1] = HACKER_DATA_INIT(0), ... } }`，用来给重复出现的数组去重。
   - 行定义写成 `[id] = { __real_value = { field = HACKER_DATA_INIT(v), ... } }`。**每行只写与默认值不同的字段**。
   - 文件末尾有 `local __default_table = {...}`，后面跟一个 `do ... end` 块。这个块遍历所有行，把缺失的字段补成默认值，并调用 `HACKER_SET_MT`（例如 `imports/table/skill_hit.lua` 的末尾约 40 行）。**所以 `__default_table` 就是这张表的完整字段清单。**本文的字段表就来自这里。
2. **明文格式**：`buff_rule`、`skill_leaf`、`skill_tree`、`skill_chip`、`skill_rock`、`item_buff`、`attribute_change`、`entity_obstacle`、`entity_goods`、`config_pvp_ai` 等是普通 Lua 表，但同样带 `__default_table` 补全。

`HACKER_DATA_INIT` 是一层防内存篡改的数值包装：
- 定义在 `hacker/HData.lua:112`，内部是 `HData:create`。
- `HData:set`（`hacker/HData.lua:59`）把值存成 `v*100000 - random factor`；`HData:get`（约 `:82`）再还原。
- 表的元表是 `HACKER_MT`（`hacker/HData.lua:260`），它的 `__index = getFunc` 会自动调 `:get()`。
- 全局的 `pairs`/`ipairs` 被重写，会穿透 `__real_value` 并解包 HData（`hacker/HData.lua:1-40`）。

业务代码因此可以直接写 `data.field`，读到的就是明文数值。

加载入口：
- `main.lua:200` 定义 `loadlua(path)`，实现为 `package.loaded[path]=nil` 再 `require`。
- 表目录由 `imports/_init.lua:3` / `main.lua:13` 的 `addSearchPath("src/imports/table")` 加入。
- 所有 DB 模块在 `db/_init.lua:2-31` 里加载。

**Config 平铺副本**：`AxmolFighter-Config/table/*.lua` 是转换后的明文副本，字段改成了 camelCase，默认值已经展开，部分表做了合并或改名。本文的示例行多取自这份副本，便于阅读，但仍按原字段名书写。已核对的对应关系如下：
- `skill.lua` ↔ `skill_attack`，多了一个派生字段 `primaryActionIds`，原表没有。
- `action.lua` ↔ `action_attack`
- `effect.lua` ↔ `entity_effect(+2)`
- `role.lua` ↔ `entity_role`
- `ai.lua` ↔ `entity_ai`
- `attribute.lua` ↔ `entity_attribute`
- `displacement.lua` ↔ `action_displacement`
- `camera.lua` ↔ `action_camera`
- `buff.lua` ↔ `buff_base`
- `stage.lua` ↔ `map_stage`，并附加了 `mapKey`
- `room.lua` ↔ `map_room/2/3` 合并，并附加了 `mapKey`

`action_effect.lua` 与 `action_attack_effect` 的对应关系**未确认**：在其中查不到 920000，而原表里有这一行。

### 0.2 访问器（DB 层）

| 模块 | 装载的表 | 访问函数（path:line） |
|---|---|---|
| `DBSkill` (`db/DBSkill.lua:2-12`) | skill_ai, skill_hit, skill_hurt, skill_attack, skill_tree, skill_leaf, skill_chip, skill_rock, skill_recommend, skill_change_system | `getSkillChangeSystem:15`（缺行返回 `{}`）、`getRecommendById:19`、`getAiData:24`（已废弃）、`getAttackData:30`（已废弃）、`getLeafData:37`、`getHitData:41`、`getHurtData:47`、`getAiSkillData:53`、`getSkillData:58`、`getTreeData:64`、`getNodeData:68`、`getChipData:72`、`getRockData:76`、`getLeafIdBySkillId:80` / `getLeafBySkillId:92`（遍历 skill_leaf 反查） |
| `DBAction` (`db/DBAction.lua:2-8`) | action_attack, action_attack_effect, action_attack_effect2, action_camera, action_displacement | `getAttackData:10`、`getAttackEffectData:16`（**key ≥ 2000000 查 `_effect2`**）、`getCameraData:26`、`getDisplacementData:32` |
| `DBBuff` (`db/DBBuff.lua:2-5`) | buff_rule, buff_base | `getBuffRule:7`、`getBuffBase:12`、`getRuleIdByName:25`（`class_name → id`，反查表在 `:19-22` 构建） |
| `DBEntity` (`db/DBEntity.lua:2-14`) | entity_ai, entity_attribute, entity_effect(2), entity_goods, entity_npc, entity_obstacle, entity_pet, entity_role, entity_portal, entity_fight_value | `getAiData:44`、`getAttributeInit:49`（原始行）、`getAttributeData:55`（**按等级插值**，见 §4.4）、`getAttributeGroup:139`、`getEffectData:148`（**key ≥ 2000000 查 `entity_effect2`**）、`getGoodsData:158`、`getNpcData:163`、`getObstacleData:168`、`getPetData:173`、`getRoleData:178`、`getPortalData:184` |
| `DBMap` (`db/DBMap.lua:2-26`) | map_data, map_room/2/3, map_stage, map_chapter, map_copy, map_copy_main … | `getMapData:65`、`getRoomData:69`（**依次查 tRoom1..3，先命中者优先**）、`getStageData:77`、`getMainCopyData:87`、`getCopyData:116` |
| `DBAttributeChange` (`db/DBAttributeChange.lua`) | attribute_change | `getAttributeData:6`、`getAttributeByTypeAndId:14`、`getAttributeDataByJob:23`、`getChangeResult:39` |
| `DBSpecialAbility` (`db/DBSpecialAbility.lua:2`) | specialability_base | `getSpecialAbilityData:5` |
| `DBWorldConfig` (`db/DBWorldConfig.lua:3-11`) | world_config, config_pvp_ai … | `getAiByLvAndType:14` |
| `DBItem` (`db/DBItem.lua:16`) | item_buff 挂在 `tItemDB[9]`，skill_chip 挂在 `tItemDB[16]` | `getInfoByItemID:106`（按 item_base 的 id 区间分发） |

多数访问器还会顺带调两个校验函数：
- `HACKER_TABLE_DB_CHECK`（`hacker/HData.lua:190` 附近）：检查 `row.id == key`，不一致就上报作弊。
- `ATTACKDBCTCOLLECT`（`hacker/AttackDBCollect.lua:88`）：做访问统计。

### 0.3 ID 与取值约定

- **`-1` 表示空**：`DATA_NIL = -1`、`DATA_FALSE = 0`、`DATA_TRUE = 1`，见 `imports/Const.lua:805-809`。数组字段通常写 `{-1}` 表示空。
- **标量与数组混用**：同一字段有时是标量，有时是数组。读取方普遍先调 `Convert.ToTable(x)` 统一成数组，例如 `module/entity/EntityEffect.lua:486`。
- **拆表规则**：
  - `action_attack_effect` / `entity_effect` 在 id ≥ 2000000 时落到 `…2` 表。
  - `map_room` 分三张表：`map_room` 大致是 1–5 位 id，`map_room2`/`map_room3` 从 100000 起（例子见 §5）。`getRoomData` 按顺序查找。
- **entity_attribute 分段**：分段基址见 `module/entity/EntityAttribute.lua:103-119`。
  - 10000 + 等级：Hero
  - 70000 + 等级：Summon
  - 140000 + 等级：Monster，以及 Machine、矿、水晶、障碍物
  - 150000 + 等级：Elite
  - 160000 + 等级：Boss
- **时间单位**：ms，例如 `cd`、`stiff_time`、`freeze_time`、`hit_interval`、`velocity_time`。**帧**字段（`effect_frames`、`interrupt_frame`、`camera_frame`、`summon_frame` 等）要乘以 `fInterval = 1000*LOGIC_DT/aciton_scale_time`（`module/behaviortree/actions/AttackRole.lua:41`）。
- **方向相关的数组**：`[1]` 是 X，乘以实体朝向；`[2]` 是 Y（高度）；`[3]` 是 Z（纵深）。见 `module/component/ComponentDisplacement.lua:586-588`。

---

## 1. 技能

### 1.1 skill_attack（技能段）

用途：一个"技能步骤"。它挂到槽位上，按 `next_skill` 串成连段，每一步引用若干 `action_attack`。
- 主键：`id`，即 skill_id。
- 访问：`DBSkill:getSkillData`，调用点在 `module/skill/SkillPool.lua:771`、`module/entity/EntityRole.lua:3869`、`module/entity/EntityManager.lua:545`（预加载）。

| 字段 | 类型 | 含义 | 读取点 |
|---|---|---|---|
| id | int | 技能 id | — |
| action_ids | int[][] | `[toward][i]` 是 action_attack id。外层下标对应"朝向/方向输入索引"，由 `ConditionAttackVectorIndex` 与 `SkillManager:getSkillToward()` 比较；内层按顺序串行执行 AttackRole | `module/skill/SkillPool.lua:844-846,910`；`module/behaviortree/conditions/ConditionAttackVectorIndex.lua:37` |
| up_action_ids | int[][] | "抬起释放"时使用的动作组。`skill_type==1` 时，SkillPool 生成"抬起分支（up_action_ids）"和"按压分支（action_ids）"两路 | `module/skill/SkillPool.lua:868-870` |
| skill_type | int | 0 表示按下释放，1 表示抬起释放 | `module/skill/SkillBase.lua:143` |
| press_time | ms | 按压阈值 | `module/skill/SkillBase.lua:144` |
| next_skill | int | 下一步技能 id，`-1` 表示结束。SkillPool 递归建节点 | `module/skill/SkillPool.lua:811-812` |
| cd / pvp_cd | ms | 冷却。PVP 下取 pvp_cd | `module/skill/SkillBase.lua:186` |
| cd_count | int | 可连续释放的次数（管道数），`-1` 视为 1 | `module/skill/SkillBase.lua:172`；`module/skill/SkillPool.lua:832` |
| mp | num | MP 消耗 | `module/skill/SkillBase.lua:667` |
| ep | num | EP（曝气）消耗，会乘以缩放系数 | `module/skill/SkillBase.lua:672` |
| crystal | num | 水晶消耗 | `module/skill/SkillBase.lua:146` |
| rage | num | 怒气消耗 | `module/entity/EntityRole.lua:3871` |
| sorder | int | 打断优先级。`-1` 或 ≥ 当前技能的 order 时可以抢占 | `module/skill/SkillBase.lua:505-506` |
| sorder_control_type | int[] | 优先级控制类型 | `module/skill/SkillBase.lua:196` |
| skill_ai_id | int | 默认 skill_ai id | `module/entity/EntityRole.lua:3690` |
| icon / name_id / desc_id | — | 仅 UI 使用 | `cache/CacheOtherRole.lua:541-543` |
| type | int | **未确认**（grep 不到 `skillData.type` 的读取） | — |

交叉引用：`action_ids` → action_attack；`next_skill` → skill_attack；`skill_ai_id` → skill_ai；`skill_change_system.skill_id` → 本表。

示例（id=920000，一套普攻的第 1 段）：
```
action_ids={{920000,920010,920020}}, next_skill=920010, cd=0, cd_count=-1,
skill_ai_id=11, skill_type=0, sorder=50, sorder_control_type={0}, up_action_ids={{0}}
```

### 1.2 skill_hit（打击数据）

用途：描述特效命中后的受击表现和伤害倍率。
- 主键：`id`。
- 来源：`entity_effect.hit_id`。取用点在 `module/entity/EntityEffect.lua:70-71`、`module/skill/SkillHurt.lua:110`，受击行为节点也会读（`module/behaviortree/actions/ActionHit*.lua`）。

| 字段 | 类型 | 含义 | 读取点 |
|---|---|---|---|
| hit_type | int | 受击类型，交给受击行为树分派，例如 ActionHitUp/Down/Floor。`-1` 表示不触发受击 | `module/entity/EntityEffect.lua:769`；`module/behaviortree/actions/ActionHitUp.lua:74,84,89` |
| displacement_id | int | 普通受击位移 → action_displacement | `module/behaviortree/actions/ActionHit.lua` 等 |
| air_displacement_id | int | 空中受击位移 | `module/behaviortree/actions/ActionHitUp.lua:76`、`ActionHitFloor.lua:98`、`ActionHitDown.lua:80` |
| floor_displacement_id | int | 倒地受击位移 | 与 air 在同一组分支里读取（`module/behaviortree/actions/ActionHitFloor.lua` 附近），具体行**未确认** |
| hit_rigidity | num | 削减浮空值（配合 `entity_role.weight`） | `module/behaviortree/actions/ActionHitUp.lua:85`；`module/entity/EntityRole.lua:2417` |
| stiff_time | ms | 硬直/倒地时间，会乘以 `1+ADD_FLOOR_TM` | `module/entity/EntityRole.lua:3132,3238`；`module/behaviortree/actions/ActionHitFloor.lua:110,116` |
| freeze_time | ms | 顿帧时长 | `module/entity/EntityRole.lua:3131` |
| freeze_time_control_role / _effect | 0/1 | 顿帧是否作用于角色 / 特效 | `module/entity/EntityRole.lua:3134-3135` |
| freeze_time_delay | ms | 顿帧延迟 | `module/entity/EntityRole.lua:3136` |
| hit_condition | int | 命中条件，例如只打地面、只打空中 | `module/entity/EntityRole.lua:3041`；`module/entity/EntityObstacle.lua:207` |
| hit_interval | ms | 多段判定间隔，`-1` 表示只判一次 | `module/entity/EntityEffect.lua:277,639,732` |
| hit_counts | int | 最大命中次数或最大目标数 | `module/entity/EntityEffect.lua:640-646` |
| hit_must | 0/1 | 1 表示必中，跳过闪避，并可无视无敌 | `module/entity/EntityEffect.lua:754`；`module/entity/EntityRole.lua:2983,3052` |
| hurt_type | int | 0 物理（ATK/DEF），1 魔法（MATK/MDEF），2 自适应（取较高的攻击），3 真实伤害（rate=1） | `module/skill/SkillHurt.lua:116-128` |
| hurt_rate / pvp_hurt_rate | num | 技能伤害倍率。PVP 下取 pvp 值 | `module/skill/SkillHurt.lua:153` |

示例（id=920000，与 §1.1 同一套普攻）：
```
displacement_id=920000, air_displacement_id=920010, floor_displacement_id=920020,
freeze_time=20, hit_rigidity=1, hit_type=0, hurt_rate=0.3, pvp_hurt_rate=0.3,
hurt_type=0, stiff_time=100, hit_interval=-1, hit_counts=-1, hit_must=0
```

### 1.3 skill_hurt（等级基准伤害）

用途：按等级给出基准伤害。
- 主键：`id`，即等级。
- 访问：`DBSkill:getHurtData(lv)`。

| 字段 | 类型 | 含义 | 读取点 |
|---|---|---|---|
| hurt | num | 英雄的标准伤害 = ATK + hurt[lv]。怪物 HP 公式也会用到 | `module/skill/SkillHurt.lua:51`；`db/DBEntity.lua:93` |
| monster_hurt | num | 怪物的标准伤害 = BasicHurt + monster_hurt[floor(lv/10)] | `module/skill/SkillHurt.lua:61-63` |
| atk_standard / crit_standard / crit_damage_standard / dodge_standard | num | **未使用** | — |

示例：`id=1, hurt=800, monster_hurt=0, atk_standard=400, crit_standard=267, crit_damage_standard=267, dodge_standard=533`

### 1.4 skill_ai（技能 AI 条件）

用途：为每个技能设定 AI 释放条件。
- 主键：`id`。
- 来源：`skill_attack.skill_ai_id`、`entity_ai.skill_ai_ids`。
- 对象：`SkillAi`（`module/skill/SkillAi.lua`）。

| 字段 | 类型 | 含义 | 读取点 |
|---|---|---|---|
| load_cd | ms | 初次可用延迟 | `module/skill/SkillAi.lua:25` |
| check_cd | ms | 条件检查间隔 | `module/skill/SkillAi.lua:61` |
| use_count | int | 可用次数，`-1` 表示无限 | `module/skill/SkillAi.lua:24` |
| prob | 0–100 | 释放概率 | `module/skill/SkillAi.lua:76` |
| composition | int[2][] | 组合条件的两组下标（与/或组），具体语义见 SkillAi | `module/skill/SkillAi.lua:115-124` |
| opp_dis_x / opp_dis_z | [min,max] | 对手的 X/Z 距离窗口 | `module/skill/SkillAi.lua:145,157` |
| opp_status | int / int[] | 对手状态 | `module/skill/SkillAi.lua:169` |
| opp_combo | int | 对手连击数门槛 | `module/skill/SkillAi.lua:181` |
| opp_skill_id | int | 对手正在放的技能 | `module/skill/SkillAi.lua:201,216` |
| self_hp | [min,max]% | 自身血量区间 | `module/skill/SkillAi.lua:226` |
| self_status | int / int[] | 自身状态 | `module/skill/SkillAi.lua:235` |

示例：`id=1, check_cd=2000, load_cd=1000, composition={{6},{-1}}, opp_dis_x={100,400}, opp_dis_z={0,100}, prob=100, self_hp={0,100}, use_count=-1`

### 1.5 skill_leaf（技能树叶子节点）

用途：养成侧的"技能节点"，决定玩家带入战斗的技能。
- 主键：`id`，即 leaf_id。
- 访问：
  - `DBSkill:getNodeData`：`cache/CacheSkill.lua:496-530`、`helper/FightHelper.lua:54,88`
  - `DBSkill:getLeafData`：`module/entity/EntityRole.lua:3154`

| 字段 | 类型 | 含义 | 读取点 |
|---|---|---|---|
| skill_id | int | 基础技能 → skill_attack | `helper/FightHelper.lua:55,88`；`db/DBSkill.lua:86` |
| hurt_type | int | **战斗公式用**：1 表示按技能等级算加成，2 表示按人物等级（注意与 skill_hit.hurt_type 含义不同） | `module/entity/EntityRole.lua:3156-3160` |
| skill_damage_factor | num | 面板伤害系数，**仅 UI 显示**，不参与战斗公式 | `cache/CacheSkill.lua:513` → `ui/view/UiSkill/*` |
| upgrade_level_limit / overflow_level_limit / upgrade_level_step / upgrade_consume_factor | int | 升级上限、步长、消耗 | `cache/CacheSkill.lua:500-511` |
| unlock_role_level / unlock_leaf_ids / unlock_leaf_levels | — | 解锁条件 | `cache/CacheSkill.lua:503,518,526-529` |
| chain | 0/1 | 是否连携技 | `cache/CacheSkill.lua:621` |
| attack_type | int | 攻击类型，用于 UI | `cache/CacheSkill.lua:523` |
| chip_ids | int[] | 可装配的 skill_chip | 服务器下发时使用（`cache/CacheSkill.lua:2910-2915`） |
| video_id | int | 演示视频 | `cache/CacheSkill.lua:516` |
| partner_unlock / tag / skill_type / icon / name_id / desc_id | — | UI 或养成用。`partner_unlock` 在表外无读取，**未使用** | — |

示例：`id=0, skill_id=930160, skill_damage_factor=11.3, hurt_type=2, attack_type=1, chip_ids={51010,51011,51012}, unlock_role_level=1, upgrade_level_limit=1`

### 1.6 skill_tree / skill_chip / skill_rock / skill_recommend

**skill_tree**（主键 id，按职业划分）：
- `leaf_ids`、`leaf_buff_id`、`leaf_rub_id` 是树里包含的 leaf 集合（`cache/CacheSkill.lua:348-367`）。
- `profession_type`、`tree_type`、`profession_background`：`cache/CacheSkill.lua:340-342`。
- `leaf_rub_place`、`ui`：**未使用**。
- 示例：`id=1, leaf_ids={10010,...,10120}, leaf_rub_id={10110}, profession_type=1, tree_type=2`。

**skill_chip**（主键 id，同时是 `tItemDB[16]` 下的物品）：芯片或技能改造。
- `chip_type`：`EnumChipCategory`，其中 `Skill` 类型会用 `relate_id` 替换节点（`cache/CacheSkill.lua:2234-2236`）。
- `relate_id`：→ skill_leaf 或 skill_rock（搓招），见 `cache/CacheSkill.lua:2070`。
- `belong_leaf_id`、`belong_tree_id`、`belong_profession`、`lv_limit`、`automatic_learn`：`cache/CacheSkill.lua:802-817`。
- `sp`、`wr`、`tag`：**未确认**（有同名但无关的读取）。

**skill_rock**（搓招，主键 id）：
- `skill_id`：搓招技能 → skill_attack。
- `command_index`：搓招槽位序号 rockIndex，对应 ControlManager 的 `KeyCodeJoy[index]`，见 §8。读取点 `cache/CacheSkill.lua:2073,2253`。
- `commands`：UI 箭头序列（`ui/view/UiSkill/UiSkillChipSkillChipShowNew.lua:33`）。
- `skill_damage_factor`、`spine_id`、`spine_action`、`video_id`：用于 UI。
- 示例：`id=1100, skill_id=920201, command_index=4, commands={4,2,6}, skill_damage_factor=7.8`。

**skill_recommend**（主键 id）：`occupation`、`skill_leaf`、`skill_chip`、`rub_leaf`、`buff_leaf` 等字段描述推荐配置。访问器 `DBSkill:getRecommendById` 在全仓**没有调用方**，整张表**未使用**。

### 1.7 skill_change_system（技能变化）

用途：定义技能的变化规则。
- 主键：`skill_id`（行 key），指基础技能。
- 访问：`DBSkill:getSkillChangeSystem`，缺行时返回 `{}`。

| 字段 | 含义 | 读取点 |
|---|---|---|
| skill_new_id | 变化后技能 id。会反查 leaf，并据此生成额外的技能槽数据 | `scene/SceneFactory.lua:113-114` |
| skill_group | 大于 `EntitySkillGroup.Special(5)` 时新建一个技能组 | `scene/SceneFactory.lua:117,123-133` |
| skill_change | 大于 `EntitySkillChange.Joy(2)` 时，写到该技能条目的 `[skill_change]` 下标（3 表示怒气变身） | `scene/SceneFactory.lua:118,136-141` |
| skill_change_id / skill_change_time | 释放后切换 "当前技能变化" 以及持续时间 | `module/skill/SkillBase.lua:933-936` |
| skill_group_change_id / skill_group_time | 释放后切换技能组以及持续时间 | `module/skill/SkillBase.lua:924-927` |

示例：`[3500000] skill_new_id=3600000`。其余字段取默认值：`skill_change=3, skill_group=-1`。

---

## 2. 动作

### 2.1 action_attack（角色攻击动作）

用途：角色一次攻击动作的配置。
- 主键：`id`。
- 读取方：`AttackRole` 行为节点（`module/behaviortree/actions/AttackRole.lua:36` 调 `DBAction:getAttackData(parameter.actionId)`）和 `ActionAttack` 基类（`module/behaviortree/actions/ActionAttack.lua`）。

| 字段 | 类型 | 含义 | 读取点 |
|---|---|---|---|
| action | int | Spine 动画索引 | `module/behaviortree/actions/AttackRole.lua:220` |
| aciton_scale_time（原拼写） | num | 播放速率。`fInterval=1000*LOGIC_DT/scale` | `module/behaviortree/actions/AttackRole.lua:41,218` |
| loop | int | 1 表示单次；`-1` 表示无限，由位移结束；大于 1 表示循环 N 次 | `module/behaviortree/actions/ActionAttack.lua:59,76` |
| action_delay_time | ms | 动画结束后再等待的时间 | `module/behaviortree/actions/ActionAttack.lua:112` |
| displacement_id | int | 自身位移 → action_displacement | `module/behaviortree/actions/AttackRole.lua:231` |
| control / control_velocity | int / num | 摇杆控制模式：0 表示变换，2、3 表示速度控制 | `module/behaviortree/actions/ActionAttack.lua:123-147`；`AttackRole.lua:194` |
| obstruct / floor | int | 碰墙、落地时的处理 | `module/behaviortree/actions/ActionAttack.lua:81,96` |
| effect_ids / effect_frames | int[] | 在第 N 帧生成 entity_effect。两个数组长度必须一致 | `module/behaviortree/actions/AttackRole.lua:490-497` |
| extend_role_vec / custom_vec | int / vec3 | 为 1 时，特效方向改用 custom_vec | `module/behaviortree/actions/AttackRole.lua:509-515` |
| buff_ids | int[] | 动作开始时给自身加 buff → buff_base | `module/behaviortree/actions/AttackRole.lua:234,330` |
| camera_id / camera_frame | int[] | 第 N 帧震屏 → action_camera | `module/behaviortree/actions/ActionAttack.lua:164-169` |
| sound_id | int[] | 音效 | `module/behaviortree/actions/AttackRole.lua:263` |
| interrupt_frame | frame | 从这一帧起可以被打断，`-1` 表示不可打断 | `module/behaviortree/actions/AttackRole.lua:392-397` |
| interrupt_extra_frame | frame | 额外的可取消窗口 | `module/behaviortree/actions/AttackRole.lua:442-447` |
| ghost | int | 残影，`-1` 表示关闭 | `module/behaviortree/actions/AttackRole.lua:243,338` |
| shadow | num | 影子缩放 | `module/behaviortree/actions/AttackRole.lua:223` |
| name_show | 0/1 | 为 0 时显示名字 | `module/behaviortree/actions/AttackRole.lua:225` |
| tips_show / dialog_show | int | 弹出提示或台词 | `module/behaviortree/actions/AttackRole.lua:248-259` |
| action_pos_type / relative_action_pos / action_orientation | — | 瞬移到地图相对坐标或绝对坐标，并设置朝向 | `module/behaviortree/actions/AttackRole.lua:275-291` |
| display_spine_ids / display_spine_frame / display_spine_frame_count | — | 大招全屏 Spine | `module/behaviortree/actions/AttackRole.lua:71,541-543,585` |
| static_target / static_time / static_start_frame / static_reset_time | — | 全屏静止（时停）效果 | `module/behaviortree/actions/AttackRole.lua:572-607` |
| transform_id / transform_frame / transform_type | — | 变身，切换为另一个 entity_role | `module/behaviortree/actions/AttackRole.lua:91-131,555-561` |

示例（id=920010）：
```
action=10120, aciton_scale_time=1, displacement_id=922010, effect_ids={920000}, effect_frames={1,0},
interrupt_frame=2, interrupt_extra_frame=0, loop=1, shadow=2, sound_id={5221,5222,5223,5224}
```

### 2.2 action_attack_effect / action_attack_effect2（特效动作）

用途：特效实体自身的动作。
- 主键：`id`，≥ 2000000 时落到 `_effect2`。
- 来源：`entity_effect.action_ids`。`module/entity/EntityEffect.lua:113,338` 为每个 id 生成一个 `AttackEffect` 节点；该节点在 `module/behaviortree/actions/AttackEffect.lua:28` 取数据。

| 字段 | 含义 | 读取点 |
|---|---|---|
| action / aciton_scale_time / loop / shadow / ghost | 与 §2.1 相同 | `module/behaviortree/actions/AttackEffect.lua:100-109,137` |
| displacement_id | 特效位移 | `module/behaviortree/actions/AttackEffect.lua:106` |
| control / control_velocity | 特效受控，1 表示跟随摇杆 | `module/behaviortree/actions/AttackEffect.lua:90` |
| effect_ids / effect_frames | 生成子特效 | `module/behaviortree/actions/AttackEffect.lua:155-157` |
| camera_id / camera_frame | 震屏 | `module/behaviortree/actions/ActionAttack.lua:164-169`（继承自基类） |
| sound_id | 音效 | `module/behaviortree/actions/AttackEffect.lua:62,120` |
| sound_id2 | 按受击者 `entity_role.sound_type` 选择的受击音效 | `module/behaviortree/actions/AttackEffect.lua:116` |
| summon_id / summon_frame / summon_time | 第 N 帧召唤 entity_role，summon_time 是存在时长 | `module/behaviortree/actions/AttackEffect.lua:173-199` |
| interrupt_frame / obstruct / floor / action_delay_time | 通过 ActionAttack 基类读取 | `module/behaviortree/actions/ActionAttack.lua:81-112` |

示例（原表 `[920000]`）：`aciton_scale_time=1.3, sound_id=__rt14`，其余字段取默认值（`action=0, loop=1, summon_id=-1`）。

### 2.3 action_camera（震屏）

- 主键：`id`。
- 读取方：`module/camera/CameraShaker.lua:35-41` 和 `ui/basic/XViewBase.lua:653-657`。
- 字段：
  - `amplitude_x`、`amplitude_y`：振幅
  - `duration`：持续时间（ms）
  - `times`：次数
  - `modifier`：衰减曲线字符，例如 `'i'`
  - `level`：优先级。`module/camera/CameraManager.lua:76` 用它比较当前震屏，高等级覆盖低等级

示例：`id=1, amplitude_x=0, amplitude_y=6, duration=100, times=5, level=10, modifier='i'`

### 2.4 action_displacement（位移曲线）

- 主键：`id`。
- 读取方：`ComponentDisplacement:setDisplacement` 在 `module/component/ComponentDisplacement.lua:540` 取数据；另有 `module/behaviortree/actions/ActionJostled.lua:21,41`。

| 字段 | 含义 | 读取点 |
|---|---|---|
| velocity | vec3 初速度。x 乘以朝向 | `module/component/ComponentDisplacement.lua:586-588` |
| velocity_time | vec3 各轴持续时间（ms），`-1` 表示直到落地 | `module/component/ComponentDisplacement.lua:590` |
| acceleration / acceleration_time | vec3 加速度及其持续时间 | `module/component/ComponentDisplacement.lua:591-592` |
| gravity | 0/1，是否受重力 | `module/component/ComponentDisplacement.lua:578,594` |
| bounces | 落地反弹系数 | `module/component/ComponentDisplacement.lua:579,595` |
| is_trace / trace_radius / trace_angle / trace_velocity | 追踪最近的敌人（半径、角度、速度） | `module/component/ComponentDisplacement.lua:553-565` |

示例：
```
id=8: velocity={-0.25,0.4,0}, velocity_time={-1,0,0}, gravity=1, bounces=0.5
id=920000: velocity={-0.5,0,0}, velocity_time={300,0,0}, acceleration={0.0025,0,0}, acceleration_time={190,0,0}
```

---

## 3. Buff

### 3.1 buff_rule（Buff 规则类）

- 主键：`id`，即 rule_id。
- 字段：
  - `class_name`：Lua 类名。`module/buff/BuffPool.lua:408` 用 `new(class_name)` 实例化。`DBBuff:getRuleIdByName` 也按它反查。
  - `buff_type`：为 1 时表示持续扣血类（DOT），见 `module/buff/BuffBase.lua:365`。
  - `fashion_show_text`：时装 UI 文本，**战斗未使用**。
- 类文件在 `module/buff/xbasic/*.lua`、`module/buff/xstatus/*.lua`。`gBuffRule.BFxxx` 常量由 `module/buff/BuffPool.lua:1141-1146` 按名字生成。

示例：
```
[1] BuffSuperArmor, [2] BuffCrazy, [3] BuffInvincible, [4] BuffBurn(buff_type=1), [5] BuffPoison(buff_type=1), [7] BuffStun
```

### 3.2 buff_base（Buff 实例配置）

- 主键：`id`。
- 访问：`DBBuff:getBuffBase`。调用点有 `module/buff/BuffBase.lua:106`，以及 `module/buff/BuffPool.lua:318,370,384,476,535`。

| 字段 | 含义 | 读取点 |
|---|---|---|
| rule_id | → buff_rule（决定行为类） | `module/buff/BuffPool.lua:385` |
| sub_type | 同 rule 下的子类型，用于同类查重 | `module/buff/BuffPool.lua:392`；`BuffBase.lua:869` |
| param_value / param_value2 | 规则参数。param_value2 支持多层嵌套 | `module/buff/BuffBase.lua:120-121` |
| target | 作用目标，`EnumBuffTarget.Self` 等 | `module/buff/BuffPool.lua:326` |
| probability / probability_repeat | 触发概率（%），probability_repeat=1 时概率乘以层数 | `module/buff/BuffPool.lua:390-396` |
| area_setting | 限定生效的场景区域 | `module/buff/BuffPool.lua:375,677` |
| binding | 是否绑定技能 | `module/buff/BuffPool.lua:322`；`BuffBase.lua:134` |
| began / ended | 开始、结束所挂的事件 id | `module/buff/BuffBase.lua:107-111` |
| event_param | `[1]` 事件目标，`[2]` 为 1 时触发后退出 | `module/buff/BuffBase.lua:168,579,587` |
| execute_type | 执行方式 1/2/3 | `module/buff/BuffBase.lua:409-419` |
| condition_param | 条件参数 | `module/buff/BuffBase.lua:122,379` |
| condition | **未确认**（没找到 `tBuffData.condition` 的读取） | — |
| interval / times | tick 间隔（ms）/ 最大次数 | `module/buff/BuffBase.lua:124-125,368-370` |
| repeat_max / remove_repeat_all | 最大层数 / 移除时是否清掉所有层 | `module/buff/BuffBase.lua:132-133` |
| reset_type | 重复添加时的处理。0：都不变；1：重置次数和间隔；2：重置次数；3：重置间隔；4 及以上：叠层 | `module/buff/BuffBase.lua:343-356` |
| add_type / priority | 同类替换策略（`EnumBuffAddType`）/ 优先级比较 | `module/buff/BuffBase.lua:897-912` |
| cd / cd_pvp | 触发 CD。`Const.FIGHT_FAIR_CD_SWITCH` 为真时取 pvp 值 | `module/buff/BuffPool.lua:445` |
| inner_cd | 内部 CD | `module/buff/BuffBase.lua:135` |
| destroy_type | 销毁方式 | `module/buff/BuffBase.lua:137,381` |
| inherit | 继承标记，用于变身或召唤时继承 | `module/buff/BuffBase.lua:885`；`BuffPool.lua:867` |
| buff_type | 增益/减益分类。3、4 可被 BFImmuneDebuff 免疫 | `module/buff/BuffPool.lua:633`；`BuffBase.lua:889` |
| hurt_type | 1 表示魔法等分支 | `module/buff/BuffBase.lua:1003` |
| bind_special_ability_id | 绑定 specialability | `module/buff/BuffBase.lua:205`；`module/buff/xstatus/BuffSummonDummy.lua:12` |
| buff_partner | 伙伴共享 | `module/buff/BuffPool.lua:594` |
| spine_id / spine_layer / spine_offsets / spine_step / buff_direction | 表现相关 | `module/entity/EntityManager.lua:521`；`module/buff/BuffBase.lua:138,516,524` |
| audio_id | 音效 | `module/buff/BuffBase.lua:430-446` |
| icon / name_id / show_tips / icon_desc_id | 提示与 UI | `module/buff/BuffPool.lua:429,466`；`ui/view/UiFight/UiFightBuffTip.lua:21` |
| desc_id | 仅 UI | — |

另外 `scene/NetworkFightScene.lua:304` 读取 `to_enemy`，但表里**没有**这个字段，读到的恒为 nil。

示例（id=1）：
```
rule_id=100, began=4, binding=1, event_param={2,0}, execute_type=3, param_value={7},
target=1, probability=100, repeat_max=1, reset_type=0, add_type=0
```

rule_id 100/101/102 是"添加子 buff"类。预加载时会递归把 `param_value` 当作 buff id 处理，见 `module/entity/EntityManager.lua:513-514`。

### 3.3 item_buff（战斗药品物品）

- 主键：`id`，16000 段。
- 访问：`DBItem.tItemDB[9]`（`db/DBItem.lua:16`）。
- 字段：`buff_id`、`overlay`（堆叠上限，`ui/ViewFightManager.lua:537`）、`need_lev`、`quality`、`destory_*`、`icon`、`name_id`、`desc_id`。
- `buff_id` 在战斗侧的应用点**未确认**：没 grep 到 `itemInfo.buff_id`。
- 示例：`[16001] buff_id=2, need_lev=2, quality=2, destory_num=2`。

### 3.4 specialability_base（特殊能力，与 Buff 平级）

- 主键：`id`。
- 来源：`entity_effect.specialability_id`、`buff_base.bind_special_ability_id`。
- 访问：`module/specialAbility/SpecialAbilityPool.lua:147`。

字段：
- `rule_id`、`sub_type`（`SpecialAbilityPool.lua:165`）
- `event`、`condition`、`condition_value`：见 `module/specialAbility/SpecialAbilityCondition.lua`
- `probability`：`SpecialAbilityBase.lua:186`
- `SpecialAbilityCD` / `SpecialAbilityCD_pvp`：`SpecialAbilityBase.lua:105`
- `ended_type` / `ended_value`：0 表示不销毁，1 表示倒计时，见 `SpecialAbilityBase.lua:106-107`
- `effect_id` / `effect_id_type`：生成的特效，`SpecialAbilityBase.lua:295-296`
- `bind_buff_id` / `bind_buff_type`：`SpecialAbilityBase.lua:253-254`
- `bind_skill_type`：`SpecialAbilityBase.lua:103`
- `pvp_setting`：PVP 下为 0 表示不生效，大于 1 表示替换为该 id，见 `SpecialAbilityPool.lua:150-152`
- `buff_partner`：`SpecialAbilityPool.lua:220`
- `res_sound_id`、`spine_*`、`show_tips`

示例：`id=1, rule_id=1, effect_id={883020}, bind_skill_type=1, SpecialAbilityCD=-1, probability=0, show_tips=1`

---

## 4. 实体

### 4.1 entity_role（角色/怪物/召唤物）

- 主键：`id`。
- 访问：`DBEntity:getRoleData`，调用点有 `module/entity/EntityRole.lua:538`、`module/entity/EntityManager.lua:563`、`helper/StageHelper.lua:168`。

| 字段 | 含义 | 读取点 |
|---|---|---|
| role_type | `EntityRoleType`：1 Hero、2 Monster、3 Elite、4 Boss、5 Summon … 12 Crystal（`global/GlobalBusinessEnum.lua:16`）。决定 entity_attribute 分段 | `module/entity/EntityAttribute.lua:128-134` |
| role_type_sign | 角色标记 | `module/entity/EntityRole.lua:552` |
| ai_id | int[]，按难度取下标 → entity_ai | `module/entity/EntityManager.lua:572`；`EntityRole.lua:870` |
| attribute_rate | 16 元素数组，对应 `AttributeName` 顺序的倍率 | `module/entity/EntityRole.lua:826-828`；`EntityAttribute.lua:138` |
| monster_camps | 阵营 | `module/entity/EntityRole.lua:548` |
| rigidity | 浮空值上限 | `module/entity/EntityRole.lua:567,1763` |
| weight | 每次被击时浮空速度的衰减 | `module/entity/EntityRole.lua:2417` |
| fatigue | 连续受击时硬直递减 | `module/entity/EntityRole.lua:1226` |
| hit_count | 被击计数初值 | `module/entity/EntityRole.lua:560` |
| hit_stiff_time | 覆盖受击硬直，会乘以 `1+ADD_FLOOR_TM` | `module/entity/EntityRole.lua:3241-3242` |
| hit_displacement_id | 覆盖受击位移 | `module/behaviortree/actions/ActionHit.lua:38,96` |
| hit_restrain | 攻防克制系数（`[2]` 影响血条显示） | `module/entity/EntityRole.lua:2808-2812`；`ui/widget/ViewFightRoleHp.lua:47` |
| time_rage | 怪物狂暴（时间、倍率、buff） | `module/entity/EntityRole.lua:578` |
| death_displacement_id / death_effect_id / ko_effect_id | 死亡时的位移 / 特效 | `module/entity/EntityRole.lua:1562-1566`；`module/behaviortree/actions/ActionDeath.lua:85-86` |
| buff_ids | 出生自带 buff | 在 `EntityRole` 中读取，具体行**未确认** |
| hp_bar_count | 血条层数 | `ui/widget/ViewFightRoleHp.lua:50` |
| is_pass_room | 跨房间保留 | `scene/FightScene.lua:759`；`module/entity/EntityManager.lua:793,853` |
| radius / velocity / tier / tier_ext / shadow / relative_position / spine_relative_position / res_spine_id / res_spine_id_ext / res_fashion | 碰撞半径、移速和外观 | `module/component/ComponentAvatar.lua:194-198,354` |
| buff_pos / buff_scale / hurt_num_pos / vertex_pos / dialog_pos / head_image / sound_id / sound_type | 表现相关 | `module/specialAbility/SpecialAbilityBase.lua:536-540`；`module/entity/EntityRole.lua:2997`；`module/component/ComponentDialog.lua:97` |

示例（id=0）：
```
role_type=1, ai_id={14}, attribute_rate={1×16}, rigidity=24, weight=0.05, fatigue=200,
radius=20, velocity=0.25, death_displacement_id=133, death_effect_id=8, time_rage={{1},{5},{101,110}}
```

### 4.2 entity_effect / entity_effect2（特效实体）

- 主键：`id`，≥ 2000000 时落到 `_effect2`。
- 构造点：`EntityEffect:init`，位于 `module/entity/EntityEffect.lua:62-145`。

| 字段 | 含义 | 读取点 |
|---|---|---|
| hit_id | → skill_hit。存在时才加碰撞组件 | `module/entity/EntityEffect.lua:70-71,104`；`module/skill/SkillHurt.lua:110` |
| action_ids | → action_attack_effect | `module/entity/EntityEffect.lua:113,338` |
| hit_target | 碰撞目标：-1 双方，0 敌方，1 友方 | `module/entity/EntityEffect.lua:76` |
| buff_id | 命中后给**释放者自己**加的 buff | `module/entity/EntityEffect.lua:479,489` |
| buff_all_id | 命中友方时加的 buff | `module/entity/EntityEffect.lua:486` |
| debuff_id | 给被击者加的 buff | `module/entity/EntityEffect.lua:497` |
| specialability_id / specialability_all_id | 命中时触发特殊能力 | `module/entity/EntityEffect.lua:459,809,818` |
| hit_effect_ids | 受击特效 → entity_effect | `module/entity/EntityEffect.lua:125,173,405` |
| next_effect_id | 结束后接续的特效 | `module/entity/EntityEffect.lua:134` |
| hit_extra_control | `[1]==0` 时不能打无敌目标 | `module/entity/EntityRole.lua:2983,3042` |
| energy | 命中后回复 EP，打 Boss 时 ×1.5 | `module/entity/EntityRole.lua:2940` |
| combo_exp | 连击经验 | `module/entity/EntityRole.lua:3308` |
| auto_release / follow | 生命周期、是否跟随释放者 | `module/behaviortree/actions/AttackRole.lua:529`；`AttackEffect.lua:163` |
| position_type / effect_oriebtation_X/Z | 位置基准与朝向 | `module/entity/EntityEffect.lua:554-586` |
| preload_count | 对象池预创建数量 | `module/entity/EntityManager.lua:973,990` |
| collision / control / effect_type | collision 与 control 通过组件读取，effect_type **未确认** | — |
| radius / relative_position / res_spine_id / tier / shadow / velocity | 外观与位置 | `module/entity/EntityRole.lua:2500-2502`；`module/entity/EntityManager.lua:492` |

示例（id=920000）：
```
action_ids={920000}, hit_id=920000, hit_effect_ids={882477}, energy=3, combo_exp=10,
auto_release=1, follow=0, hit_target=-1, buff_id={-1}, debuff_id={-1}, res_spine_id=48
```

### 4.3 entity_ai（怪物/AI 配置）

- 主键：`id`。
- 访问：`DBEntity:getAiData`，调用点有 `module/entity/EntityRole.lua:870`、`module/entity/EntityManager.lua:572`；竞技场还会 clone 后改写（`scene/game/ArenaScene.lua:87`）。

字段：
- **技能组**：`skill_ids`、`crazy_skill_ids`、`joystick_skill_ids`、`other_skill_ids`，分别对应 `EntitySkillGroup` 的 Normal、Crazy、JoyStick(+Crazy)、Special（`module/entity/EntityRole.lua:587-591`）。每个都是 `[slot][step]` 形式的 skill_attack id。
- `skill_ai_ids`、`crazy_skill_ai_ids`：与技能组平行的 skill_ai id。
- `skill_priority_level`、`skill_priority_level_cd`、`skill_interval`：`module/ai/AiAgent.lua:515,555`。
- 索敌、追击、巡逻：`target_scope_x/z`（`AiAgent.lua:314`）、`chase_scope_x/z`、`patrol_scope_x/z`（`AiAgent.lua:653-655`）、`patrol_delay_time`（`module/behaviortree/actions/ActionPatrol.lua:17`）、`alert_delay_time`（`module/behaviortree/actions/ActionAlert.lua:20`）、`chase_delay_time`。
- `chase_scope_*`、`chase_delay_time` 的读取行**未确认**，只在表内出现，推测在 AiAgent 里经变量名间接读取。

示例（id=1）：
```
skill_ids={{920000},{920100},{920120},{920150},{920170},{920200}},
skill_ai_ids={{1,1,1,1},{1,1},...}, other_skill_ids={{-1},{80220},{-1}},
target_scope_x={-2000,2000}, chase_scope_x={200,300}, patrol_scope_x={100,300}, skill_interval=200
```

### 4.4 entity_attribute（属性基表）

- 主键：`id`，按 §0.3 的分段。
- 读取方：
  - `EntityAttribute:loadAttribute`（`module/entity/EntityAttribute.lua:123-139`）：`tBasicAttribute[i] = row[AttributeName[i]] * attribute_rate[i]`。
  - `DBEntity:getAttributeData`（`db/DBEntity.lua:55-136`）：**怪物属性插值**。

怪物属性插值过程：
- 以 140000 行作为 init 值。
- 取 `curId = 140000 + floor(lv/100)`、`nextId = curId+1`，按 `lv%100` 线性插值。
- **HP**：
  - 先把 `hp` 与 `base_damage` 两列互换使用。
  - 再加 `skill_hurt[ceil(lv/10)].hurt`，乘以 `monster_hit_number`。
  - 如果 key > 160000，再乘 `boss_hp_rate`；如果 key > 150000，再乘 `elite_hp_rate`。
- **base_damage**：除以 `player_hit_number`，再按 Boss 或精英分别乘 `boss_hurt_rate` / `elite_hurt_rate`。

字段（顺序与 `AttributeName` 一致，`db/DBEntity.lua:16-33`）：
- `source_force`、`agility`、`habitus`、`spirit`、`hp`、`atk`、`def`、`matk`、`mdef`、`crit`、`crit_resist`、`crit_damage`、`crit_damage_resist`、`dodge`、`hit`、`base_damage`
- 以及 `monster_hit_number`、`player_hit_number`、`boss_hp_rate`、`boss_hurt_rate`、`elite_hp_rate`、`elite_hurt_rate`

前 4 个一级属性只会被载入，不参与伤害公式；它们经 attribute_change 转换，见 §4.5。

示例：`id=10000, hp=4000, atk=800, def=800`，其余为 0。

### 4.5 attribute_change（一级属性到二级属性的转换）

- 主键：`id`。
- 字段：
  - `occupation`：职业
  - `primary_attributes`：一级属性 id
  - `result_attributes`：二级属性 id 列表
  - `coefficient`：转换系数列表
- 读取方：`db/DBAttributeChange.lua:14-50`、`cache/CacheEquip.lua:58`（`value*coefficient[k]`）、`ui/view/UiOther/UiRoleAttributeChangeItem.lua:38`。
- 转换发生在养成侧（Cache），战斗内没有读取。
- 示例：`[1] occupation=1, primary_attributes=1, coefficient=__rt2, result_attributes=__rt4`。

### 4.6 其它实体表

- **entity_obstacle**（主键 id）：
  - `obstacle_type`：等级由 `map_room.obstacle_level[type]` 决定（`scene/GameScene.lua:791-795`）。
  - `attribute_rate`：`module/entity/EntityObstacle.lua:66`，基址为 140000。
  - `hit_counts`、`death_effect_id`、`death_displacement_id`、`radius`、`res_spine_id` 等。
  - 示例：`[15] obstacle_type=1, radius=50, res_spine_id=1221, hit_counts=-1`。
- **entity_goods**（掉落物）：
  - `buff_id`：拾取时加 buff（`module/entity/EntityGoods.lua:153-154`）。
  - 另有 `specialability_id`（`:157`）、`sound_pick`（`:105`）、`name_show`、`quality_show`（`:59,220`）。
  - `summon_id`、`sound_drop`：**未使用**。
- **entity_portal**：传送门的外观和动画，由 `map_room.portal_ids` 引用。
- **entity_pet**、**entity_npc**、**entity_fight_value**：宠物外观、城镇 NPC、推荐战力（`db/DBEntity.lua:194`），都是非战斗核心。

---

## 5. 地图/刷怪

### 5.1 map_data（场景地图）

- 主键：`id`，即 map_data_id。
- 字段：
  - `map_key`：场景资源名，`module/map/MapManager.lua:140`
  - `soundid`：BGM，`scene/SceneManager.lua:139-143`
  - `distant_offset`、`middle_offset`、`nearby_offset`、`case_offset`、`light_offset`：各层视差系数，分别在 `module/map/MapDistant.lua:17`、`MapMiddle.lua:17`、`MapNearby.lua:17`、`MapCase.lua:17`、`MapLight.lua:17`
- 示例：`[29] map_key='liangongfang', soundid=1002`。

### 5.2 map_stage（关卡）

- 主键：`id`，即 stage_id。
- 访问：`DBMap:getStageData`，调用点在 `helper/StageHelper.lua:47` 以及各 `scene/game/*Scene.lua`。
- 字段：
  - `room_id`：起始房间 → map_room，`helper/StageHelper.lua:54`、`scene/GameScene.lua:899`
  - `stage_pass_time`：限时，`scene/game/TrialChallengeScene.lua:64`
  - `next_node`：小地图连线，`cache/CacheDungeon.lua:1346`
  - `show_hidden`：`cache/CacheDimensionDoor.lua:226`
  - `map_csb`：小地图
  - `drop_id`、`drop_type`、`exp`、`coin`、`cost_strength`：结算和消耗，服务器权威
  - `contain_index`、`index_visible`、`explore_schedule`、`scene_name`、`open_time`、`skill_p`：UI 或**未使用**
- 示例：`[901] room_id=30002, stage_pass_time=600, exp=600, coin=200, next_node={4}, scene_name={11024,11051}`。

### 5.3 map_room / map_room2 / map_room3（房间刷怪）

- 主键：`id`，即 room_id。三张表的字段结构相同。
- 构造入口：`scene/FightScene.lua:198`（`DBMap:getRoomData`）。

| 字段组 | 含义 | 读取点 |
|---|---|---|
| map_data_id | → map_data | `scene/GameScene.lua:1095-1096` |
| room_type | 房间类型：-1 无，0 普通，1 关卡 Boss，2 最终 Boss（`global/GlobalExcelEnum.lua:26`） | `ui/widget/ViewMinimapManager.lua:247` |
| battle_rule_type / battle_rule_param | 胜负规则：0 无，1 清怪，2 防守，3 生存，4 深渊（`global/GlobalExcelEnum.lua:33`）；param 为波次等参数 | `scene/FightScene.lua:204`；`scene/game/PlotScene.lua:89` |
| monster_ids / monster_pos_x / monster_pos_z / monster_vector_x | 怪物 → entity_role 及其坐标和朝向 | `scene/FightScene.lua:492-527` |
| monster_levels | 按 `role_type-1` 取等级，再加上功能增幅等级 | `scene/FightScene.lua:1543`；`cache/CacheDungeon.lua:632` |
| monster_ai_difficulty | AI 难度，作为 `entity_role.ai_id` 的下标 | `scene/FightScene.lua:1524` |
| monster_hp_bar / monster_drop_goods | 血条层数、HP/EP 掉落 | `scene/FightScene.lua:516-517` |
| actor_pos_x / actor_pos_z / actor_vector_x / actor_buff_ids | 玩家出生点和房间 buff | `scene/NetworkFightScene.lua:381`；`scene/FightScene.lua:1426` |
| obstacle_ids / obstacle_pos / obstacle_vector_x / obstacle_level | 障碍物 | `scene/GameScene.lua:766-805`；`scene/FightScene.lua:389-412` |
| good_ids / good_pos / good_vector_x | 场景物品 → entity_goods | `scene/FightScene.lua:446-468` |
| portal_ids / portal_slots / portal_dest_* / portal_limit_type / portal_limit_value | 传送门，以及目标房间或关卡 | `scene/GameScene.lua:845-899` |
| is_warning / open_tips / victory_tips / icon_go / minimap_slot / story_id / talk_* | 表现与剧情 | `scene/FightScene.lua:1019-1037,1285,1601`；`ui/widget/ViewSoundTalk.lua:173-296` |
| victory_cond | **未使用** | — |

示例（map_room `[1]`）：
```
map_data_id=37, battle_rule_type=2, battle_rule_param={1,2}, monster_ids={2223,2223,2223,2223},
monster_pos_x={690,870,870,1040}, monster_pos_z={185,135,160,160}, monster_vector_x={-1,...},
actor_buff_ids={200,400}, obstacle_ids={16,16}, portal_ids={100,200}, portal_dest_room_ids={{30006},{30006}}, room_type=1
```

map_room2 与 map_room3 都有 `[100000]`，内容与 `[1]` 类似。由于 `getRoomData` 按顺序查找，room2 优先生效。

### 5.4 map_copy / map_copy_main（副本入口）

- **map_copy**（探索副本）：
  - `contain_stage_camp`：`[1]` 是关卡列表，`[2]` 是营地列表，见 `cache/CacheDungeon.lua:1335-1350`。
  - `difficult_level_improve`：按难度增加怪物等级，`cache/CacheDungeon.lua:217`。
  - `return_camp_num`：`:216`。`key_hud`：`:210`。
  - `max_revive`、`item_revive(_cost)`：复活。
  - `allstar_time`：UI。
  - 掉落和扫荡相关字段属于非战斗逻辑。
- **map_copy_main**（主线）：
  - `stage_id`、`copy_type`、`add_level`、`auto_copy_type`、`key_hud`、`max_revive`、`item_revive`：`helper/StageHelper.lua:11-34`、`cache/CachePlotFight.lua:55-71`。
  - `star_task_id` → map_copy_main_task。
- 示例：`map_copy_main [101] map_csb='UiMinimapAct_Main_1_1', recommend_fighting=1`，其余为默认值（`stage_id=40101, max_revive=3`）。

---

## 6. 词条 / PVP AI / 其它

- **config_pvp_ai**（主键 id）：
  - `pvp_type`、`profression`（原拼写）、`level`、`ai_warehouse`。
  - `DBWorldConfig:getAiByLvAndType`（`db/DBWorldConfig.lua:14-31`）先按类型和职业过滤，再按 level 升序，取第一个 `role_lv <= level` 的行，并从 `ai_warehouse` 里随机选一个 entity_ai id。
  - 调用点：`scene/game/ArenaScene.lua:81`、`scene/game/ArenaCrossServerScene.lua:216`，使用 `pvp_type=2`。
  - `type`：**未使用**。
- **other_bossrush_buff**：`buff_id` → buff_base，用于 BossRush 选择 buff（`cache/CacheBossRush.lua:54-55`，`db/DBOther.lua:512`）。
- **other_constellation_buff_***：星座副本 buff，`scene/game/ConstellationScene.lua:50-81` 读取 `buff_id`。
- **other_boss_skills**：巢穴 Boss 技能说明，仅 UI（`db/DBOther.lua:208`）。
- **词条**：养成带入的 buff 不在独立的"词条表"里。它们以 `{id, source}` 的形式由各养成表的 `buff_id` / `specialability_id` 收集，例如：
  - `item_artifact_skill`、`other_superskill_*`、`item_partner_*`、`item_fashion_suit`
  - 收集点：`cache/CacheCrossArena.lua:1302-1383`、`entity/Partner.lua:234`
  - 注入战斗：`scene/SceneFactory.lua:62-63`（`EnumFightModule.Buff/Ability`）
  - 这些表的具体字段**未逐一确认**。
- **world_config**：`id → value`，是通用常量（`db/DBWorldConfig.lua:3`）。其中与战斗相关的 key **未确认**。

**与战斗无关的表**（仅 UI、养成、运营）：
- 前缀族：`bt_*`、`config_*`（除 config_pvp_ai）、`detection_third_party`、`item_*`（除 item_buff）、`lottery_*`、`name_*`、`official_account_gift`
- `other_*`：除 bossrush_buff、constellation_buff_*、boss_skills，以及上面提到的词条来源表
- 其它前缀族：`pvp_*`（天梯分、奖励）、`recharge_*`、`res_*`（资源路径）、`sound_*`、`text_*`、`tutor_*`、`union_*`、`world_lv_gift`、`server_enterkey`、`push_system_massage`
- `map_` 中非战斗的表：`map_chapter`、`map_city`、`map_province`、`map_country`、`map_camp`、`map_copy_bestdrop`、`map_copy_card`、`map_copy_main_task`、`map_copy_partner`、`map_activity_*`、`map_stage_appraise`

---

## 7. 改变公式的扩展属性

定义在 `module/entity/EntityAttribute.lua:4-23`（`ExtendAttributeType`）。写入方式：
- `EntityRole:modifyExtendAttribute`（`module/entity/EntityRole.lua:1471`），由各 buff 类调用，例如 `module/buff/xbasic/BuffBreakArmor.lua:8`（AVOID_HURT）、`BuffAttributeSlotCD.lua:41-59`。
- `setExtendAttribute`（`module/entity/EntityAttribute.lua:326`）。

| id | 名称 | 作用位置 | 公式 |
|---|---|---|---|
| 100 | ADD_HURT | `module/skill/SkillHurt.lua:164,195` | `hurt *= 1+ADD_HURT(攻)` |
| 101 | AVOID_HURT | `module/skill/SkillHurt.lua:165,196` | `hurt *= 1-AVOID_HURT(受)` |
| 102 | ADD_CRIT | `module/skill/SkillHurt.lua:177` | 暴击率 = clamp((crit+ADD_CRIT − (critDef+AVOID_CRIT))/100, 0.01, 1) |
| 103 | AVOID_CRIT | `module/skill/SkillHurt.lua:179` | 同上 |
| 104/105 | ADD_EP / AVOID_EP | 计算公式里**未确认**有读取，只出现在调试名表（`module/entity/EntityRole.lua:4142`） | — |
| 106 | ADD_MAXHP | `scene/FightScene.lua:619-621`、`scene/game/PVPScene.lua:201-203` 等 | 场景按系数缩放额外 HP |
| 107 | AVOID_MAXHP | **未确认** | — |
| 108 | DRAGON_DROP | `module/behaviortree/actions/ActionDeath.lua:145-147` | 掉落 |
| 109 | ADD_DODGE | `module/entity/EntityEffect.lua:757` | 闪避率 = clamp((dodge+ADD_DODGE − (hit+ADD_HIT))/100, 0, 0.5)，`module/skill/SkillHurt.lua:227-235`。仅在 `hit_must==0` 时判定 |
| 110 | AVOID_DODGE | 已废弃 | — |
| 111 | ADD_HIT | `module/entity/EntityEffect.lua:758` | 同上 |
| 112 | ADD_CRIT_HURT | `module/skill/SkillHurt.lua:183` | 暴伤倍率 = max(1.5, 1.5+(critHurt+ADD − (critHurtDef+DEF))/100)，`:237-240` |
| 113 | ADD_CRIT_HURT_DEF | `module/skill/SkillHurt.lua:185` | 同上 |
| 114 | ADD_ARTIFACT_HIT | `module/skill/SkillHurt.lua:198-199`；`module/buff/BuffBase.lua:1037` | 神器技能或能力触发的特效：`hurt *= 1+v` |
| 115 | ADD_FLOOR_TM | `module/entity/EntityRole.lua:3238,3242`；`module/behaviortree/actions/ActionHitFloor.lua:110,116` | 倒地/硬直时间 `*= 1+v` |

**完整伤害公式**（`SkillHurt:calculateDamage`，`module/skill/SkillHurt.lua:108-209`）：

1. `standHurt`：英雄为 `ATK + skill_hurt[lv].hurt`；怪物为 `BasicHurt + skill_hurt[max(1,floor(lv/10))].monster_hurt`；召唤物递归取主人的值（`:42-67`）。
2. `rate = atk/(atk+def)`。物理用 ATK/DEF，魔法用 MATK/MDEF，真伤取 1。PVP 下 atk、def 各自再乘 `1+PvpATK` / `1+PvpDef`。
3. `hurt = standHurt × rate × hurt_rate × (1+addition)`。
   - `addition` 在 `module/entity/EntityRole.lua:3141-3164` 按 `skill_leaf.hurt_type` 计算：`等级 × Const.SKILL_HURT_DEFAULT_ADDITION`。
   - 该常量**为 0**（`imports/Const.lua:614`），因此当前技能等级对伤害没有影响。
4. 暴击判定成功时乘暴伤倍率。之后乘 `(1+ADD_HURT)(1−AVOID_HURT)`，按条件乘 `(1+ADD_ARTIFACT_HIT)`，最后乘随机系数 `(99 + 0.02×rand(0,100))/100`，结果为负时取 0，再向下取整。
5. Buff 伤害（`calculateBuffDamage`，`:82-97`）：`standHurt × param_value × (1+addition)`，不计防御，也不计暴击。

---

## 8. 槽位与按键配置

| 层 | 定义 | 位置 |
|---|---|---|
| 技能槽枚举 | `EnumSkillSlot`：1 Attack、2 Sprint、3 Dodge、4 Crazy、5/6/7 A/B/C、8/9/10 SA/SB/SC（搓招）、11/12 EA/EB、13–15 SUA/SUB/SUC（奥义）、16 Break（挣脱）、17–19 SAP/SBP/SCP（搓招按键版）、20 Anger（怒气变身） | `global/GlobalBusinessEnum.lua:552-590` |
| 技能组 | `EntitySkillGroup`：1 Normal、2 Crazy、3 JoyStick、4 JoyStick_Crazy、5 Special；`EntitySkillChange`：1 Normal、2 Joy、3 Anger | `module/skill/SkillPool.lua:10-22` |
| 槽位到 [组, 中间下标] | 例如 Attack→{Normal,1}、A/B/C→{Normal,2/3/4}、Crazy→5、Dodge→6、EA/EB→7/8、SUA–SUC→9–11、Break→12、SAP–SCP→13–15、Anger→16、Sprint→{Special,2}、SA/SB/SC→{JoyStick,−1}（使用 rockIndex） | `scene/SceneFactory.lua:2-23` |
| 构建 | `operationDataTransform`：曝气类技能的组号 +1；`skill_change_system` 在这里展开 | `scene/SceneFactory.lua:61-170` |
| 槽位字符串 | `CONST_SLOT`：A 平 A；B/C/D 基础技能；E 曝气（已弃用）；F 闪避；G/H 转职；I/J/K 奥义；L 挣脱；Y 冲刺；`"1+".."12+"` 搓招；M/N/O 搓招按键 | `imports/ConstBusiness.lua:5371-5401` |
| 槽位到控制事件 | SA/SB/SC→CTR_ATKA，A→CTR_ATKB，B→CTR_ATKC，C→CTR_ATKD | `scene/SceneFactory.lua:30-37` |
| 键盘 | `KeyCodeAttack`：u/i/o/j/k/l/m/n/8/9/0/;/Y/T/H/Q 对应 CTR_ATKA..Q | `module/touch/ControlManager.lua:122-139` |
| 搓招指令 | `KeyCodeJoyAttack[1..24]` 两两对应 CTR_JOY1..12；`KeyCodeJoy[i]` 是方向序列，例如 `[1]={2,3,4,1,2}`。方向码：1=↑ 2=→ 3=↓ 4=←（与 `KeyCodeJoyAttackName` 对照得出，如 `[1]` = → ↓ ← ↑ →）。`skill_rock.command_index` 就是这里的 index | `module/touch/ControlManager.lua:141-240` |

---

## 9. 查表顺序

```
[养成] skill_tree.leaf_ids ──► skill_leaf(id) ──skill_id──► 基础技能
            skill_chip(chip_type=Skill).relate_id ─► skill_leaf / skill_rock(command_index→搓招槽)
[怪物] map_room.monster_ids ─► entity_role ─ai_id[monster_ai_difficulty]─► entity_ai.skill_ids/skill_ai_ids
            entity_role.role_type + monster_levels ─► entity_attribute(段基址+lv, 插值) × attribute_rate
                                                        └─ HP 用 skill_hurt[lv/10].hurt
            [PVP AI] config_pvp_ai.ai_warehouse ─► entity_ai
                     │
                     ▼
 SceneFactory 槽位映射 (EnumSkillSlot→EntitySkillGroup,slot) ── skill_change_system(skill_id) 追加变化槽
                     │
                     ▼
 skill_attack(id) ──skill_ai_id──► skill_ai          ──next_skill──► skill_attack(下一段)
      │ action_ids[toward][i]
      ▼
 action_attack(id) ──displacement_id──► action_displacement   (自身位移)
      │            ──camera_id[]──────► action_camera          (震屏)
      │            ──buff_ids[]───────► buff_base ─rule_id─► buff_rule.class_name
      │            ──transform_id─────► entity_role            (变身)
      │ effect_ids[i] @ effect_frames[i]
      ▼
 entity_effect(id ≥2000000→effect2) ──action_ids──► action_attack_effect(≥2000000→2)
      │                                   ├─displacement_id─► action_displacement (特效飞行)
      │                                   ├─effect_ids─────► entity_effect (子特效)
      │                                   └─summon_id──────► entity_role (召唤)
      │ ──next_effect_id / hit_effect_ids──► entity_effect
      │ ──buff_id(自身)/buff_all_id(友)/debuff_id(敌)──► buff_base ─► buff_rule
      │ ──specialability_id──► specialability_base ─effect_id/bind_buff_id─► …
      │ hit_id
      ▼
 skill_hit(id)
      ├─hurt_type/hurt_rate/pvp_hurt_rate ─► SkillHurt:calculateDamage
      │        standHurt = ATK + skill_hurt[lv].hurt  (怪: BasicHurt + skill_hurt[lv/10].monster_hurt)
      │        × atk/(atk+def) × hurt_rate × (1+addition[skill_leaf.hurt_type])
      │        × 暴击 × (1+ADD_HURT)(1-AVOID_HURT)(1+ADD_ARTIFACT_HIT) × rand(0.99~1.01)
      ├─hit_must/ADD_DODGE/ADD_HIT ─► 闪避判定 (EntityEffect.lua:754)
      ├─hit_type ─► ActionHitUp/Down/Floor
      │     └─displacement_id / air_displacement_id / floor_displacement_id ─► action_displacement
      │        (entity_role.hit_displacement_id 覆盖)
      ├─stiff_time × (1+ADD_FLOOR_TM)  (entity_role.hit_stiff_time 覆盖, fatigue 递减)
      ├─hit_rigidity vs entity_role.rigidity/weight ─► 浮空
      └─freeze_time* ─► 顿帧
 命中后: entity_effect.energy → EP;  combo_exp → 连击;  action_attack_effect.sound_id2[受击者 sound_type]
```
