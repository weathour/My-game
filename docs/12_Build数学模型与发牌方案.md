# Build 数学模型与发牌方案

> 首批卡牌、英雄特性 6/12/18/25 质变、能力包数据与协同连结见 [13_Build首批卡牌与等级节奏.md](13_Build首批卡牌与等级节奏.md)。
> 完整首批版纯模型实现入口：`scripts/build/build_first_batch_database.gd`、`scripts/build/build_first_batch_model.gd`；smoke：`scripts/tests/build_first_batch_model_smoke.gd`。

本文档描述下一代 Build 系统的完整设计模型。目标是把“英雄特性、英雄卡、队伍共鸣卡、通用卡”从经验性设计，整理成可实现、可测试、可调参的数学模型。

核心结论：

- 队伍经验等级共享，不拆成三个英雄经验条。
- 英雄成长以“构筑投入 / 特性深度”分开记录，而不是独立升级刷经验。
- 不使用“心愿”系统；中期转向由玩家近期选卡形成的“动量”自动驱动。
- 不固定主 C / 副 C / 辅助模板；系统只记录英雄、时机、功能、状态传递和轮转关系。
- 每次升级仍然三选一，但三张卡分别由不同槽位生成：延续、协同、转向/补缺。

---

## 1. 设计目标

### 1.1 必须满足

1. 鼓励三英雄配合，而不是只养单人。
2. 不强迫固定职责配比；允许三人都是输出，也允许控制、保护、回能等功能组合。
3. 玩家前期选择应该有延续性，不被巨大卡池随机打断。
4. 玩家中期应该能转向，例如前期剑士投入较高，中期连续选择枪手后，枪手能成为新的构筑重心。
5. 卡池可以很大，但每次升级给出的 3 张卡必须职责清晰。
6. Boss 奖励用于阶段性突破，不永久锁死路线。

### 1.2 不做什么

- 不做三个英雄独立经验等级。
- 不做显式心愿 / 追踪按钮。
- 不做隐藏复杂配方；共鸣出现原因应尽量可解释。
- 不做“一主一副一辅”为唯一最优解。
- 不从全卡池无约束随机抽 3 张。

---

## 2. 基础集合

### 2.1 英雄集合

```text
R = {swordsman, gunner, mage}
```

### 2.2 时机标签

```text
T = {
  entry,      # 入场
  active,     # 主战 / 在场输出
  exit,       # 离场
  ultimate    # 大招
}
```

### 2.3 功能标签

```text
F = {
  burst,      # 爆发
  sustain,    # 持续输出
  control,    # 控制
  survival,   # 生存
  energy,     # 回能
  domain,     # 领域
  mark,       # 标记
  projectile, # 弹幕 / 弹道
  mobility,   # 位移 / 机动
  shield,     # 护盾
  lifesteal   # 吸血 / 回复
}
```

### 2.4 状态传递标签

状态传递是三英雄配合的核心。每张卡可以制造、消耗或放大某种状态。

```text
S = {
  armor_break,  # 破甲
  marked,       # 标记
  slowed,       # 减速
  shocked,      # 感电
  burning,      # 灼烧
  vulnerable,   # 易伤
  overdrive,    # 过载
  field,        # 领域
  guard,        # 守护
  charge        # 蓄能
}
```

一张卡可以：

```text
produce: 制造状态
consume: 消耗状态
amplify: 放大状态收益
pass_next: 增强下一名英雄
inherit_prev: 继承上一名英雄留下的效果
```

### 2.5 机制标签

功能标签描述“这张卡大致做什么”，机制标签描述“它用哪套规则做”。机制标签用于支持后续新增流派，例如召唤流、治疗推进流，而不需要重写发牌模型。

```text
M = {
  direct_hit,        # 直接命中
  projectile_chain, # 弹道链式命中
  summon_unit,      # 召唤单位
  command_summon,   # 指挥召唤物集火 / 转移
  heal,             # 治疗
  overheal,         # 过量治疗转护盾 / 资源
  push,             # 推开 / 推进敌人
  collision,        # 撞墙 / 撞敌伤害
  field_tick,       # 领域持续跳伤
  dot,              # 持续伤害
  execute,          # 斩杀
  reflect,          # 反击 / 反弹
  resource_loop     # 回能 / 回血 / 冷却循环
}
```

机制标签允许两个看起来不同的门派互相连接。例如“召唤物在领域内攻击更快”同时属于 `summon_unit` 与 `field_tick`；“过量治疗形成冲击波”同时属于 `overheal` 与 `push`。

### 2.6 流派 / 门派原型

“门派”不是固定职业，也不是强制路线，而是一组可识别的构筑原型。它的作用是让系统知道当前局正在靠什么赢，并据此发放延续、桥接和突破卡。

```text
A = {
  entry_burst,       # 入场爆发 / 破阵
  projectile_storm,  # 弹幕 / 过载 / 穿透
  domain_blast,      # 领域 / 轰炸 / 范围清场
  mark_execute,      # 标记 / 集火 / 斩杀
  control_lock,      # 控制 / 减速 / 冻结 / 压制
  ultimate_cycle,    # 大招循环 / 回能
  guard_counter,     # 守护 / 反击 / 受击收益
  summon_swarm,      # 召唤物 / 仆从 / 协同作战
  healing_push,      # 治疗 / 过量治疗 / 推进冲撞
  lifesteal_grind    # 吸血 / 持久战 / 续航压制
}
```

每张卡可以同时属于多个门派。这样可以形成“混血卡”：

```text
星灾傀儡 = summon_swarm 0.7 + domain_blast 0.5
圣盾冲潮 = healing_push 0.8 + guard_counter 0.4 + control_lock 0.2
破阵号令 = entry_burst 0.6 + summon_swarm 0.4
```

混血卡是保证多样化的关键，因为它们让玩家能从一种门派平滑转向另一种门派，而不是被单一路线锁死。

### 2.7 配比向量

配比不是“最佳模板”，而是对当前构筑结构的数学描述。

```text
role_mix[r] = role_points[r] / sum(role_points)
function_mix[f] = function_points[f] / sum(function_points)
archetype_mix[a] = archetype_points[a] / sum(archetype_points)
```

系统可以识别但不强制以下配比：

```text
三输出轮转：三个英雄 role_mix 接近，burst/sustain/projectile/domain 较高。
双核心接力：两个英雄 role_mix 较高，二者 edge_points 较高。
单核带队：一个英雄 role_mix 很高，但其他英雄 pass_next / inherit_prev / edge 有贡献。
三功能轮转：输出、控制、生存、回能等 function_mix 较均衡。
召唤核心：summon_swarm / summon_unit 较高，英雄配比可单核、双核或三人均衡。
奶推核心：healing_push / heal / overheal / push 较高，输出来自推进、撞击、护盾爆发或续航压制。
```

因此模型不会规定“必须一主一副一辅”。它只描述：玩家当前把资源投向了哪些英雄、哪些机制、哪些状态传递。

### 2.8 英雄亲和张量

英雄不是全能模板。每个英雄对“门派、机制、功能”的组合有不同亲和度。

```text
Affinity[r, a, m, f] ∈ [0, 1]
```

含义：英雄 `r` 用机制 `m` 在门派 `a` 中承担功能 `f` 的自然程度。

示例：

```text
Affinity[swordsman, entry_burst, direct_hit, burst] = 0.95
Affinity[swordsman, summon_swarm, summon_unit, taunt] = 0.55
Affinity[swordsman, summon_swarm, summon_unit, heal] = 0.20

Affinity[gunner, projectile_storm, projectile_chain, sustain] = 0.95
Affinity[gunner, summon_swarm, summon_unit, mark] = 0.75
Affinity[gunner, healing_push, heal, survival] = 0.45

Affinity[mage, domain_blast, field_tick, burst] = 0.95
Affinity[mage, summon_swarm, summon_unit, taunt] = 0.75
Affinity[mage, healing_push, heal, survival] = 0.65
```

亲和度不是硬禁用，而是决定：

```text
高亲和：可以成为完整能力包和主构筑。
中亲和：适合桥接、变体或副构筑。
低亲和：只适合稀有卡、Boss 特殊卡或不进入普通池。
```

建议初始阈值：

```text
core_affinity >= 0.70      可做完整能力包
bridge_affinity >= 0.40    可做桥接或低阶变体
rare_affinity >= 0.20      只能做稀有/特殊
< 0.20                     默认不做
```

### 2.9 能力包节点

能力包是新系统的基本设计单位，比“路线”更细，也比“单卡”更稳定。

```text
AbilityPackage p = {
  package_id,
  role_id,
  archetype_id,
  mechanic_profile,
  function_profile,
  state_profile,
  timing_profile,
  affinity_score,
  coverage_role,
  bridge_to,
  bridge_from
}
```

它回答四个问题：

```text
谁来做？          role_id
用什么方式做？    mechanic_profile
最终解决什么？    function_profile
如何和队友连接？  state_profile / bridge_to / bridge_from
```

例如：

```text
剑士·血潮破阵
role: swordsman
archetype: healing_push + entry_burst
mechanic: direct_hit + heal + overheal + push
function: burst + survival + control
state: armor_break + guard
bridge: entry_burst -> healing_push
```

```text
术师·守护傀儡
role: mage
archetype: summon_swarm + control_lock
mechanic: summon_unit + command_summon + field_tick
function: taunt + survival + control
state: field + guard + slowed
bridge: domain_blast -> summon_swarm
```

注意：同样是召唤，功能结果可以不同。召唤物可以输出、嘲讽、治疗、挡伤、爆炸、聚怪或搬运状态。

### 2.10 能力包图

所有能力包组成一张图：

```text
G_package = (P, E)
```

节点 `P` 是能力包，边 `E` 是可转移、可共鸣或可继承关系。

边类型：

```text
continue_edge: 同英雄同门派延续
bridge_edge:   同英雄跨门派转向
relay_edge:    不同英雄状态接力
mirror_edge:   不同英雄使用相似机制但不同功能
capstone_edge: 指向突破 / 终式
```

发牌时不再只是从“卡池”抽卡，而是在能力包图上做局部游走：

```text
当前位置 = 玩家已投入能力包的加权中心
延续槽 = 沿 continue_edge 找深化
协同槽 = 沿 relay_edge / mirror_edge 找队伍配合
转向槽 = 沿 bridge_edge 找可理解的新方向
Boss = 沿 capstone_edge 找阶段突破
```

这让中期转向不是随机跳跃，而是从已有能力包沿桥接边移动。

---

## 3. 卡牌向量模型

每张卡不是单纯效果文本，而是一个带权向量。

```text
Card c = {
  package_id:         String,
  role_weights:       Vector[R],
  route_weights:      Vector[Route],
  timing_weights:     Vector[T],
  function_weights:   Vector[F],
  mechanic_weights:   Vector[M],
  archetype_weights:  Vector[A],
  produce_weights:    Vector[S],
  consume_weights:    Vector[S],
  amplify_weights:    Vector[S],
  edge_weights:       Matrix[R -> R],
  bridge_weights:     Matrix[A -> A],
  package_edges:      Vector[PackageEdge],
  affinity_score:     float,
  novelty_score:      float,
  tier:               int,
  base_weight:        float,
  slot_affinity:      Vector[Slot]
}
```

### 3.1 示例：剑士破阵步

```text
role_weights:
  swordsman: 1.0

timing_weights:
  entry: 1.0

package_id:
  swordsman_entry_burst_break

function_weights:
  burst: 0.8
  mobility: 0.5
  survival: 0.3

mechanic_weights:
  direct_hit: 0.8

archetype_weights:
  entry_burst: 0.9

produce_weights:
  armor_break: 0.8

edge_weights:
  swordsman -> gunner: 0.2
  swordsman -> mage: 0.2
```

含义：剑士入场爆发卡，同时制造破甲，为后续枪手或术师接力留下可能。

### 3.2 示例：枪手火线追击

```text
role_weights:
  gunner: 1.0

timing_weights:
  active: 1.0

function_weights:
  projectile: 0.9
  sustain: 0.6
  burst: 0.3

mechanic_weights:
  projectile_chain: 0.8

archetype_weights:
  projectile_storm: 0.8
  mark_execute: 0.2

consume_weights:
  armor_break: 0.8
  marked: 0.5

edge_weights:
  swordsman -> gunner: 0.6
  mage -> gunner: 0.3
```

含义：枪手可以消耗剑士破甲或术师标记，形成接力输出。

### 3.3 示例：术师星灾符印

```text
role_weights:
  mage: 1.0

timing_weights:
  exit: 0.8
  entry: 0.4

function_weights:
  domain: 0.8
  burst: 0.6
  control: 0.3

mechanic_weights:
  field_tick: 0.8

archetype_weights:
  domain_blast: 0.9
  control_lock: 0.2

produce_weights:
  field: 0.8
  slowed: 0.3

pass_next:
  field: 0.6

edge_weights:
  mage -> swordsman: 0.4
  mage -> gunner: 0.4
```

含义：术师不一定是辅助；它可以作为领域输出，也可以给下一名英雄提供场地收益。

---

## 4. 当前构筑状态

玩家选过的卡累加形成当前 Build 状态。

```text
B_n = Σ c_i, i = 1..n
```

实际实现不需要存完整高维向量，可拆成几个字典：

```text
role_points:       Dictionary[role_id -> float]
route_points:      Dictionary[route_id -> float]
timing_points:     Dictionary[timing_tag -> float]
function_points:   Dictionary[function_tag -> float]
mechanic_points:   Dictionary[mechanic_tag -> float]
archetype_points:  Dictionary[archetype_id -> float]
produce_points:    Dictionary[state_tag -> float]
consume_points:    Dictionary[state_tag -> float]
amplify_points:    Dictionary[state_tag -> float]
edge_points:       Dictionary["from->to" -> float]
bridge_points:     Dictionary["archetype_a->archetype_b" -> float]
package_points:    Dictionary[package_id -> float]
package_position:  Dictionary[package_id -> float]
recent_momentum:   Dictionary[tag_or_role_or_archetype_or_package -> float]
route_droughts:    Dictionary[route_id -> int]
package_droughts:  Dictionary[package_id -> int]
rejection_memory:  Dictionary[card_id -> float]
```

### 4.1 英雄投入

```text
role_points[r] += card.role_weights[r]
```

它表示本局对某英雄的构筑投入，不是英雄经验等级。

### 4.2 路线投入

```text
route_points[route] += card.route_weights[route]
```

例如：

```text
swordsman_break
swordsman_blood
swordsman_guard
gunner_overdrive
gunner_mark
gunner_suppress
mage_starfall
mage_thunder
mage_frost
```

### 4.3 关系边

```text
edge_points[a->b] += card.edge_weights[a->b]
```

关系边表达“谁给谁创造收益”。例如：

```text
swordsman -> gunner = 3.0
```

说明当前局剑士到枪手的接力关系较强。

### 4.4 门派分与桥接分

```text
archetype_points[a] += card.archetype_weights[a]
bridge_points[a->b] += card.bridge_weights[a->b]
```

门派分用于识别当前构筑，例如 `summon_swarm` 或 `healing_push`。桥接分用于识别玩家是否正在从一个门派过渡到另一个门派，例如：

```text
domain_blast -> summon_swarm
healing_push -> guard_counter
projectile_storm -> mark_execute
```

桥接卡越多，中期转向越自然；如果一个新门派没有桥接卡，它就只能作为独立路线，很难在中期进入。

### 4.5 能力包位置

```text
package_points[p] += card.package_weight[p]
package_position[p] = normalized(package_points[p] + recent_momentum[p])
```

`package_position` 表示玩家当前在能力包图上的位置。延续、协同、转向和 Boss 突破都可以从这个位置出发，沿不同边找候选卡。

```text
ContinueCandidates = neighbors(position, continue_edge)
LinkCandidates     = neighbors(position, relay_edge or mirror_edge)
PivotCandidates    = neighbors(position, bridge_edge)
BossCandidates     = neighbors(position, capstone_edge)
```

这样“转向”不是从全卡池随机给一个新流派，而是从当前能力包走到相邻能力包。

---

## 5. 动量模型：不用心愿也能中期转向

玩家不需要手动设置心愿。系统根据最近选择自动形成动量。

### 5.1 指数衰减动量

每次选卡后更新：

```text
M_t(x) = λ * M_{t-1}(x) + I_x(card)
```

建议初始参数：

```text
λ = 0.65
```

其中 `x` 可以是：

```text
英雄：swordsman / gunner / mage
路线：swordsman_break / gunner_overdrive
标签：entry / exit / burst / domain
```

`I_x(card)` 是当前卡在该维度的权重。

### 5.2 动量的作用

如果玩家前期投入剑士，但中期连续选择枪手：

```text
role_points.swordsman 高
recent_momentum.gunner 高
```

系统会给出：

```text
剑士延续卡
枪手竞争卡
剑士+枪手共鸣卡
```

如果玩家继续选枪手，枪手动量会推动枪手成为新的构筑重心。

---

## 6. 协同评分模型

卡牌和当前 Build 的适配度由协同评分计算。

### 6.1 状态制造 / 消耗匹配

一张卡如果能消耗当前 Build 已经大量制造的状态，它应该更容易出现。

```text
consume_match(c, B) = dot(c.consume_weights, B.produce_points)
```

一张卡如果能制造当前 Build 已经擅长消耗的状态，也应该更容易出现。

```text
produce_match(c, B) = dot(c.produce_weights, B.consume_points)
```

### 6.2 轮转边匹配

如果当前存在强关系边 `a -> b`，那么强化这条边的卡应更容易出现。

```text
edge_match(c, B) = Σ c.edge_weights[a->b] * B.edge_points[a->b]
```

### 6.3 标签相似度

用于延续当前战术方向。

```text
tag_match(c, B) =
  dot(c.timing_weights, B.timing_points)
+ dot(c.function_weights, B.function_points)
```

### 6.4 门派匹配

门派匹配用于保证召唤流、奶推流、领域流等能被系统识别，而不只是靠英雄或功能标签。

```text
archetype_match(c, B) = dot(c.archetype_weights, B.archetype_points)
mechanic_match(c, B) = dot(c.mechanic_weights, B.mechanic_points)
```

如果当前局已经有 `summon_swarm`，召唤延续卡会升权；如果当前局有 `healing_push`，治疗推进相关卡会升权。

### 6.5 桥接匹配

桥接匹配用于支持中期转向和混合门派。

```text
bridge_match(c, B) = Σ c.bridge_weights[a->b] * B.archetype_points[a]
```

例如玩家已有领域流，`domain_blast -> summon_swarm` 的桥接卡会更容易出；玩家已有守护/治疗，`guard_counter -> healing_push` 的桥接卡会更容易出。

### 6.6 亲和评分

亲和评分决定一张卡是否适合普通池、桥接池或稀有池。

```text
affinity(c) = Σ role_weights[r] * archetype_weights[a] * mechanic_weights[m] * function_weights[f] * Affinity[r,a,m,f]
```

如果 `affinity(c)` 太低，卡不会进入普通升级池；如果中等，则主要进入转向槽或 Boss 特殊奖励；如果高，则可作为稳定延续卡。

```text
affinity_gate(c) =
  1.00, if affinity >= core_affinity
  0.60, if affinity >= bridge_affinity
  0.25, if affinity >= rare_affinity
  0.00, otherwise
```

这能避免“每个英雄什么都能做”的全能化问题。

### 6.7 能力包图距离

从当前能力包位置到候选卡能力包的距离决定它像“延续”还是“跳跃”。

```text
package_distance(c, B) = shortest_path_distance(B.package_position, c.package_id, G_package)
package_proximity(c, B) = 1 / (1 + package_distance(c, B))
```

边有不同代价：

```text
continue_edge cost = 1
relay_edge    cost = 1
mirror_edge   cost = 1.5
bridge_edge   cost = 2
capstone_edge cost = 2.5
missing edge  cost = infinity
```

转向槽允许较远距离；延续槽只接受近距离。

### 6.8 饱和惩罚

为了避免系统把玩家越推越窄，最高门派或最高功能达到一定浓度后，继续发完全同质卡会降权。

```text
saturation(x) = score(x) / (score(x) + k)
saturation_penalty(c, B) = Σ c.tag_weight[x] * max(0, saturation(x) - threshold)
```

建议初始值：

```text
k = 4.0
threshold = 0.62
```

饱和惩罚不是禁止继续强化，而是让协同槽和转向槽更愿意给桥接卡、第二门派卡或第三英雄接入卡。

### 6.9 总协同分

```text
Synergy(c, B) =
  0.25 * consume_match(c, B)
+ 0.18 * produce_match(c, B)
+ 0.18 * edge_match(c, B)
+ 0.14 * archetype_match(c, B)
+ 0.10 * bridge_match(c, B)
+ 0.08 * package_proximity(c, B)
+ 0.07 * tag_match(c, B)
+ 0.10 * affinity(c)
- 0.20 * saturation_penalty(c, B)
```

初始权重可调。这里故意让“制造/消耗状态闭环”和“门派识别”比单纯标签相似更重要。

---

## 7. 三选一发牌模型

每次升级仍然只给 3 张卡，但三张卡由不同槽位生成。

```text
Slot 1: 延续槽 Continue
Slot 2: 协同槽 Link
Slot 3: 转向 / 补缺槽 Pivot
```

这三个槽位不是 UI 上必须写出来的分类，而是后台生成逻辑。

---

## 8. 槽位权重函数

### 8.1 延续槽

目的：保证玩家已投入路线不会断供。

```text
W_continue(c) =
  base(c)
+ 1.20 * route_match(c, B)
+ 0.90 * package_proximity(c, B)
+ 0.70 * role_match(c, B)
+ 0.40 * tag_match(c, B)
+ 0.30 * momentum_match(c, M)
+ 0.40 * affinity(c)
- 0.80 * repetition_penalty(c)
```

解释：

- 路线延续最重要。
- 英雄投入次之。
- 近期动量有影响，但不压过长期路线。

### 8.2 协同槽

目的：鼓励三英雄配合、双人接力、三人轮转。

```text
W_link(c) =
  base(c)
+ 1.20 * Synergy(c, B)
+ 0.80 * edge_match(c, B)
+ 0.60 * package_proximity(c, B)
+ 0.60 * pair_balance_bonus(c, B)
+ 0.40 * triad_progress_bonus(c, B)
+ 0.30 * affinity(c)
- 0.50 * repetition_penalty(c)
```

解释：

- 协同槽优先找“当前 Build 已经能接上”的卡。
- 若当前只有单英雄过强，则增加第二/第三英雄接入卡权重。

### 8.3 转向 / 补缺槽

目的：保留中期摇摆空间，不使用心愿。

```text
W_pivot(c) =
  base(c)
+ 0.90 * momentum_match(c, M)
+ 0.80 * underused_role_bonus(c, B)
+ 0.70 * openness(stage)
+ 0.60 * bridge_match(c, B)
+ 0.45 * package_proximity(c, B)
+ 0.40 * alternative_route_bonus(c, B)
+ 0.25 * affinity(c)
- 0.60 * hard_conflict_penalty(c, B)
```

解释：

- 玩家最近连续选某英雄，该英雄会在转向槽中快速升权。
- 投入较低的英雄会得到低门槛接入机会。
- 但严重冲突的卡降低权重，例如当前完全没有领域/状态基础时，不频繁给高阶领域终式。

---

## 9. 阶段开放度

用于控制前期开放、中期可摇摆、后期适度收束。

建议初始曲线：

```text
Level 1-3:   openness = 1.00
Level 4-8:   openness = 0.85
Level 9-14:  openness = 0.65
Level 15+:   openness = 0.35
Boss reward: openness = 0.50
```

注意：中期开放度不能下降太快，否则玩家无法从剑士转到枪手或术师。

---

## 10. 摇摆状态判断

当两个英雄接近，或者第二英雄近期动量明显升高时，系统进入摇摆状态。

### 10.1 英雄重心分

```text
Focus(r) = role_points[r] + 1.5 * recent_momentum[r] + breakthrough_bonus[r]
```

### 10.2 摇摆判定

设最高分英雄为 `r1`，第二名为 `r2`。

```text
swing(r1, r2) = Focus(r2) / max(Focus(r1), 0.01)
```

若：

```text
swing >= 0.72
```

则视为双英雄摇摆。

### 10.3 摇摆状态下的发牌变化

- 延续槽：仍给 `r1` 或其路线。
- 协同槽：优先给 `r1 <-> r2` 的共鸣或接力。
- 转向槽：提高 `r2` 的主战/入场/终式路线卡权重。

这允许：

```text
前期剑士较强 -> 中期连续选枪手 -> 剑枪摇摆 -> 枪手上位或形成双输出
```

---

## 11. 三英雄配合指标

为了避免系统暗中鼓励固定一主两辅，使用指标监控。

### 11.1 集中度

```text
Concentration = max(role_points) / sum(role_points)
```

解释：

- 接近 1：极端单核。
- 接近 0.33：三英雄均衡。

不强制玩家均衡，但若集中度过高，协同槽应增加接入卡权重。

### 11.2 参与度

```text
Participation = count(role_points[r] >= 1.0) / 3
```

用于判断是否已有多个英雄参与构筑。

### 11.3 共鸣密度

```text
ResonanceDensity = resonance_card_count / total_card_count
```

过低说明玩家几乎没有形成配合。协同槽可轻微升权。

### 11.4 三人闭环分

三个英雄之间存在有向接力：

```text
CycleScore = min(
  edge_points[swordsman->gunner] + edge_points[gunner->swordsman],
  edge_points[gunner->mage] + edge_points[mage->gunner],
  edge_points[mage->swordsman] + edge_points[swordsman->mage]
)
```

当 `CycleScore` 达到阈值时，可以出现三人轮转共鸣。

---

## 12. 不固定职责的构筑识别

系统不显示“主 C / 辅助”作为硬分类。更推荐显示构筑解析：

```text
当前构筑倾向：
- 剑士：破阵 / 入场 / 爆发
- 枪手：过载 / 弹幕 / 持续
- 术师：星灾 / 领域 / 爆发
- 队伍关系：剑士 -> 枪手，术师 -> 全队
```

可识别的构筑形态包括：

```text
三输出轮转
双核心接力
领域接力
标记消耗
入场爆发链
离场传承链
大招循环
控制压制
续航反击
```

这些是描述，不是锁定职业。

---

## 13. Boss 奖励模型

Boss 奖励不从普通池随机抽，而是根据当前状态生成 3 类奖励。

```text
Boss Slot 1: 当前最高路线突破
Boss Slot 2: 追赶路线突破
Boss Slot 3: 双人/三人共鸣突破
```

示例：

```text
[剑士突破] 破阵无双
[枪手突破] 过载弹幕
[剑枪共鸣突破] 火线开路
```

选择剑士突破后，剑士获得高阶强化，但不永久锁死。若后续枪手动量和投入追上，枪手仍可成为后期重心。

---

## 14. 卡牌数据结构建议

后续新卡推荐使用如下字段。

```gdscript
{
  "id": "swordsman_break_step",
  "title": "破阵步",
  "owner_role": "swordsman",
  "route_id": "swordsman_break",
  "tier": 1,
  "max_level": 3,
  "base_weight": 1.0,
  "stage_min": 1,
  "stage_max": 99,

  "package_id": "swordsman_entry_burst_break",
  "affinity_score": 0.92,
  "novelty_score": 0.2,
  "role_weights": {"swordsman": 1.0},
  "route_weights": {"swordsman_break": 1.0},
  "timing_weights": {"entry": 1.0},
  "function_weights": {"burst": 0.8, "mobility": 0.5},
  "mechanic_weights": {"direct_hit": 0.8},
  "archetype_weights": {"entry_burst": 0.9},
  "produce_weights": {"armor_break": 0.8},
  "consume_weights": {},
  "amplify_weights": {},
  "edge_weights": {"swordsman->gunner": 0.2, "swordsman->mage": 0.2},
  "bridge_weights": {"entry_burst->projectile_storm": 0.3},
  "package_edges": [
    {"to": "gunner_projectile_followup", "type": "relay_edge", "cost": 1.0},
    {"to": "swordsman_healing_push_tide", "type": "bridge_edge", "cost": 2.0}
  ],

  "slot_affinity": {
    "continue": 1.0,
    "link": 0.3,
    "pivot": 0.4
  },

  "unlock_requirements": {
    "route_points": {},
    "role_points": {},
    "archetype_points": {},
    "edge_points": {},
    "bridge_points": {}
  },

  "preview": "剑士入场突进更远，并在命中后制造破甲。",
  "detail_lines": [
    "剑士入场突进距离提高。",
    "入场斩击命中的敌人短暂破甲。",
    "后续枪手或术师攻击破甲敌人时更容易触发接力收益。"
  ]
}
```

---

## 15. 首批内容建议

第一版不要一次铺满所有路线。建议先做最小闭环：

### 15.1 三条输出路线

```text
剑士：破阵线  入场爆发 / 破甲 / 近身斩击
枪手：过载线  弹幕持续 / 穿透 / 火力窗口
术师：星灾线  领域爆发 / 轰炸 / 范围清场
```

这三条都可以是输出，因此不会强迫“一输出两辅助”。

### 15.2 三条双人共鸣

```text
剑士 + 枪手：破甲 -> 穿透 / 火线接力
枪手 + 术师：弹幕 -> 雷火爆链 / 领域弹幕
术师 + 剑士：领域 -> 入场增伤 / 星灾破阵
```

### 15.3 一条三人轮转

```text
三段爆发：三名英雄在短时间内依次入场或造成核心伤害后，触发一次队伍终结打击。
```

### 15.4 少量通用卡

```text
生命 / 拾取 / 移速 / 切换冷却 / 经验效率
```

通用卡只补体验，不成为主构筑。

---

## 16. 生成流程伪代码

```text
function build_upgrade_options(state):
  candidates = get_eligible_cards(state)

  continue_card = weighted_pick(candidates, W_continue)
  remove_conflicts(candidates, continue_card)

  link_card = weighted_pick(candidates, W_link)
  remove_conflicts(candidates, link_card)

  pivot_card = weighted_pick(candidates, W_pivot)

  options = dedupe([continue_card, link_card, pivot_card])
  options = repair_if_needed(options, state)
  return shuffle_for_display(options)
```

### 16.1 去重规则

- 同一次升级不出现 2 张完全同路线同功能卡。
- 除非当前是明确三输出轮转，否则不出现 3 张同一英雄卡。
- 已满级卡不出现。
- 高阶卡要求对应路线/关系分达标。

### 16.2 断供保护

不使用心愿，但需要基础质量保护：

```text
若某路线 route_points >= 2，且最近 2 次升级完全没有出现该路线延续卡，
则下一次延续槽显著提高该路线候选权重。
```

这是系统稳定性保护，不是玩家手动指定心愿。

### 16.3 拒绝降权

如果某张卡连续出现但玩家不选，可以短期降权：

```text
rejection_penalty(card) += 1
每次升级后衰减
```

这让系统隐式理解“玩家不想走这张卡”，但不需要心愿按钮。

### 16.4 单次刷新机制

每次普通升级给玩家 **1 次免费刷新**。刷新不是心愿，也不是全随机重抽，而是在同一 `state`、同一队伍等级、同一可选卡池下重新生成三槽位候选。

目标：

```text
1. 降低“三张都不想选”的挫败。
2. 不让玩家用刷新稳定追某个固定最优解。
3. 保留中期转向机会，但不破坏三槽位职责。
```

刷新规则：

```text
每次升级：refresh_remaining = 1
点击刷新：
  - 消耗 refresh_remaining。
  - 当前三张 offer 进入本次升级的 rejected_offer_ids。
  - 按 Continue / Link / Pivot 三槽重新生成。
  - 已拒绝卡在本次刷新内强降权，除非候选不足以修复三槽。
选择任意卡后：
  - 本次升级结束，refresh_remaining 清零。
  - 被展示但未选的卡可进入轻度 rejection_penalty，后续逐渐衰减。
```

刷新不改变：

```text
role_investment / package_depth / edge_level / tag_points / position_points
```

刷新只改变：

```text
offer_context.refresh_index
offer_context.rejected_offer_ids
offer_context.refresh_remaining
```

### 16.5 刷新质量约束

刷新后的三张卡仍必须满足：

```text
- 仍然最多 3 张。
- 仍然保留 continue / link / pivot 槽位标签。
- 不出现已满级卡。
- 不故意突破等级门槛和投入门槛。
- 尽量不重复刷新前的 3 张卡。
```

如果可选池太小，允许少量重复，但要在 `offer_context` 里标记：

```text
refresh_repair_used = true
```

### 16.6 刷新的平衡边界

刷新会提高玩家拿到“想要路线”的概率，所以需要约束：

```text
- 每次升级最多刷新 1 次。
- 刷新不能锁定英雄、门派或卡牌。
- 刷新不增加额外候选数量，仍然是三选一。
- 刷新不提高高阶卡权重，只降低本次被拒绝卡的权重。
```

因此，刷新提供的是“拒绝这组牌”的权利，而不是“指定我想要什么”的权利。

---

## 17. 英雄不是全能：亲和矩阵约束

该模型允许同一英雄承担不同定位，但不允许所有英雄对所有定位同样擅长。

### 17.1 设计表述

每个英雄应定义：

```text
高亲和能力包：这个英雄可以作为完整构筑核心。
中亲和能力包：这个英雄可以作为桥接、变体或副构筑。
低亲和能力包：只用于稀有卡、Boss 卡或特殊事件。
禁忌能力包：默认不做，避免破坏角色辨识度。
```

示例：

```text
剑士：高亲和 entry_burst / lifesteal_grind / guard_counter；中亲和 healing_push / summon_swarm；低亲和 projectile_storm。
枪手：高亲和 projectile_storm / mark_execute；中亲和 summon_swarm / ultimate_cycle / control_lock；低亲和 healing_push。
术师：高亲和 domain_blast / control_lock / summon_swarm / ultimate_cycle；中亲和 healing_push / guard_counter；低亲和 direct melee。
```

### 17.2 机制载体与功能结果解耦

机制不是功能。发牌和设计时必须同时写：

```text
mechanic = 用什么实现
function = 解决什么问题
```

例如召唤机制：

```text
summon_unit + burst     = 爆炸傀儡 / 剑影齐斩
summon_unit + taunt     = 守护傀儡 / 嘲讽幻影
summon_unit + heal      = 医疗无人机 / 治疗图腾
summon_unit + mark      = 侦察无人机 / 标记妖精
summon_unit + control   = 冰傀儡 / 牵引炮台
```

治疗机制：

```text
heal + survival   = 回复生命
heal + shield     = 过量治疗转护盾
overheal + push   = 治疗溢出形成冲击波
overheal + burst  = 护盾爆裂造成伤害
overheal + energy = 过量治疗转大招能量
```

这种解耦能让未来门派扩展时不把所有新机制都做成输出。

### 17.3 能力包覆盖不等于英雄全覆盖

一个门派进入系统时，不要求三个英雄都能完整走这门派。只要求：

```text
至少 1 个英雄有高亲和完整能力包。
至少 1 个英雄有中亲和桥接能力包。
至少存在 2 条与其他门派的桥接边。
```

例如召唤流可以是：

```text
术师高亲和：元素傀儡完整召唤核心。
枪手中亲和：无人机 / 炮台作为桥接。
剑士低-中亲和：剑影只作为入场或 Boss 稀有变体。
```

这样既支持召唤流，又不会让每个英雄都变成召唤师。

### 17.4 普通池准入规则

```text
if affinity >= core_affinity and package_coverage_ready:
  可进入延续槽 / 协同槽 / 转向槽
elif affinity >= bridge_affinity:
  只进入协同槽 / 转向槽
elif affinity >= rare_affinity:
  只进入 Boss / 稀有奖励 / 特殊事件
else:
  不进入卡池
```

---

## 18. 多样化保障模型

该模型不能保证每一种构筑最终强度完全相等；这仍然需要战斗数值、怪物压力和演出反馈共同调平。但它可以在结构上保证：玩家不会被巨大卡池淹没，已有路线不会断供，中期转向有入口，不同门派不会互相隔离。

### 18.1 三层保障

```text
供给保障：玩家已投入的路线、门派、英雄会持续获得可选延续。
桥接保障：当某门派或英雄过度集中时，系统会提供兼容的第二门派或第二英雄接入卡。
结构保障：每次三选一由不同槽位生成，避免三张卡都在重复同一件事。
```

这三层保障的是“选择空间质量”，不是强迫玩家平均发展。

### 18.2 Offer 级多样化

单次三选一需要满足最低结构约束：

```text
1. 至少 1 张延续当前投入的卡。
2. 至少 1 张能产生英雄关系、状态闭环或门派桥接的卡。
3. 至少 1 张允许补缺、摇摆或转向的卡。
4. 默认不出现 3 张同英雄同路线卡。
5. 默认不出现 3 张纯数值卡。
```

如果玩家已经明确选择三输出轮转，允许同为输出，但三张卡仍应在英雄、时机或状态关系上有差异。

### 18.3 局内路径多样化

模型用有效门派数量衡量一局是否过窄：

```text
H_A = -Σ p(a) * log(p(a))
N_eff_archetype = exp(H_A)
```

其中：

```text
p(a) = archetype_points[a] / sum(archetype_points)
```

解释：

```text
N_eff_archetype ≈ 1：单一门派。
N_eff_archetype ≈ 2：双门派混合。
N_eff_archetype >= 2.5：多门派轮转。
```

系统不强制 `N_eff_archetype` 变高；但如果它长期接近 1，协同槽和转向槽会提高桥接卡权重。

### 18.4 英雄配比多样化

英雄配比也用熵描述：

```text
H_R = -Σ p(r) * log(p(r))
N_eff_role = exp(H_R)
```

解释：

```text
N_eff_role ≈ 1：单英雄核心。
N_eff_role ≈ 2：双核心 / 单核带副轴。
N_eff_role ≈ 3：三英雄均衡或三输出轮转。
```

注意：低 `N_eff_role` 不一定是坏事。如果其他英雄通过 `edge_points`、`pass_next`、`inherit_prev` 参与，单核带队仍然是合法构筑。系统只在“单核且无关系边”时提高接入卡权重。

### 18.5 门派可用性矩阵

每个门派要进入正式卡池，必须满足内容覆盖要求。

```text
Coverage[a] = {
  seed:       入口卡数量,
  engine:     运转卡数量,
  payoff:     收益卡数量,
  bridge:     桥接卡数量,
  stabilizer: 容错卡数量,
  capstone:   终式 / 突破数量
}
```

首版最低要求：

```text
seed >= 2
engine >= 2
payoff >= 2
bridge >= 2
stabilizer >= 1
capstone >= 1
```

如果某门派没有达到最低要求，只能作为其他门派的附属标签，不能作为完整构筑方向主动推给玩家。

### 18.6 门派转移图

不同门派之间需要有桥接边：

```text
entry_burst -> projectile_storm     破甲后弹幕穿透
projectile_storm -> mark_execute    弹幕快速叠标记
mark_execute -> ultimate_cycle       斩杀返还大招能量
domain_blast -> summon_swarm         领域强化召唤物
summon_swarm -> healing_push         治疗召唤物产生推进收益
healing_push -> guard_counter        过量治疗形成护盾反击
control_lock -> domain_blast         控制敌人后领域命中更稳定
```

设计目标不是让所有门派两两相连，而是让每个门派至少有 2 条合理转移边。这样玩家中期不会因为前期选错而只能重开。

### 18.7 保证边界

模型可以较稳定地保证：

```text
- 已投入路线不会长期断供。
- 三选一不会完全随机污染。
- 中期连续选择某新方向后，发牌会跟随动量转移。
- 三输出、双核心、单核接力、召唤、奶推等结构都能被识别。
- 新门派只要补齐 coverage，就能并入系统。
```

模型不能单独保证：

```text
- 每个门派最终强度完全相等。
- 玩家一定会喜欢所有构筑。
- 所有混合构筑都可赢。
- 召唤物 AI、治疗反馈、推进碰撞等战斗实现一定好玩。
```

这些需要战斗实现、数值曲线和关卡压力继续验证。

---

## 19. 扩展流派支持：召唤流与奶推流

### 19.1 召唤流如何进入模型

召唤流不是第四套特殊系统，而是普通门派原型：

```text
archetype: summon_swarm
mechanic: summon_unit / command_summon / resource_loop
function: sustain / control / survival / burst
state: command_mark / field / guard / charge
```

召唤流可以有多种配比：

```text
剑士召唤：入场号令，召唤物跟随突进或继承破甲。
枪手召唤：炮台 / 无人机，消耗标记或跟随弹幕集火。
术师召唤：元素傀儡，在领域内攻击或死亡爆炸。
三英雄召唤：切换英雄时重新指挥召唤物，形成轮转战术。
```

召唤流需要的 coverage：

```text
seed: 召唤第一个单位 / 炮台 / 傀儡。
engine: 召唤物继承英雄属性、自动攻击、跟随标记。
payoff: 召唤物数量、死亡爆炸、集火增伤。
bridge: 领域强化召唤物、治疗召唤物、标记指挥召唤物。
stabilizer: 召唤物吸引火力、替玩家挡伤、短暂复活。
capstone: 三英雄轮转时召唤物合体 / 全体号令。
```

### 19.2 奶推流如何进入模型

奶推流不是单纯治疗，而是“治疗 -> 过量治疗 -> 护盾 / 推进 / 撞击 / 反击”的收益链。

```text
archetype: healing_push
mechanic: heal / overheal / push / collision / shield
function: survival / control / burst / sustain
state: guard / vulnerable / slowed / field
```

奶推流可以不是辅助流，也可以是输出流：

```text
治疗自己产生过量护盾。
护盾满时释放冲击波推开敌人。
敌人被推到墙或其他敌人身上造成撞击伤害。
被推敌人进入易伤，下一名英雄接力输出。
```

三英雄表达：

```text
剑士：近身吸血 / 护盾冲撞 / 入场推线。
枪手：治疗转弹药 / 过量治疗提高弹幕速度 / 推开敌人后穿透。
术师：治疗领域 / 过量治疗爆波 / 减速场内推进撞击。
```

奶推流 coverage：

```text
seed: 治疗或护盾入口。
engine: 过量治疗转护盾 / 推力 / 冷却返还。
payoff: 撞击伤害、冲击波、护盾爆裂。
bridge: 与控制、领域、召唤、守护反击相连。
stabilizer: 濒死治疗、护盾保底、推开近身敌人。
capstone: 全队过量治疗转大型推进浪潮。
```

### 19.3 新门派接入流程

新增任何门派时，先不要写大量卡。先补一张门派定义表：

```text
archetype_id
核心机制 mechanic
主要功能 function
核心状态 state
可连接门派 bridge_to / bridge_from
三英雄表达方式
coverage 当前数量
```

只有当 `coverage` 达到最低要求，才进入普通升级池；否则只作为桥接或 Boss 特殊奖励测试。

---


## 19.5 敌人压力模型

Build 平衡不能只看玩家卡牌，还要纳入敌人生态。首批纯模型增加敌人压力层：

```text
EnemyPressure(level/time) = f(敌人血量, 伤害, 攻击方式, 类型权重, 刷怪密度, 精英/Boss事件)
```

实现入口：

```text
scripts/build/build_enemy_pressure_model.gd
scripts/tests/build_enemy_pressure_model_smoke.gd
```

### 19.5.1 压力维度

敌人不直接折算成一个“难度数字”，而是先拆为 8 个压力维度：

| 维度 | 含义 | 主要来源 |
| --- | --- | --- |
| density | 敌人数量和包密度 | spawn_interval、swarm_min/max、pack_chance |
| durability | 血量/硬度 | max_health、精英/Boss |
| contact | 贴身碰撞压力 | touch_damage、追踪怪、群怪 |
| ranged | 远程弹幕压力 | shooter、shotgunner、turret、Boss弹幕 |
| burst | 瞬时爆发/冲刺风险 | dasher、splitshot、Boss爆发 |
| mobility | 追击速度和机动 | speed、dash_speed_multiplier |
| control | 区域限制/特殊机制 | turret bombard、rebirth slow、Boss控制 |
| boss | Boss/小Boss持续压力 | small_boss、boss_spellcore |

### 19.5.2 敌人资料如何进入模型

基础敌人资料来自当前实装：

```text
scripts/enemy/enemy_archetype_database.gd
```

波次密度和类型权重来自：

```text
scripts/enemy/enemy_director.gd
```

模型读取：

```text
max_health
speed
touch_damage
behavior
shot_interval
projectile_damage
projectile_count
dash_interval / dash_speed_multiplier
turret_bombard_*
boss_*
```

并结合：

```text
spawn_interval
weights
swarm_min / swarm_max
pack_chance
pack_bonus_max
elite_spawn_times
small_boss_spawn_times
boss_spawn_time
```

### 19.5.3 Build 对压力的覆盖

玩家 Build 也被映射到压力覆盖：

```text
position_points -> pressure_coverage
tag_points      -> pressure_coverage
edge_level      -> 少量 boss / burst 覆盖
```

示例：

```text
damage    覆盖 durability / boss / density
control   覆盖 density / mobility / burst
survival  覆盖 contact / burst
summon    覆盖 density / contact / ranged
resource  覆盖 boss / durability
```

机制标签也参与覆盖：

```text
projectile_storm -> density / ranged
domain_blast     -> density / control
mark_execute     -> durability / boss
ultimate_cycle   -> boss / durability
control_lock     -> mobility / density
healing_push     -> contact / burst
```

### 19.5.4 风险指标

给定某阶段敌人压力 `P` 和某 Build 覆盖 `C`：

```text
resisted_pressure = Σ min(P_i, C_i)
uncovered_pressure = Σ max(0, P_i - C_i)
coverage_ratio = resisted_pressure / total_pressure
danger_ratio   = uncovered_pressure / total_pressure
```

这不是最终死亡率，而是“这个构筑面对当前敌人生态是否缺答案”的信号。

### 19.5.5 平衡解释

允许不同路线有不同风险曲线：

```text
剑士主轴：可以前期强，但面对 ranged / boss 可能更依赖联动补足。
枪手主轴：清密度和远程对抗较好，但接触/爆发需要保护。
术师主轴：前期慢，但领域/控制对中后期密度和机动压力更有效。
召唤支援：后期风险低可以接受，但不能同时最高输出、最低风险、最易成型。
低协同散选：可以弱，且应在高压阶段暴露明显风险。
```

因此，后续判断“是否过强”不只看强度分，还看：

```text
aggregate_score 高 + risk_score 低 + 成型稳定
```

三者同时成立时，才是真正危险的唯一最优解候选。

### 19.6 完整场景时间线评估器（升级方向）

当前纯模型已经能在 `6 / 12 / 18 / 25` 四个里程碑估计路线强度与敌人压力风险。下一步要补的是“完整场景时间线评估器”，用于把难度、升级节奏和敌人时间轴放到同一个模拟里判断。

核心形式：

```text
TimelineEval(route_policy, difficulty_profile)
  for t in 0..stage_end step 15s/30s:
    expected_team_level = LevelCurve(t, difficulty_profile, route_policy)
    build_state         = UpgradePolicy(route_policy, expected_team_level)
    enemy_pressure      = EnemyPressure(t, difficulty_profile)
    build_coverage      = BuildCoverage(build_state)
    risk[t]             = UncoveredPressure(enemy_pressure, build_coverage)
    clear_margin[t]     = PlayerOutput(build_state) - EnemyEHPFlow(t)
    survival_margin[t]  = PlayerDefense(build_state) - EnemyDamageFlow(t)
```

它和当前阶段快照的区别：

| 当前快照模型 | 完整时间线模型 |
| --- | --- |
| 只看 6/12/18/25 级 | 按 15s 或 30s 连续采样 |
| 只知道某阶段强弱 | 能看到哪一分钟突然断档 |
| 适合比较 Build 路线 | 适合设置难度和波次 |
| 不累计场上存量 | 可以估计清怪不足造成的敌人堆积 |
| Boss 只是一个压力维度 | Boss 可作为 480s/720s 的独立窗口评估 |

需要输入：

```text
1. 难度档 difficulty_profile：密度、血量、伤害、速度、特殊怪、Boss 压力倍率。
2. 经验曲线 LevelCurve：不同时间点预期队伍等级。
3. 发牌/选择策略 route_policy：主轴、副轴、转向和散选策略。
4. 敌人时间线 EnemyPressure(t)：波次、精英、小 Boss、Boss。
5. Build 覆盖 BuildCoverage(state)：输出、控制、生存、召唤、治疗、资源等。
```

需要输出：

```text
risk_curve            每个时间点的未覆盖压力
difficulty_curve      敌人有效压力随时间变化
clear_margin_curve     清怪余量，负值代表可能堆怪
survival_margin_curve  生存余量，负值代表可能被秒杀或被压死
spike_windows          突然变难的窗口
overkill_windows       玩家明显碾压的窗口
route_fail_windows     某路线必然断档的窗口
```

这能回答四档难度最关键的问题：

```text
简单：弱构筑是否也能在 0-6 级安全学习。
普通：合理构筑是否在大多数时间处于可控风险。
困难：不成体系的路线是否会在 12/18 级后明显吃力。
地狱：强构筑是否仍然需要补足敌人压力答案，而不是只堆最高输出。
```

验收线：

```text
- 90s 前不能因密度或速度突然压死新手。
- 180s/240s 的第一次精英或小 Boss 压力要能暴露构筑短板，但不应强迫唯一路线。
- 420s 左右应检查中期转向路线是否还有追赶空间。
- Boss 前 60s 应形成备战窗口，而不是纯随机秒杀。
- 地狱难度可以高压，但不能让某一个强路线同时拥有最高输出、最低风险、最稳定成型。
```


## 20. 调参和验证指标

建议写一个纯逻辑模拟器，不进 Godot 战斗，只模拟 10-20 次升级选择。

### 20.1 关键指标

```text
OfferQuality:
- 每次三选一是否至少包含 1 张延续卡。
- 是否至少包含 1 张协同/转向机会。
- 死卡率是否低于 5%。

PivotElasticity:
- 中期连续选择某新英雄 2-3 次后，该英雄路线卡是否明显增多。

BuildDiversity:
- 模拟多种选择策略后，能否形成三输出、双核心、领域、控制、大招循环等多种形态。

ResonanceAccess:
- 玩家投入两个英雄后，合理时间内是否能看到相关共鸣。

NoForcedTemplate:
- 三输出策略不能被系统强行改造成一输出两辅助。

ArchetypeCoverage:
- 每个正式门派是否满足 seed / engine / payoff / bridge / stabilizer / capstone 最低数量。

TransitionReachability:
- 每个正式门派是否至少有 2 条合理转移边。

OfferEntropy:
- 单次三选一的英雄、功能、门派标签是否避免完全同质。
```

### 20.2 初始验收线

```text
普通 12 次升级内：
- 至少 90% 模拟局能形成 2 名以上英雄参与。
- 玩家连续 3 次选择追赶英雄后，接下来 2 次升级至少 1 次出现追赶英雄延续卡。
- 已投入路线在未满级情况下，不应连续 3 次升级完全没有延续机会。
- 三输出策略、双核心策略、单核心接力策略都能完成基本闭环。
- 召唤策略和奶推策略在模拟中能稳定拿到 seed -> engine -> payoff 至少 3 段结构。
- 中期从任意正式门派连续选择桥接卡 2 次后，接下来 3 次升级内至少 1 次出现目标门派候选。
```

---

## 21. 实施阶段

### 阶段 1：纯模型落地

新增纯逻辑脚本：

```text
scripts/build/build_vector_model.gd
scripts/build/build_offer_generator.gd
scripts/tests/build_offer_model_smoke.gd
```

目标：

- 定义卡牌标签字段，包括英雄、时机、功能、机制、门派、状态和关系边。
- 定义英雄亲和张量与能力包图，包括 `Affinity[r,a,m,f]`、`package_edges`、`package_distance`。
- 实现 Build 状态累计，包括 `mechanic_points`、`archetype_points`、`bridge_points`、`package_points`。
- 实现动量更新。
- 实现三槽位发牌。
- 实现 coverage 检查、饱和惩罚、拒绝降权和断供保护。
- 测试不接入实际战斗。

### 阶段 2：首批新卡数据

先录入最小闭环：

```text
剑士破阵 3-4 张
枪手过载 3-4 张
术师星灾 3-4 张
双人共鸣 3 张
三人轮转 1-2 张
通用 3 张
召唤测试包 6-8 张，仅在 coverage 达标后进入普通池
奶推测试包 6-8 张，仅在 coverage 达标后进入普通池
```

目标：验证卡池结构，不追求一次性内容完备。召唤和奶推可以先作为模型测试包，不立刻接入完整战斗实现。

### 阶段 3：UI 解释

升级界面增加轻量解释：

```text
[剑士 · 入场 · 爆发]
出现原因：延续剑士破阵路线

[剑士 + 枪手 · 接力]
出现原因：剑士破甲可被枪手消耗

[术师 · 领域]
出现原因：补充第三英雄参与 / 可转向星灾
```

不要显示复杂公式，只显示玩家能理解的原因。

### 阶段 4：Boss 突破接入

Boss 奖励改为：

```text
当前路线突破
追赶路线突破
共鸣突破
```

并保证突破不是永久锁定。

### 阶段 5：替换旧主题树

当新模型稳定后，再移除旧的主题排列组合逻辑。不要一边改模型一边大规模改战斗效果，避免难以定位问题。

---

## 22. 推荐默认参数

```text
momentum_decay λ = 0.65
swing_threshold = 0.72
core_affinity = 0.70
bridge_affinity = 0.40
rare_affinity = 0.20
route_drought_limit = 2 upgrades
archetype_drought_limit = 3 upgrades
min_bridge_count_per_archetype = 2
min_archetype_coverage = {seed: 2, engine: 2, payoff: 2, bridge: 2, stabilizer: 1, capstone: 1}
saturation_k = 4.0
saturation_threshold = 0.62
package_edge_costs = {continue: 1.0, relay: 1.0, mirror: 1.5, bridge: 2.0, capstone: 2.5}
max_same_role_cards_per_offer = 2
max_same_route_cards_per_offer = 1, unless route is currently the only active route
max_pure_numeric_cards_per_offer = 1
openness:
  early = 1.00
  mid = 0.85
  late = 0.65
  end = 0.35
```

这些参数不是最终平衡，只是第一版实现可用值。

---

## 23. 总结

下一代 Build 系统可以抽象为：

```text
卡牌 = 英雄 / 时机 / 功能 / 机制 / 门派 / 状态传递的向量
能力包 = 英雄语法 + 机制载体 + 功能结果 + 状态传递 + 桥接边
构筑 = 已选卡向量之和 + 能力包图上的当前位置
配合 = 英雄关系图、门派转移图、能力包图和状态制造-消耗闭环
发牌 = 延续槽 + 协同槽 + 转向槽
转向 = 近期动量 + 桥接卡 + 能力包图距离自动驱动，不需要心愿
多样化 = 亲和门槛 + coverage 门槛 + 熵指标 + 饱和惩罚 + 转移图
突破 = Boss 阶段奖励，不永久锁死
```

这样可以同时满足：

```text
鼓励三英雄配合
允许三输出
允许中期转向
支持未来召唤流、奶推流等新门派
避免巨大卡池随机污染
让每次三选一都可解释
```
