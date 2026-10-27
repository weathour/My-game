# Enemy Profile Refactor

> 2026-10-26整理：本页保留旧版本的工程与测量记录，正文中的“当前”“已定”“后续”指记录时点；不作为新体系要求或当前任务队列。目标以[当前设计共识](00_当前设计共识.md)为准，新设计尚未实施。


目标：怪物数据从脚本大字典迁移到资源文件，保持现有玩法不变。

## 当前结构

- `scripts/enemy/enemy_profile.gd`
  - 定义 `EnemyProfile` Resource。
  - 基础字段保存血量、速度、伤害、经验、碰撞半径、视觉场景。
  - 特殊字段放在 `extra`，避免把没有配置的默认值误写进运行时。

- `data/enemies/*.tres`
  - 每种怪物一个 profile。
  - 新增怪物时优先新增 `.tres`，不要继续往脚本里塞大字典。

- `scripts/enemy/enemy_archetype_database.gd`
  - 只负责把 `archetype` 映射到 `.tres`。
  - 对外仍返回 `Dictionary`，兼容现有生成和应用流程。

- `scripts/enemies/enemy_profile_applier.gd`
  - 把 profile 字典应用到运行时 enemy。

- `scripts/enemies/enemy_visuals.gd`
  - 使用 `profile_visual_scene` 创建视觉模型。
  - 不再硬编码具体怪物素材路径。
  - 没有 profile 视觉时回退到 `Polygon2D` 兜底。

## 不变量

本阶段不改变：

- 怪物血量、速度、伤害、经验。
- 怪物碰撞半径。
- 怪物视觉模型对应关系。
- 刷怪逻辑。
- 小 Boss / Boss 行为。

## 验证

`enemy_profile_resource_smoke.gd` 检查资源字段与基本范围；`enemy_profile_snapshot_smoke.gd` 只锁定稳定的 archetype、行为和视觉对应关系，不复制会持续调参的血量、速度等数值。

运行：

```bash
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --script scripts/tests/enemy_profile_resource_smoke.gd
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --script scripts/tests/enemy_profile_snapshot_smoke.gd
```

预期输出：

```text
enemy_profile_resource_smoke: OK
enemy_profile_snapshot_smoke: OK
```

## 新增怪物

1. 在 `data/enemies/` 下新增一个 `.tres`。
2. 在 `EnemyProfile.visual_scene` 里指定视觉场景。
3. 在 `scripts/enemy/enemy_archetype_database.gd` 的 `PROFILE_PATHS` 加一行 archetype 到 profile 路径的映射。
4. 不要在 `enemy_visuals.gd` 里新增具体怪物判断。
