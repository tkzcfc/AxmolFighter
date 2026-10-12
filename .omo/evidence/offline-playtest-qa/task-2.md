# Task 2 evidence — import skill_tree and skill_leaf

Plan: `.omo/plans/offline-playtest-qa.md` todo 2. Packer / C++ structs are todo 4; not run here.

## Convert

Workdir: `AxmolFighter-Tools/config_converter/script`

```text
lua migrate/import/run_table_convert.lua --src D:/work/AxmolFighter/heiyue --axmol D:/work/AxmolFighter --kinds skill_tree,skill_leaf
```

Exit: 0

```text
[table-convert] loading map_data / map_room indexes ...
[table-convert] skill_tree: filled 0 absent keys
[table-convert] skill_leaf: filled 0 absent keys
[table-convert] skill_tree: wrote 9 rows -> D:/work/AxmolFighter/AxmolFighter-Config/table/skill_tree.lua
[table-convert] skill_leaf: wrote 311 rows -> D:/work/AxmolFighter/AxmolFighter-Config/table/skill_leaf.lua
[table-convert] done rows=320 missing=0
```

Output is a contiguous array (`local M = { { ... }, ... } return M`), camelCase, defaults expanded.

## Checks

Tree ids: `1, 2, 4, 11, 12, 21, 22, 41, 42`. No id 3.

Tree 1 (sparse source row, no `id`): `id = 1`, `professionType = 1`, default `leafIds` 10010..10120.

`rg "professionType = 4" AxmolFighter-Config/table/skill_tree.lua`:

```text
89:        professionType = 4,
```

Tree 4: `leafIds` 40010, 40020, 40030, 40040, 40050, 40060, 40070, 40080, 40100, 40120; `leafRubId` 40110; `leafBuffId` 40090.

`rg -C 8 "id = 40010" AxmolFighter-Config/table/skill_leaf.lua`:

```text
3758:        id = 40010,
3763:        skillId = 980000,
```

Leaf key 0 kept `id = 0`, `skillId = 920050` (not the default skill id).

## Unknown kind

```text
lua migrate/import/run_table_convert.lua --src D:/work/AxmolFighter/heiyue --axmol D:/work/AxmolFighter --kinds nosuch
```

Exit: 1

```text
D:\bin\lua.exe: migrate/import/run_table_convert.lua:105: unknown kind: nosuch
```

## Registration

- `KIND_SPECS.skill_tree` / `skill_leaf` with `idFromKey = 'id'` (map key overwrites default `id` after `__default_table` expansion).
- `COMBAT_KINDS` includes both kinds.

## Re-run on the committed converter snapshot

Same command, after isolating the spec onto HEAD (no other converter edits). Exit: 0

```text
[table-convert] skill_tree: wrote 9 rows -> D:/work/AxmolFighter/AxmolFighter-Config/table/skill_tree.lua
[table-convert] skill_leaf: wrote 311 rows -> D:/work/AxmolFighter/AxmolFighter-Config/table/skill_leaf.lua
[table-convert] done rows=320 missing=0
```

## Commits

- AxmolFighter-Tools `183c6cd4f9e2e97dd2f44a2c1cc51c67c1d19139` `feat(config): import skill_tree and skill_leaf KIND_SPECS` (TableConvert.lua + run_table_convert.lua only)
- AxmolFighter-Config `25b2c0d2ee8fc5b4f7976a4d7cf8c0cf0401eb31` `feat(table): add flattened skill_tree and skill_leaf`
- No root submodule pointer commit. No push.

## Re-verify (this worker session)

Same convert command from `AxmolFighter-Tools/config_converter/script`. Exit: 0

```text
[table-convert] skill_tree: filled 0 absent keys
[table-convert] skill_leaf: filled 0 absent keys
[table-convert] skill_tree: wrote 9 rows -> D:/work/AxmolFighter/AxmolFighter-Config/table/skill_tree.lua
[table-convert] skill_leaf: wrote 311 rows -> D:/work/AxmolFighter/AxmolFighter-Config/table/skill_leaf.lua
[table-convert] done rows=320 missing=0
```

`--kinds nosuch` Exit: 1

```text
D:\bin\lua.exe: migrate/import/run_table_convert.lua:105: unknown kind: nosuch
```

Config `table/skill_tree.lua` and `table/skill_leaf.lua` stayed clean vs `25b2c0d` after re-convert.
Tools working tree remains dirty with unrelated converter edits; those were not committed.
