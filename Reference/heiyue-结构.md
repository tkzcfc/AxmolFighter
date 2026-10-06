# heiyue 工程结构总览

> 本文讲参考工程 `heiyue/` 的**结构**，是把战斗逻辑移植到 C++ 时的入口文档。战斗细节见 `heiyue-战斗逻辑.md`，配置表见 `heiyue-战斗配置.md`，AI 见 `heiyue-AI与行为树.md`。
> 下文路径都相对于 `heiyue/`，`src/...` 指 Lua 源码。行号写作 `path:line`。标"未确认"的内容没有验证过。
> **编码**：`src/**/*.lua` 是 **UTF-8**。PowerShell 里用 `Get-Content -Encoding utf8` 读取；按 GBK 读会乱码。

---

## 1. 工程形态

| 项 | 内容 |
|---|---|
| 引擎 | cocos2d-x **3.14.1**，见 `frameworks/cocos2d-x/cocos/cocos2d.cpp:34` 和 `.cocos-project.json`（`project_type: lua`, `has_native: true`） |
| Lua VM | LuaJIT（`simulator/win32/lua51.dll`）。`src/main.lua:2-7` 里 `jit.off()` 把 JIT 关掉了，只用解释器，目的应当是保证帧同步时浮点结果一致 |
| 启动 | `start.bat` 运行 `simulator/win32/heiyue.exe`。`config.json` 的 `init_cfg` 为横屏 1136x640，`entry: src/main.lua` |
| 原生层 | `frameworks/runtime-src/Classes/`：`AppDelegate.cpp`、`scene/GameScene.cpp`、`common/`（AEUtil、AERandom、AEMD5、AERC4、AEByteBuffer）、`math/`（AEVec2、AEGeometry）、`external/{behavior,collision,spine,json,md5}`、`net/`、`xenet/`、`aone/`（SDK） |
| Lua 绑定 | `frameworks/runtime-src/Classes/scripting/lua-bindings/`：`auto/lua_{behavior,collision,common,external,network,spine}_auto.cpp`、`manual/*`、`register_custom_function.cpp`。Lua 侧 API 桩在 `auto/api/*.lua`，例如 `AEBTNode/AEBTSelector/AEBTSequence/AEBTParallel/AEBTCondition/AEBTAction`、`AECollision/AECollider/AESpineColliderManager`、`AESpine`、`AEUtil` |
| 其它目录 | `runtime/win32` 是运行时副本；`simulator/win32` 是模拟器 exe 和 dll；`frameworks/runtime-src/proj.*` 是各平台工程 |

### 1.1 Lua 启动链
1. `AppDelegate::applicationDidFinishLaunching` 位于 `frameworks/runtime-src/Classes/AppDelegate.cpp:119`。它添加搜索路径（`:134-140`，包括 dlc 目录的 `res`、`src`、`src/imports`、`src/imports/table`），设计分辨率为 1136x640 NO_BORDER（`:155-157`），然后注册 Lua 模块（`:181-195`，其中 `register_custom_function(L)` 在 `:195`）。
2. 原生层的 `GameScene::createScene()`（`AppDelegate.cpp:99/108`，`Classes/scene/GameScene.cpp`）会初始化 behaviac，设置 `Workspace::SetFilePath` 指向 `src/imports/behaviac_exported`，格式为 XML（`GameScene.cpp:42-53`）。
3. `src/main.lua`：
   - `:13-14` 调用 `addSearchPath("src/imports")` 和 `"src/imports/table"`。这样表文件可以直接用 `loadlua "skill_attack"` 这种短名加载。
   - `:103-153` 定义 `LoadGameFileConfig.INDEX_TO_FILES`，是分成三批的加载清单：
     - 第 1 批在启动时加载：global、aonesdk、protocol、hacker、util、trigger、Const*、各 Scene 基础类、GameManager/SceneManager、登录、部分启动 UI、net、handler、Tutorial。
     - 第 2 批：`imports._init`、`db._init`。
     - 第 3 批：`entity/cache/module/scene/task/ui/datacollection/tool/helper` 的 `_init`。
   - `:156` `LoadGameFileFunc(index)` 按批次执行 `loadlua`。`:204` 的 `loadlua(path)` 先清掉 `package.loaded[path]` 再 `require`。
   - `:268-270` 依次执行 `reLoadLua "config"`（`src/config.lua`）、`"cocos.init"` 和 `"alert"`。
   - `:272-283` 是 `main()`：设置 GC 参数，`AEUtil:randomseed`，调用 `LoadGameFileFunc(1)` 和 `GameManager:init()`。
4. `src/scene/GameManager.lua:61` 的 `init()` 调用 `scheduleScriptFunc()`（`:78`），然后初始化 Event/View/Timer Trigger、NetWork、CheatManager 和 SceneManager（`:80-90`），最后 `changeScene("LogoScene")`（`:93`）。
5. 第 2、3 批由 `src/ui/view/UiStartApp/UiFirstLoading.lua:208/218` 在首次 loading 时加载。调试开关 `_GAME_TRAIL_FOR_FIGHT_DEBUG`（`src/imports/Const.lua:773`，默认 false）打开时，`GameManager.lua:95-99` 会直接加载全部三批并进入 `FightDebugScene`。

### 1.2 res/ 与 src/
- `res/`：
  - `animation/`：Spine 资源，约 7.3k 文件（`.skel/.atlas/.png`，少量 `.json`），子目录有 monster、npc、effect、map、buff、fashion、goods、obs、por 等。
  - `collider/`：1066 个 `.collider`，是二进制受击/攻击框文件，内部引用 `animation/xxx.json` 和动作名（例如 `hit`、`heavyhit`）。
  - `ui/`：1855 个 Cocos Studio `.csb`。
  - `piece/`：UI 散图和字体。
  - 另有 `plist/`、`sound/`、`video/`、`Default/`。
- `src/`：全部 Lua 代码，外加生成出来的 Lua 数据表（`src/imports/table`、`src/imports/map`）和 shader。

---

## 2. src/ 分层

| 目录 | 文件数 | 用途与关键文件 |
|---|---|---|
| `aonesdk` | 63 | 渠道 SDK 适配：`_init.lua`、`Channel.lua`、`channel_adapter.lua`、`pipes/`、`sdks/` |
| `cache` | 162 | 各业务系统的客户端数据缓存（CacheXxx，例如 `CacheRole`、`CachePet`、`CacheTask`、`CacheNetworkedFight`）。`GameManager:addCacheFileName` 会记录它们，重登时统一执行 `releaseCache` |
| `cocos` | 63 | cocos2d-x 官方 Lua 框架，包括 `cocos/init.lua`、`framework/`（`class`、`display`、`handler`）、`spine`、`cocostudio` |
| `datacollection` | 3 | 数据打点：`DataCollectManager`、`NetworkFightCollectManager` |
| `db` | 31 | 表访问层 DBXxx，用 `loadlua "<表名>"` 包装原始表，例如 `DBSkill`、`DBEntity`、`DBAction`、`DBBuff`、`DBMap`、`DBSpecialAbility` |
| `entity` | 8 | **UI 用的业务实体**（商店、`Partner`、`UiRole`），和战斗实体无关 |
| `global` | 3 | 全局枚举 `GlobalBusinessEnum`、`GlobalExcelEnum` |
| `hacker` | 6 | 防作弊。`HData.lua` 里有 `HACKER_DATA_INIT`、重写后的 `pairs/ipairs` 和 `HACKER_TABLE_DB_CHECK`；另有 `CheatManager`、`ServerVerificationManager`、`BuildInGod`、`AttackDBCollect` |
| `handler` | 124 | 网络请求封装 `req_msg_*`、`client_msg_protocol` |
| `helper` | 8 | 静态工具：`GameHelper`、`LogicHelper`、`ViewHelper`、`StorageHelper`、`FightHelper`、`EntityHelper`、`StageHelper` |
| `imports` | 1480 | 常量和生成数据，详见 2.2 |
| `jit` | 13 | LuaJIT 自带的调试模块（`v.lua`、`dump.lua`）。运行时不加载 |
| `module` | 353 | **战斗和场景核心**，详见 2.1 |
| `net` | 11 | 网络：`NetWork`、`NetConnect`、`NetBuffer`、`NetMessage`、`NetTime`、`NetSafeReq` |
| `protocol` | 68 | 协议定义 `msg_cg_*`、`msg_xx_*`、`msg_cf_fight`（战斗服） |
| `scene` | 53 | 场景层：`GameManager`、`SceneManager`、`SceneManagerExternal`、`SceneFactory`、`SceneBase` → `GameScene` → `FightScene` → `NetworkFightScene`，以及 `scene/game/*`（约 38 种玩法场景） |
| `task` | 2 | `PathFindingManager`（寻路） |
| `tool` | 2 | `NetworkFightPlayback/NetworkFightPlaybackManager`（联机战斗回放） |
| `trigger` | 7 | 事件和定时器：`EventTrigger`（REGEVENT）、`TimerTrigger`（绘制帧）、**`LogicTimerTrigger`（逻辑帧定时器，用定点累加）**、`ViewTrigger`、`TutorialTrigger`、`event.lua` |
| `ui` | 2017 | 界面：`XViewManager`、`XViewFactory`、`ViewFightManager`（战斗数据采集）、`widget/Gamepad.lua`（虚拟摇杆和技能按钮）、`view/*` |
| `util` | 50 | `engine/`、`game/`（包括 `LanguageManager`、`InfoBar`）、`shader/`、`tool/` |

### 2.1 src/module

| 子目录 | 内容 |
|---|---|
| `ai` | `AiAgent.lua`：AI 代理。`initAgent` 通过 `AEEntityAgent:create()`（`AiAgent.lua:107`）创建 C++ behaviac agent。`update` 驱动 agent，并处理嘲讽和定时换目标（`:65-94`） |
| `behaviortree` | 自研 AEBT 行为树（节点是 C++ 的 `AEBTSelector/Sequence/Parallel/Condition/Action`）。`BehaviorManager.lua` 负责建树（`:74`）和递归解析（`:45`）。`BehaviorTree.lua` 是树实例。`actions/`（ActionBase 及约 40 个 Action，其中 **`AttackRole`/`AttackEffect`** 继承自 `ActionAttack`）；`conditions/`（ConditionBase 及约 50 个 Condition）。树的结构数据在 `src/imports/ConstBehaviorTree.lua`（`BEHAVIOR.ROLE/EFFECT/...`） |
| `buff` | `BuffPool`（每个实体一个）、`BuffBase`、`BuffCondition`、`xbasic/`、`xstatus/`。Buff 子类按名字动态加载（`BuffPool.lua:1140/1145`） |
| `camera` | `CameraManager`（`logicUpdate`/`drawUpdate`/`getSlowScale`）、`CameraShaker`、`CameraSlow`、`CameraFreeze`、`CameraMap`、`CameraMoveControl` |
| `component` | `ComponentBase`，以及 Avatar（Spine 表现）、Collision、Control、Decorator、Dialog、Displacement（位移曲线）、Go、NpcChat、Task、Title、Touch；`avatar/` 下有 AvatarRole、Pet、MainRole、CityRole 和 ArtifactSkin |
| `entity` | `EntityManager`，以及 EntityBase 和各实体类型（Role、Effect、Npc、Model、Obstacle、CityRole、Pet、Goods、Portal）；另有 `EntityAttribute`、`SkillAttribute`、`EntityExtraState` |
| `fsm` | `SimpleFsm`、`IState`。只有 UI 在用（`ui/ViewAbstructClass.lua`、`UiFashion/*`），战斗不用 |
| `layer` | `LayerManager` 和 10 个层（`LayerManager.lua:13-24`，顺序为 Map、Touch、Cover、Main、FrameFull、Frame、Dialog、Tutorial、Shade、Tips）。**`LayerMap`** 是战斗逻辑的入口 |
| `login` | `InitRequest`、`LoginProtocol`、`HotFix` |
| `map` | `MapManager` 和各地图层：Region、Trigger、**Entity**、Distant、Middle、Nearby、Ground、Shadow、Case、Light（`MapManager.lua:39-53`）。**`MapEntity`** 负责驱动实体 |
| `service` | 战斗服相关的本地服务：`FightServerManager`、`FightServerSkillDodge`、`FightServerSuperSkill`、`FightServerControlEntityProperty`、`FightServerTaskData` |
| `skill` | `SkillPool`（技能树 `tPool[槽位][连携][招式][步骤]`，见 `SkillPool.lua:27`）、`SkillBase`、`SkillHurt`（伤害结算）、`SkillAi`（神器/自动技能 AI） |
| `specialAbility` | `SpecialAbilityPool`、`SpecialAbilityBase`、`SpecialAbilityCondition`（被动或特殊能力） |
| `story` | `StoryManager`，剧情文件通过 `require("module/story/stor/"..)` 加载（`StoryManager.lua:115`） |
| `sync` | `SyncManager`（帧同步：`update(delta, handler)` 在 `:669`，`processSyncFrame` 在 `:278`，`setSyncBegin` 在 `:586`）、`SyncCityManager`（主城同步） |
| `touch` | `ControlManager`（输入转成实体控制事件，`update` 在 `:419`）、`TouchManager` |
| `tutorial` | `Tutorial.lua`（新手引导，驱动见 `SceneManagerExternal`） |

### 2.2 src/imports

| 子目录/文件 | 内容 |
|---|---|
| `Const.lua` / `ConstValue` / `ConstUI` / `ConstModel` / `ConstBusiness` / `ConstTest` / `ConstUserAgreement` / `StorageKey` / `GameResVersion` | 全局常量和开关，例如 `_GAME_FPS=60`（`Const.lua:734`）、`_GAME_NEW_SKILL_SYSTEM=false`（`:777`） |
| `ConstBehaviorTree.lua` | AEBT 树结构的 Lua 表 `BEHAVIOR`（`:6`；`ROLE` 在 `:264`，新技能系统版本在 `:551` 之后） |
| `files.lua` / `spines.lua` / `prefabs.lua` | 资源索引，由 `DBMap` 加载（`db/DBMap.lua:4-6`） |
| `table/` | 420 个导出的 Lua 数据表，例如 `skill_*`、`action_*`、`entity_*`、`buff_*`、`specialability_base`、`map_*` |
| `map/` | 924 个地图/房间场景文件（`act_XX_YY_ZZ.lua`），是 Cocos Creator 风格的序列化场景（`__type__`、`__id__`、`__uuid__`） |
| `transform_files/` | `assemble_{camp,city,fight}_{npc,portal}.lua`：NPC 和传送门的摆放数据 |
| `behaviac_exported/` | behaviac 导出物：`Entity.xml`（AI 树）和 `meta/Closers.meta.xml`。由 C++ 的 `AEEntityAgent` 调用 `btload("Entity")` 加载（`frameworks/runtime-src/Classes/external/behavior/AEEntityAgent.cpp:9`） |
| `shader/` | 各种 `.vert/.frag`：gray、blur、ghost、superArmor、light_spine 等 |
| `tutor/` | 新手引导脚本 `Tutor_*.lua` |

---

## 3. 模块加载：实际运行的系统与死代码

**运行时实际加载的战斗链路**（依据 `module/_init.lua` 的 require 链）：
- `module/_init.lua:5-37` 依次加载：fsm、BuffPool（它会 `loadlua` 进 BuffBase 和 BuffCondition，见 `BuffPool.lua:962`）、SpecialAbilityPool（加载 Base 和 Condition，见 `:300`）、BehaviorManager、BehaviorTree、ActionBase（它加载全部 Action，见 `ActionBase.lua:153-195`）、ConditionBase（加载全部 Condition，见 `ConditionBase.lua:55-117`）、camera\*、ComponentBase（加载全部 Component 和 Avatar，见 `ComponentBase.lua:11-30`）、ControlManager、TouchManager、EntityManager（加载全部 Entity 类，见 `EntityManager.lua:2-17`）、LayerManager、MapManager、AiAgent、SkillPool（加载 SkillBase 和 SkillHurt；SkillBase 再加载 SkillAi）、SyncManager、SyncCityManager、Tutorial、StoryManager、service。
- 每个 `EntityRole` 实例化的对象见 `module/entity/EntityRole.lua:636-668`：`SkillPool`、`BuffPool`、`SpecialAbilityPool`、`SkillHurt`、`SkillAi`（神器）、AEBT `BehaviorTree(BEHAVIOR.ROLE)`；如果 `bAi` 为真，还有 `AiAgent`（behaviac）。
- **移植时以这些为准**：`SkillPool`/`SkillBase`、`AttackRole`、AEBT（`BehaviorManager` + `ConstBehaviorTree`）负责角色行为，behaviac（`AiAgent` → `AEEntityAgent` → `Entity.xml`）负责 AI。

**死代码或不参与战斗的部分**：
- `_GAME_NEW_SKILL_SYSTEM` 分支（`ConditionBase.lua:58-65`、`ConstBehaviorTree.lua:551+`）。开关为 false（`Const.lua:777`），而且引用的 `module/behavior/condition/base/XCondition*` **目录不存在**，所以这个分支是死代码。
- `ConditionBase.lua:66-75` 的 else 分支（`ConditionAttackSlot/SkillStep/VectorIndex/Press/Release`）才是实际生效的分支。
- `module/fsm/*`：战斗不用，只有 UI 在用。
- `src/jit/*`：`jit.off()`，不 require。
- `module/camera/CameraMoveControl.lua`：`module/_init.lua:21` 加载了它，但全局没有其它引用（按 rg 结果），视为死代码。
- `hacker/AttackDBCollect.lua`：只在 `hacker/_init.lua` 里加载，没有其它引用。
- `ViewManager`：`LayerManager.lua:58` 把 `ViewManager:update` 注释掉了，实际使用的是 `XViewManager`。
- `tool/_init.lua:3-5`：回放 UI 被注释掉，只保留了 Manager。
- `db/DBMap.lua:3,5`：`assets`、`scenes` 表被注释。
- 以下属于非战斗系统，移植战斗时可以忽略：`SyncCityManager`、`EntityCityRole`、`Avatar*CityRole*`、`ComponentNpcChat/Task/Go/Dialog`、`StoryManager`、`Tutorial`、`cache/`、`handler/`、`aonesdk/`、`ui/view`。
- 未确认：`MapCase`、`MapLight` 只在 `MapManager` 的列表里出现，是否真的有地图用到它们，要看地图数据。

---

## 4. 帧循环

有两个调度器，都注册在 `scene/GameManager.lua:216-242`：
- **逻辑帧**：`scheduler:scheduleScriptFunc(logicUpdate, LOGIC_DT)`，其中 `LOGIC_DT = ENCRYPT_CONST._0_03333332`（`GameManager.lua:10`，**30Hz**）。
- **绘制帧**：`pRenderScene:scheduleUpdateWithPriorityLua(drawUpdate, 0)`，`DRAW_DT = 1/60`（`:12`，`:66`）。

逻辑帧的调用顺序：
```
GameManager:logicUpdate                         scene/GameManager.lua:128
 ├ SceneManagerExternal:beforeFixUpdate         scene/SceneManagerExternal.lua:133  (NetWork:update, keepLive)
 ├ LogicTimerTrigger:update(delta)              trigger/LogicTimerTrigger.lua:14    (联机时只在收到新同步帧后执行, GameManager.lua:140-148)
 ├ CheatManager:update
 └ SceneManagerExternal:afterFixUpdate          SceneManagerExternal.lua:143
    ├ Tutorial:logicUpdate(LOGIC_DT)
    ├ ControlManager:update(LOGIC_DT)           module/touch/ControlManager.lua:419
    └ LayerManager:update(LOGIC_DT)             module/layer/LayerManager.lua:51 → 各 Layer:update，然后 XViewManager:update
       └ LayerMap:update                        module/layer/LayerMap.lua:42
          ├ (非联机) updateMap(delta)
          └ (联机)  SyncManager:update(delta, updateMap)  module/sync/SyncManager.lua:669 → processSyncFrame
             LayerMap:updateMap                 LayerMap.lua:50
              ├ CameraManager:logicUpdate       module/camera/CameraManager.lua:137
              └ MapManager:update(delta*SlowScale)  module/map/MapManager.lua:118 → 各 Map 层
                 └ MapEntity:update             module/map/MapEntity.lua:76
                    ├ EntityManager:update      module/entity/EntityManager.lua:229
                    │    按组更新: Role → Effect → Npc → Model → Obstacle → CityRole → Pet → Goods → Portal (:231-397)
                    │    EntityRole:update      module/entity/EntityRole.lua:1049
                    │      SkillPool:update(:1053) → BuffPool(:1073) → SpecialAbilityPool(:1077) → HurtNum/Combo
                    │      → MP 回复/各 dealWith* → AiAgent:update(:1107/1112) → 身体抖动/检查
                    │      → EntityBase:update  module/entity/EntityBase.lua:167
                    │           控制事件队列 → pBehaviorTree:update(:184) → 各 Component:update(:187)
                    ├ SceneManager:update → 当前 Scene:update (SceneManager.lua:72; FightScene/GameScene:218)
                    ├ Sound:update
                    └ AECollision:getInstance():update(delta)  MapEntity.lua:84  (C++ 碰撞检测)
```
绘制帧：`GameManager:drawUpdate`（`:156`）先调用 `TimerTrigger:update`，再调用 `SceneManagerExternal:update`（`:122`），后者执行 `Tutorial:update` 和 `LayerManager:draw`，接着是 `LayerMap:draw`（`LayerMap.lua:57`），其中包括 `SyncManager:draw`、`CameraManager:drawUpdate` 和 `MapManager:draw`。实体的表现在 `EntityBase:draw` 中处理，它会调用各 Component 的 `draw`。
要点：所有逻辑累加都用 `AEUtil:FixPoint` 截断（例如 `LogicTimerTrigger.lua:27`、`SkillPool.lua:116`），随机数用 `AEUtil:GRandomN/F`。这些都是为了帧同步的确定性。

---

## 5. 战斗对象图

```
场景:  SceneBase (scene/SceneBase.lua:9)
        └ GameScene (scene/GameScene.lua:34)
           └ FightScene (scene/FightScene.lua:38)
              ├ NetworkFightScene (scene/NetworkFightScene.lua:22) → PVPScene (scene/game/PVPScene.lua:14) 等
              ├ FightDebugScene (scene/game/FightDebugScene.lua:10), LimitFightScene, ...
        NetworkFightDebugScene (scene/game/NetworkFightDebugScene.lua:10) 直接继承 SceneBase

单例(全局表): GameManager, SceneManager, SceneManagerExternal, LayerManager, MapManager(module/map/MapManager.lua:15),
               EntityManager, CameraManager, ControlManager(module/touch/ControlManager.lua:2), SyncManager(module/sync/SyncManager.lua:39),
               BehaviorManager(module/behaviortree/BehaviorManager.lua:9), FightServerManager(module/service/FightServerManager.lua:18)

层/地图: LayerBase (module/layer/LayerBase.lua:2) → LayerMap (LayerMap.lua:2)
         MapBase (module/map/MapBase.lua:2) → MapEntity (MapEntity.lua:2) / MapGround / ...

实体:  EntityBase (module/entity/EntityBase.lua:3)
        ├ EntityRole (EntityRole.lua:278)  [数据: EntityRoleData :11]
        ├ EntityEffect (EntityEffect.lua:23)   ├ EntityNpc (EntityNpc.lua:8)
        ├ EntityModel (EntityModel.lua:1)      ├ EntityObstacle (EntityObstacle.lua:25)
        ├ EntityPet (EntityPet.lua:11)         ├ EntityGoods (EntityGoods.lua:24)
        ├ EntityPortal (EntityPortal.lua:108)  └ EntityCityRole (EntityCityRole.lua:10)
       附属: EntityAttribute (EntityAttribute.lua:2), SkillAttribute (SkillAttribute.lua:2), EntityExtraState (EntityExtraState.lua:61)

EntityRole 持有:
  pSkillManager = SkillPool (module/skill/SkillPool.lua:6) → SkillBase (SkillBase.lua:4) → SkillAi (SkillAi.lua:2)
  pBuffPool = BuffPool (module/buff/BuffPool.lua:98) → BuffBase (BuffBase.lua:22) → xbasic/xstatus 子类
  pSpecialAbilityPool = SpecialAbilityPool (SpecialAbilityPool.lua:2) → SpecialAbilityBase (:2)
  pSkillHurt = SkillHurt (module/skill/SkillHurt.lua:5)
  pBehaviorTree = BehaviorTree (module/behaviortree/BehaviorTree.lua:9)，节点包括：
      ActionBase (actions/ActionBase.lua:5, 包装 C++ AEBTAction) → ActionAttack (ActionAttack.lua:5) → AttackRole (AttackRole.lua:7) / AttackEffect (AttackEffect.lua:2)
      ActionBase → ActionMove (ActionMove.lua:3), ActionCanBreakBase (ActionCanBreakBase.lua:2, cname 写的是 "ActionHit")
      ConditionBase (conditions/ConditionBase.lua:2, 包装 AEBTCondition:create())
  pAgent = AiAgent (module/ai/AiAgent.lua:29) → C++ AEEntityAgent (behaviac EntityAgent)
  tComponent: ComponentBase (module/component/ComponentBase.lua:32) 的子类
      ComponentAvatar (ComponentAvatar.lua:2) → AvatarRole (avatar/AvatarRole.lua:7, mixin ArtifactSkin) → AvatarMainRole → AvatarMainRolePartner；AvatarPet
      ComponentCollision (:4), ComponentDecorator (:22), ComponentDisplacement (:89, DisplacementData :2), ComponentControl, ComponentTitle, ComponentTouch, ...
```

---

## 6. 表与资源

- **原始表**放在 `src/imports/table/*.lua`（420 个），由工具导出。表里每个数值都包成 `HACKER_DATA_INIT(v)`，数组包成 `{ __real_value = {...} }`。例如 `skill_attack.lua` 开头就是这种结构；`entity_role.lua` 里 `HACKER_DATA_INIT` 出现了约 2 万次。
  - `HACKER_DATA_INIT` 定义在 `src/hacker/HData.lua:112`，返回一个 `HData` 对象（`:43-110`），它把值存成 `value*100000 - 随机factor`，`get()` 时还原并校验字符串副本。
  - `HData.lua:19-39` 重写了全局 `ipairs/pairs`：遇到 `__real_value` 就穿透，遇到 `isHack` 就自动 `:get()`。所以业务代码读到的是普通数字。**移植时可以直接把这层包装剥掉。**
  - `HACKER_TABLE_DB_CHECK` 在 DB 访问时做校验（例如 `db/DBAction.lua:11`）。
- **DB 层**是 `src/db/DBXxx.lua`，用 `loadlua "<短表名>"` 加载，能找到文件靠的是 `src/imports/table` 这个搜索路径。与战斗相关的表：
  - `DBSkill`（`db/DBSkill.lua:3-10`）：skill_ai、skill_hit、skill_hurt、skill_attack、skill_tree、skill_leaf、skill_chip、skill_rock……
  - `DBAction`（`db/DBAction.lua:3-7`）：action_attack、action_attack_effect(2)、action_camera、action_displacement
  - `DBEntity`（`db/DBEntity.lua:3-13`）：entity_ai、attribute、effect(2)、goods、npc、obstacle、pet、role、portal、fight_value
  - `DBBuff`（`db/DBBuff.lua:3-4`）：buff_rule、buff_base
  - `DBSpecialAbility`（`db/DBSpecialAbility.lua:2`）：specialability_base
  - `DBMap`（`db/DBMap.lua:4-20`）：files、spines、map_data、map_room(1/2/3)、map_stage、map_chapter、map_copy*、map_camp、map_city、map_province
- **表加载时机**：`db._init` 属于第 2 批（`main.lua:144-147`）。它在模块加载时就同步 `require` 全部表，没有懒加载。
- **地图**：`MapManager:load(mapDataId)`（`module/map/MapManager.lua:136`）先调用 `DBMap:getMapData`，得到 `map_key`，再加载 `src/imports/map/act_*.lua`（Creator 风格的节点树），然后按 `MapGroupOrderFile` 把节点分发到各 Map 层（`MapManager.lua:43-53`）。具体解析过程未确认，见 `MapBase.lua`。
- **Spine**：`res/animation/<类别>/<name>.{skel,atlas,png}`。C++ 层有 `AESpine`、`AESpineCache`，`ComponentAvatar` 持有 `pSpineBody`、`pSpineWeapon`、`pSpineWing`。
- **碰撞框**：`res/collider/<name>.collider`（二进制，按 spine 动画和动作逐帧存框）。由 C++ 的 `AESpineColliderManager`、`AECollision`（`Classes/external/collision/AECollision.h`）加载和检测，Lua 侧是 `ComponentCollision`。二进制格式未确认。
- **行为树**：AEBT 的结构在 Lua 表 `ConstBehaviorTree.lua` 里；behaviac 的树是 `src/imports/behaviac_exported/Entity.xml`。
- **UI**：`res/ui/*.csb`（Cocos Studio）。

---

## 7. 文件索引（战斗移植相关，约 60 个）

| 路径 | 作用 |
|---|---|
| `config.json` | 模拟器配置和入口 `src/main.lua` |
| `frameworks/runtime-src/Classes/AppDelegate.cpp` | 原生启动、搜索路径、Lua 注册 |
| `frameworks/runtime-src/Classes/scene/GameScene.cpp` | behaviac Workspace 初始化 |
| `frameworks/runtime-src/Classes/common/AEUtil.cpp` | FixPoint、随机数、适配等原生工具 |
| `frameworks/runtime-src/Classes/common/AERandom.h` | 确定性随机 |
| `frameworks/runtime-src/Classes/external/behavior/default/AEBTNode.h` | AEBT 行为树 C++ 节点 |
| `frameworks/runtime-src/Classes/external/behavior/AEEntityAgent.cpp` | behaviac agent 包装，`btload("Entity")` |
| `frameworks/runtime-src/Classes/external/collision/AECollision.h` | 碰撞检测单例 |
| `frameworks/runtime-src/Classes/scripting/lua-bindings/auto/api/*.lua` | C++ 导出给 Lua 的 API 清单 |
| `src/main.lua` | Lua 入口，分批加载清单，`loadlua`/`new`/`property` |
| `src/config.lua` | 调试和日志开关 |
| `src/scene/GameManager.lua` | 双调度器，logic/draw update |
| `src/scene/SceneManager.lua` | 场景切换，`update` 转发给当前场景 |
| `src/scene/SceneManagerExternal.lua` | before/after FixUpdate，驱动 Layer |
| `src/scene/SceneFactory.lua` | 按名字创建场景 |
| `src/scene/SceneBase.lua` | 场景基类 |
| `src/scene/GameScene.lua` | 带地图和房间状态的场景 |
| `src/scene/FightScene.lua` | 战斗场景基类：实体构造、复活、传送 |
| `src/scene/NetworkFightScene.lua` | 联机战斗场景 |
| `src/scene/game/FightDebugScene.lua` | 本地战斗调试场景 |
| `src/scene/game/PVPScene.lua` | PVP 场景 |
| `src/trigger/LogicTimerTrigger.lua` | 逻辑帧定时器（REGTIMER 类） |
| `src/trigger/EventTrigger.lua` | 全局事件系统 |
| `src/hacker/HData.lua` | `HACKER_DATA_INIT`，重写 pairs/ipairs |
| `src/imports/Const.lua` | 全局开关和常量 |
| `src/imports/ConstBehaviorTree.lua` | AEBT 树结构 `BEHAVIOR.*` |
| `src/imports/ConstValue.lua` | 数值常量 |
| `src/imports/behaviac_exported/Entity.xml` | behaviac AI 树 |
| `src/db/DBSkill.lua` | 技能表访问 |
| `src/db/DBAction.lua` | 动作、攻击、相机、位移表访问 |
| `src/db/DBEntity.lua` | 实体表访问 |
| `src/db/DBBuff.lua` | Buff 表访问 |
| `src/db/DBMap.lua` | 地图、房间、关卡表访问 |
| `src/module/_init.lua` | 战斗模块加载总表 |
| `src/module/layer/LayerManager.lua` | 层顺序，update/draw 分发 |
| `src/module/layer/LayerMap.lua` | 战斗逻辑入口（同步或本地） |
| `src/module/map/MapManager.lua` | 地图加载和各层更新 |
| `src/module/map/MapEntity.lua` | 驱动 EntityManager、Scene 和碰撞 |
| `src/module/map/MapBase.lua` | 地图层基类 |
| `src/module/entity/EntityManager.lua` | 实体容器，分组更新，查找 |
| `src/module/entity/EntityBase.lua` | 实体基类：事件队列、行为树、组件 |
| `src/module/entity/EntityRole.lua` | 角色：技能、Buff、AI、MP、冻结、狂暴等 |
| `src/module/entity/EntityEffect.lua` | 特效/飞行物实体 |
| `src/module/entity/EntityAttribute.lua` | 属性 |
| `src/module/entity/EntityExtraState.lua` | 额外状态 |
| `src/module/skill/SkillPool.lua` | 技能池（槽位、连携、招式、步骤） |
| `src/module/skill/SkillBase.lua` | 单个技能 |
| `src/module/skill/SkillHurt.lua` | 伤害结算 |
| `src/module/skill/SkillAi.lua` | 技能 AI（神器、自动释放） |
| `src/module/buff/BuffPool.lua` | Buff 容器，动态加载子类 |
| `src/module/buff/BuffBase.lua` | Buff 基类 |
| `src/module/buff/BuffCondition.lua` | Buff 触发条件 |
| `src/module/specialAbility/SpecialAbilityPool.lua` | 特殊能力池 |
| `src/module/behaviortree/BehaviorManager.lua` | AEBT 建树 |
| `src/module/behaviortree/BehaviorTree.lua` | 树实例 update |
| `src/module/behaviortree/actions/ActionBase.lua` | Action 基类和加载表 |
| `src/module/behaviortree/actions/ActionAttack.lua` | 攻击 Action 基类 |
| `src/module/behaviortree/actions/AttackRole.lua` | 角色攻击执行（核心） |
| `src/module/behaviortree/actions/AttackEffect.lua` | 特效攻击执行 |
| `src/module/behaviortree/conditions/ConditionBase.lua` | Condition 基类和加载表 |
| `src/module/ai/AiAgent.lua` | behaviac AI 代理 |
| `src/module/component/ComponentBase.lua` | 组件基类和加载表 |
| `src/module/component/ComponentAvatar.lua` | Spine 表现 |
| `src/module/component/ComponentCollision.lua` | 碰撞组件 |
| `src/module/component/ComponentDisplacement.lua` | 位移曲线 |
| `src/module/camera/CameraManager.lua` | 相机、慢动作倍率 |
| `src/module/touch/ControlManager.lua` | 输入转控制事件 |
| `src/module/sync/SyncManager.lua` | 帧同步 |
| `src/module/service/FightServerManager.lua` | 战斗服本地服务 |
| `src/ui/widget/Gamepad.lua` | 虚拟摇杆和技能按钮（读取 SkillPool） |
| `src/ui/ViewFightManager.lua` | 战斗数据采集和实体释放记录 |
