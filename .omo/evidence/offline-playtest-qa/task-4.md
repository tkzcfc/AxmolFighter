# Task 4 — skill_tree / skill_leaf pack

## Scaffold

`config_converter.exe scaffold <ConfigDir> skill_tree`:

```
struct skill_treeConfig {
    int32_t descId;
    int32_t id;
    std::vector<int32_t> leafBuffId;
    std::vector<int32_t> leafIds;
    std::vector<int32_t> leafRubId;
    std::vector<int32_t> leafRubPlace;
    int32_t nameId;
    std::string professionBackground;
    int32_t professionType;
    int32_t treeType;
    std::string ui;
}
```

`scaffold skill_leaf`:

```
struct skill_leafConfig {
    int32_t attackType;
    int32_t chain;
    std::vector<int32_t> chipIds;
    int32_t descId;
    int32_t hurtType;
    std::string icon;
    int32_t id;
    int32_t nameId;
    int32_t overflowLevelLimit;
    int32_t partnerUnlock;
    Fixed | int32_t skillDamageFactor;
    int32_t skillId;
    int32_t skillType;
    std::vector<int32_t> tag;
    std::vector<int32_t> unlockLeafIds;
    std::vector<int32_t> unlockLeafLevels;
    int32_t unlockRoleLevel;
    int32_t upgradeConsumeFactor;
    int32_t upgradeLevelLimit;
    int32_t upgradeLevelStep;
    int32_t videoId;
}
```

`skillDamageFactor` 记为 `Fixed`（与 `SkillRockConfig` 相同）。`LuaReader::readFixed` 接受任意 Lua number，整数行不会因此失败。`chipIds` 是 `vector<int32_t>`，没有加入 `MG_CONFIG_REFS`。

## Schema hash

| | value |
|---|---|
| before (config.bin header) | 735714878451861681 |
| after pack | 15664757811292255776 |

头部为 `MGCF` + version `1`（大端 u32）+ schemaHash（大端 u64）。

## G4 pack

`pwsh AxmolFighter-Tools/config_converter/run_config_converter.ps1 --skip-configure`

- exit 0
- `skill_tree: 9 rows`
- `skill_leaf: 311 rows`
- refs: `skill_leaf.skillId`、`skill_tree.leafIds`、`leafRubId`、`leafBuffId` dangling=0
- `Wrote ...\\config.bin schemaHash=15664757811292255776`

## Replay header

`Replay::serialize`：`MGRP` + `uint32 version=1` + `uint64 schemaHash`，`ByteBuffer` 在 `MG_USE_BIG_ENDIAN` 下写大端。

只改写 offset 8 的 8 字节。三个文件旧 hash 均为 `735714878451861681`，新字节 `D9-64-66-3B-E2-99-B6-20`：

- `TestsHeadless/data/replays/copy101_room2010101.mgrp`
- `TestsHeadless/data/replays/defense2071501.mgrp`
- `TestsHeadless/data/replays/arena30002.mgrp`

未重录 payload。未改 `spawnRole`。

## G1 / G2

- G1 `pwsh AxmolFighter-Client/TestsHeadless/run_headless_tests.ps1`：`[doctest] test cases: 254 | 254 passed | 0 failed`，Status SUCCESS，exit 0。编译包含 `SkillTreeConfigTest.cpp` 与 `DeterminismTest.cpp`。
- G2 `pwsh AxmolFighter-Client/TestsHeadless/check_rules.ps1`：exit 0。

用例：`SkillTree config loads tree 4 and leaf 40010` — `find<SkillTreeConfig>(4)->professionType==4`，`leafIds.size()>=10`，`find<SkillLeafConfig>(40010)->skillId==980000`。

## Docs

- `table-kind-mapping.md` 增加 `skill_tree` / `skill_leaf` 行（KeyById）。未改 skill_rock “Pack 尚未接线”文案。
- 根 `README.md` 工作区把“40 种”改为“42 种”。该文件还有大量未提交的架构文档差异，未做根仓库提交，避免带上子模块指针或无关文档。
