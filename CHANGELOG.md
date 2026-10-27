# Changelog

本文件按发生时点记录变更；下方历史玩法条目不作为当前目标。新设计见[当前设计共识](docs/00_当前设计共识.md)，实现范围见[当前状态](docs/08_当前实现状态与后续重点.md)。

## Unreleased

- 2026-10-27公开源码同步准备：整理可复用战斗美术流程和素材来源，排除本地参考图片、缓存及已弃用旧音频；旧音频仍存在于此前公开Git历史。项目入口及smoke日志检查对齐当前实现，净目录183项smoke与Python／合同、Godot导入启动检查通过；独立高密度性能基准按原流程跳过。范围与证据见[源码同步记录](docs/implementation/2026-10-27_公开仓库同步.md)。

- 2026-10-27战斗美术流程：整理人物母版、透明素材生成、Aseprite动作与头像导出、Godot接入及验收留档，形成可复用的[角色战斗美术制作流程](docs/art/角色战斗美术制作流程.md)；同步资源规范、索引和公开源码与成品发行边界。

- 2026-10-27贾苇索战斗美术：以已确认起家立绘为母版生成独立刀／枪待机、奔跑和攻击帧，Aseprite整理为共享调色板、透明帧及可编辑源，并接入三类攻击特效与单独生成的HUD头像；其他角色不变。成功施放才触发攻击表现，保留移动和既有战斗数值。美术26项、尺度62项、战斗规则66项、流程UI和headless启动通过，动作与实战观感待用户审看。见[本轮记录](docs/implementation/2026-10-27_贾苇索战斗美术接入.md)。

- 2026-10-27人物稀有度与编队加成：设置普通蓝、稀有紫、传说金橙及主角专属朱红，透明人物图与卡底分层，主角起家立绘用于卡片及人物详情；编队调整为左队伍、右实际加成与支援／装备汇总。稀有度独立于人物分类、抽卡规则和存档；155项编队汇总、66项战斗规则、三尺寸界面回归与headless启动通过。见[本轮记录](docs/implementation/2026-10-27_人物稀有度与编队加成.md)。

- 2026-10-27夺寨聚众四关：接入运粮道／冥市暗巷二选一、匪寨夺旗及可选荒祠兵冢，串接鬼市、追随者、寨后古井与寨中一夜；B07及后续战斗仍未制作。现有六个可玩战斗节点，单次路线四场或含可选精英五场；12人实装，女医者、军需小吏、女匪首和荒祠咒师按剧情或战果解锁入池，不直接赠送。新增关卡配置、突进及高生命低移速的重装近战和Boss范围重击；复用旧地图与素材。旧正式档按已完成节点补卡池资格，保留待选候选与选择。新流程180项、既有规则与界面回归及headless启动通过，实战平衡仍需审看。见[本轮记录](docs/implementation/2026-10-27_夺寨聚众四关接入.md)。

- 2026-10-27战场比例与三角头像HUD：按用户反馈将战场从1120×630扩大至3200×1800，采用1280×720基准视野的跟随镜头，并以素材可见身体与脚底对齐角色和怪物；边界、场域与小地图共用几何，刷怪围绕当前交战区。恢复当前头像居中抬高、切换目标左右下方的三角HUD，覆盖全幅战场；单人／两人不补假头像，阵亡头像保留但切人时跳过，三行版继续可选。此前简单底栏实际为横排。尺度58项、战斗66项、真实两关UI和headless启动通过；扩大世界及近场刷怪的遭遇节奏仍需实玩。见[实施记录](docs/implementation/2026-10-27_战场比例与三角头像HUD.md)。

- 2026-10-27人物卡与主线界面重排：新增肖像、卡片、编队与奖励组件，调整行装、地图和独立菜单。路线默认突出当前与前路，六段总览按需展开，隐藏25条重复的地图摘要而保留事件正文。三张生成图集共26个肖像单元，通过角色映射和兵种复用覆盖38条目录，艾玛沿用原图；八张具名三国人物卡参考《火凤燎原》造型，均为临时设计。框和按钮采用墨绿底、旧金细边、局部角饰及酒红主按钮，地图保持苍凉三国。headless 启动、原界面冒烟、真实两关流程和三尺寸布局夹具通过；画面尚待用户验收。见[实施记录](docs/implementation/2026-10-27_人物卡与主线界面重排.md)。

- 2026-10-27界面研究与HUD取舍：收集兰斯10官方及发售后29张截图，按18个页面整理组成、信息时机和本作对照；当时主线页面重排尚待实施。新战斗接回默认简单底栏，保留三行版；设定及暂停复用原HUD选项，移除常驻规则解释、重复经验数字和空辅助占位。切换布局不改血魔、冷却、成长和主线档。详见[研究](docs/design-reviews/2026-10-27_兰斯10界面结构与信息减法研究.md)与[实施验证](docs/implementation/2026-10-27_简洁HUD与双布局.md)。

- 2026-10-27战斗表现复用：前两关接回已有地图、剑士／法师／枪手动画、史莱姆／骷髅敌人、头像和特效；用原HUD小组件呈现新三人队伍、血魔、技能冷却与经验。删除程序占位人形，增加跟随视野与位置缩略图。保留新战斗／成长／存档规则及已批准的主线界面，复用映射独立于战斗内核。[实施与验证](docs/implementation/2026-10-27_战斗表现与HUD复用.md)。

- 2026-10-27前两关真实战斗：默认界面接入独立战斗内核与正式主线服务，八人物、自动攻击／技能、独立血魔和冷却、辅助支援与阵亡、四角精英、Boss、经验升级、装备、五选二／三、失败回退及保存已连通。正式档位于 `chronicle_campaign_v1`，不覆盖旧档或演练档；后续战斗明确锁定。66项规则及保存检查、实战UI和三尺寸真实渲染通过，细节见[实施记录](docs/implementation/2026-10-27_前两关真实战斗接入.md)。

- 2026-10-27真实战斗架构调研：核对当前源码与 GDQuest、OctoD、Godot State Charts、Godot／Epic 官方资料，记录独立人物状态、能力与伤害流程、纯键盘操作、关卡时序及正式保存接入的工程提案。同步状态、工程导航和开发顺序，修正文档索引仍称“仅设计文档”的旧描述；未改战斗代码或安装插件。

- 2026-10-27操作界面大框架：默认入口切换到新白门楼界面；采用用户批准的三国志式美术、兰斯10式布局。加入天下/区域地图、人物编队、三槽行装、事件、HUD演练、关末抽卡、独立自动/手动行军档、见闻、设定与音乐页。新增三份运行美术与许可明确的地理示意数据，旧版战斗保留单独入口。新战斗和经验系统尚未接入；演练档不覆盖旧档。同步最近确认的持有加成、特殊支援、装备对象与七项属性。验证与截图见[制作记录](docs/design-reviews/2026-10-27_操作界面风格与制作方向.md)。

- 2026-10-27关内规则确认：经验按进关时实际配置人数均分，阵亡不改分母，候补与战后加入者不追分；敌人掉落经验物，局内拾取即时成长，Boss被击败后收取剩余经验，存活敌人不补算。Boss出现后停止普通刷怪，已有敌人与额外精英保留，专属援军有限且经验有总量限制。同步共识、成长、关卡、保存与验收文档，未改运行代码。

- 开局、人物与装备修正：初始只有贾苇索，两辅助位为空；城外首遇改为复用已有魔法师的艾玛，首关剧情直接加入并入池，同时正常五选二。女剑士改为后续获救，枪手和机械师留后续战役；异世来客与原住民主角分开。三槽确定为护甲／武器／饰品，分别承接受击效果／主角攻击形态／攻击附魔，撤回装备仅基础加成的限制。原36张预算新增艾玛后暂计37张；同步当前设计、路线、卡池与保存验收，未改运行代码或素材。

- 奖励与保存确认：抽卡精英使普通关五选三；章末七选三且候选至少两张重要卡，抽卡精英成功七选四，保底遵守剧情开池。切人保留临时效果和召唤物，过关清理，HP／MP／阵亡／冷却延续。参考《兰斯10》采用多手动档与自动续档；战斗退出回进关前，待结算恢复同组候选，读旧档整体回退。同步规则和验收目标，未改运行代码。

- 状态规则补充确认：未配置候补状态冻结，只有本关三人回魔与推进冷却；升级回满存活人物生命与魔法但不复活阵亡者，候补重复卡升级也可恢复；Boss死亡立即通关，未击败的额外精英不发奖励。同步规则与交接，未改运行代码。

- 实施前规则确认：普通关随机五选二；随行人数无限，关间从全部符合战役条件的人物中换至多两辅助，新卡下一关可用，撤回预选有限名单与容量扩充。新人物按解锁阶段设初始等级，重复卡升1级保留经验；每人最多2个手动关键技能，全队共享3槽，本关三人均分经验且阵亡仍分。新增确认记录，状态、额外／章末奖励和数值继续讨论，未改运行代码。

- 卡池方向确认：人物跨战役复用，加入吕布、张辽、高顺、陈宫及虎豹营将领等重要人物卡；全游戏沿用对应剧情完成后入池，张辽／高顺／陈宫由吕布前的精英关及剧情解锁。普通N卡可复用素材微调改色。新增36张卡目录提案（8具名武将／谋士＋10女性伙伴＋18张N卡），撤回旧14张卡上限和吕布不入池提案；同步规则、首章、UI保存需求与交接，未改运行代码或生成素材。

- 首章范围确认：白门楼自成完整大章，主要参考《兰斯10》的节奏。扩充现有首章草案，建议12名女性、12张基础辅助卡与2张主线预留卡、36个路线节点（制作18战、单次12—15战）及分段开发；数字、人物席位与加入条件仍待讨论，未改运行代码。

- 白门楼剧情修正：贾苇索劫掠并侵犯成年吕玲绮的事件发生在抵御鬼曹军之前，过程略去，救城之恩与伤女之仇共同承接吕布终战。同步首战、主线、背景、产品及交接；人物后续反应与结局未定，未改运行代码。

- 首战确认：白门楼鬼城以贾苇索听闻吕玲绮而出征开场，经进城掳掠女剑客、杀匪杀官与夺地壮大，抵御鬼曹军救城及吕布一家，最终对战吕布，开启诸侯起家之路。重写首段草案和主线入口，撤下县城解围与虎牢关首战试排；终战理由、节点、人物去留和领地仍待讨论，未改运行代码。

- 人物确认：男主定名贾苇索，结合苇索缚鬼与“假猥琐”的双关，大事上极其正义、极有正气。同步共识、背景、定位、战斗与产品入口；身世、存在形态及武器仍未定，未修改运行代码。

- 风格校准：按用户要求核对《兰斯》官方人物、剧情、系统与TADA访谈，明确直接的欲望表达、成人喜剧和冒险群像参照；撤回过度细腻的恋爱养成及统一关系成长流程建议。同步背景、产品、首段与交接，保留女性相关内容约占一半的方向，未改运行代码。

- 体验方向确认：女性角色的暧昧与亲密陪伴希望约占整体体验的一半，与征战共同规划；认可苍凉威严、山河壮丽、民俗奇趣和英雄情义，加入鲜明的风流气质。女性阵容来源暂不限定，当前先讨论整体体验。同步产品、背景、首段内容与交接，具体关系机制仍未定，未修改运行代码或素材。

- 背景确认：采用三国已经覆亡的架空世界，遗迹与鬼怪遍布，名将主要以亡魂或异变形态重现。《黑神话：悟空》作为风格参照之一，整体结合其他气质，具体组合未定。新增世界背景文档，同步产品、视觉、主线和首段草案；撤出历史黄巾开局的默认前提，未改运行代码或资源。

- 开发方向确认：以《兰斯10》第一部为长期目标体量，分阶段推进，先做参考其开场的入门战役。新增首段题材、路线、人物、敌人、奖励与开发顺序的讨论草案；具体制作数量仍未确定，未启动运行代码实施。

- 设计确认：采用三国背景和两层地图。天下图展示全部州/大模块，用于查看信息、天下局势与选择大战役；战役区域图显示相关一大片区域，以小关、精英关和恢复/事件节点连接至最终Boss。认可一次大战役对应一次出征、有限主线行动、预选可扩容随行名单及出征返营全员恢复；具体年代、区域边界、路线、节点与行动数量仍未定。已同步共识、主线、UI/存档与验收文档，未修改运行代码或导入地图资源。

- 设计讨论：参考《兰斯10》的任务与战况组织，补充三国背景下主线阶段、一次出征、大战役和小关的对应，用攻关路线说明卡牌、恢复、支线与局势后果。行动次数、出征恢复和随行名单均标为待确认提案；未更改已定规则或运行代码。

- 背景调研：整理三国州域、古地名坐标和城池节点数据来源，核对许可及简化州界的落区缺口，比较《三国志14》与《真·三国无双：起源》的地图层级。年代、分区和战役路线仍在讨论；仅记录调研并更新入口，未导入地图数据或修改运行代码。

- 设计确认：关键技能按键只调用当前角色，各角色复用同一组按键；后台支援自动。魔法用于手动关键技能，普攻、常规自动技能和自动后台支援不耗魔法。后台继续冷却并按角色自身回复属性回魔，生命恢复依赖恢复能力或补给；切换不回血回魔。已同步设计与验收文档，未改运行代码。

- 设计确认：关内不需要鼠标，普攻、常规技能和攻击/技能方向自动，关键技能手动且可以有多个，整体操作复杂度保持较低。一般只有当前操作人物直接承伤，允许特殊辅助代主角承伤；辅助分别设计前台、后台与持有被动，阵亡停支援但保留持有收益。切换采用短暂公共冷却，保留独立资源和技能冷却，不附赠通用无敌或刷新；特殊登场效果按人物设计。已同步设计文档，未改运行代码。

- 文档重构：建立[当前设计共识](docs/00_当前设计共识.md)，落实固定主角＋两名可控辅助、人物卡/经验升级、等级自动解锁、持有角色加成、四角场域、Boss通关、跨关状态、保留装备与失败回退。重写产品、战斗、成长、主线、状态、路线图和交接入口；删除17份被替代规格/草案（含本轮两份早期草案），另替换旧04/10文档路径；保留重构前运行基线及技术/素材证据，简化评审模板，清理旧链接。尚未决定的数值和规则继续标为未定；本次没有修改代码、资源、测试或存档。

- 全局主要界面采用古金雕花框、深绿/酒红底板和衬线标题，覆盖主页、双选档、主线准备/阅读/记录、营地、人物页、暂停、奖励和战斗 HUD；保留原有玩法与存档流程。主页大背景按当前剑士、枪手、法师和机械师四人重新绘制，并为导航保留左侧空间。
- 主页新增「音乐鉴赏」，直接试听现有全部14首原创配乐，支持选曲、上一首/下一首、播放暂停和拖动进度，曲终顺序播放；沿用全局音量/静音，关闭后恢复主页音乐原位置。
- 架构健全性整改：运行档验证嵌套类型与坐标，坏主档可回退好备份；恢复失败阻止继续和自动写回，无尽清理失败可重试且不重复发奖。补齐旧最小档角色分享初始化的类型边界。
- 战斗退出释放离树对象池；延迟伤害核对敌人激活代数。有效投射物每物理步检查命中并保留到期尾段，修复方形Boss框角落的静止弹假命中；低帧拥挤不再跳过出生预警。
- 暂停由场景内原因集合统一控制，HUD与音乐使用只读会话视图；敌人配置完成后发布身份，第三关显示“讨伐用时”。机械师五主动技能支持真实手动施放，火球悬停参数与运行数值同源，敌人资源/关卡引用由权威清单校验。
- 清理旧测试合同与无效108节点展示，保留合法旧build和已存角色天赋效果；完善必需引擎/导入错误检查、每测试独立存档与日志、Graphify残缺更新回滚，并清理MCP编辑器工具退出时的引用环。
- 减少保存有限值遍历中的路径分配和JSON对象键排序，保持完整验证与原子主备写入；敌弹同一tick复用目标准备，跨帧及伤害回调后失效。补齐真实主场景全帧、保存分项和十次入退测量；高密度仍超过60FPS预算。逐项验收与性能边界见 `docs/implementation/2026-10-25_架构健全性整改.md`。

- 完成14份原创配乐：营地、三关、两精英、三小Boss、最终Boss三阶段与胜负短曲。巴赫式声部组织结合东方式战斗主题；REAPER工程、MIDI、48k/24bit无损母带、Ogg与技术QA保留在 `design/music-20261025/`。只做音乐，不做台词配音。
- 音乐按真实关卡/波段/存活特殊敌人选择，支持双精英优先级、复活、Boss阶段同时间轴淡化、音量静音、暂停/旧档位置恢复及一次性结算。四个旧占位音乐保留源文件但移出场景与导出包。美术/关卡审计及后续推进见 `docs/design-reviews/2026-10-25_美术关卡与配乐制作推进.md`；地图与玩法提案没有在本轮改造。

- 主线准备重做为“等一声回答”的夜间通讯营地：当前线索/NPC滚动栏、随任务变化的环境短句、隐藏未解锁地点名的三关路线，以及发现后可查看、交付后转为情报的物件入口；查看不推进任务，已通关重访仍仅供练习。
- 主线对话改用全屏场景和底部阅读带，重写13段29节点的原创短句与独立环境旁白；记录页支持定向页签并回看已见旁白。保留接取/交付明示、120%文字、减动画、键盘焦点、保存失败反馈与Esc断点；稳定ID、选择命令、内容版本1和原三关保存业务保持。该项界面改造未新增可行走剧情地图或战斗机制；玩家实玩与阅读节奏尚待验收。配乐见上文独立条目。详见 `docs/design-reviews/2026-10-25_主线场景与叙事呈现.md`。

- 开放故事首章：接任务、三关出击、首通剧情物品、返营交付、情报与已读对话、断点恢复和练习回刷。使用稳定内容ID、schema2及独立尝试身份，保留旧档进度、核心与四角色。
- 修复永久坏档被空槽覆盖、语义无效run未回退备份、小Boss奖励续战丢失及最终结算失败后无恢复入口；补齐失败/放弃结果保存、同关重试与写盘失败反馈。
- 骨头拾取先保存余额与本局拾取凭据，再移除拾取物；写入失败可重试，旧战局快照中的同一拾取物不重复计入，凭据随本局结束清理。
- 暂停页复用完整设置；新增独立界面音效音量、合成提示音、减动画、常亮出怪预警及剧情正文放大。修正波次/主线计时、当前按键教学和各角色技能点高亮。
- 添加剧情内容与运行回归、隔离测试存档、Linux开发导出预设和内容包检查；测试兼容当前快照接口，并修复读取不存在的待结算标记时的报错。人物技能设计/数值与怪物机制保持当前版本。
- 2026-10-23阶段结果与当时未通过的既有回归见 `docs/implementation/2026-10-23_系统框架实施.md`；现行回归结论以上方架构整改为准。上述变更按功能拆分提交，未推送或公开发布；默认暂停后二次退出的奖励候选恢复缺口留待后续修复。

- 重做三个技能特效：魔眼聚合改为细长紫色激光加农炮（聚能炮口、沿光束推进的能量脉冲、抖动芯线、后坐喷溅、命中亮点，判定宽度不变）；火球术改为聚能期间火球沿抛物线飞向落点、抵达爆炸并留下带火舌与裂缝的燃烧地面；火焰之径改为焦黑地面带上成簇摇曳的火舌与火星，越旧越矮越暗。只改表现，伤害与数值不变。

- 重构法师“波涛汹涌”为现行 LV0-LV9 技能加点构筑：LV4、LV8、LV9 分别选择分支并写入法师角色存档；实现回流、洪流、水径、清泉、潮涌与叠浪效果。

- 法师「通电」感电改为每层护甲 -20、易伤 +5%，最多 3 层；满层后下一次受伤追加战场角色 400% 攻击力伤害并清空层数。感电易伤计入独立易伤乘区，叠层与引爆均显示小闪电命中特效。

- 法师普通攻击 LV6 改为伤害倍率 +25 个百分点、普通攻击大招能量获取效率 ×1.2、基础攻击速度 -0.20；移除 LV6 原有雷击范围 +30%。

- HUD 原生提示统一改为鼠标悬停 1.5 秒后显示。法师进入火焰之径时，角色头顶显示随剩余持续时间缩短的图形进度条，不显示数字；切换角色、状态结束和读档恢复均正确处理。

- 聚雷改为攻击速度 -50%、雷击范围 +25%、伤害 +30 个百分点，当前大招能量百分比等额转为攻速百分比。勇猛移除攻速惩罚，改为普通攻击命中敌人击退50，暴击与伤害加成保留。

- 战意普通攻击触发概率由10%调整为30%，其余触发限制、1秒冷却和回复效果不变。

- 剑士普攻构筑数值调整：分裂扇形改为150°、半径200，伤害仍为当前倍率50%；地裂半径改为175，延迟1.5秒后造成当前倍率300%伤害，保留每刀一次与待爆炸区域不重叠规则。

- 法师神绛改为每3次雷击触发全屏神绛雷：第三次雷击后延迟0.4秒出现，黄色特效保持普通雷击大小，对全屏敌人造成当前伤害倍率150%；狂雷整组三道合计计数一次，神绛雷不重复计数。

- 波末改为顺序收尾：残怪先播放0.7秒倾倒、压缩与消散动画，期间不计击杀、不掉奖励；动画结束后全部经验晶体实际飞向角色，到达后才发放经验。全部吸收、升级结算完成再停留0.5秒，之后打开免费Build菜单；小Boss原奖励也延后至收取结束。收尾期间不刷怪、不开始整备倒计时，收尾阶段与进度支持存档恢复。

- 第11波引渡人关卡自然刷怪仅保留远程骷髅、散弹骷髅和骷髅法师，每3秒补1只，场上分别最多3/2/1只，预警计入名额；死亡领域原有补齐10只冲锋骷髅的技能保留。

- 技能点改为角色独立持有：队伍每升一级，每名出战角色各获得1点，学习技能和升级普攻/已有技能仅扣当前角色点数；切人后加号与高亮跟随该角色余额。存档保存各角色点数；旧档将原公共剩余点数分别保留给每名角色，已学技能不变。

- 波末自动吸收场上全部经验晶体，含Boss最后掉落；残怪清退仍不产出奖励。整备结束（含跳过）将全队主动技能剩余冷却设为0.2秒。第6波护卫开局2只，每1.5秒补1只成年幽影树怪，逐步补到场上20只，死亡后继续补充；树种与幼年共享6只上限不变。

- 每波结束自动弹出Build界面，从3个随机通用祝福中免费选择1个，不消耗技能点；候选沿用当前等级的祝福阶级权重，不包含角色技能。选卡暂停战斗与整备倒计时，小Boss原奖励结束后再选，最终波选完后通关。未选候选与领取状态随波次存档恢复，已选奖励不会重复发放。

- 20波模式改用专属经验曲线，经验获取倍率由沿用的2.43调整为0.22，升级需求按波次流程重新标定并移除20级旧门槛突增。第6/11/16波小Boss的经验原值为500/700/900，仍经过晶块与难度倍率结算。参考预算第1/5/6/11/20波约为Lv3/10/11/17/28，实战随击杀和拾取变化；旧运行档保留等级、技能点和当前等级内经验比例，新档保存曲线标记避免重复迁移。

- 波次结束时自动清退未击杀的剩余怪物，包括普通怪、精英与召唤单位；不触发击杀计数、经验、爱心、骨头或经验引力晶核掉落。已击杀怪物掉落在地上的奖励保留。Boss波仍须击败Boss才结束。

- 生存/无尽战斗改为20波混搭流程：普通波60～90秒，第6/11/16/20波为Boss波，第7/12/17波为奖励波；限制中等与拔高怪物数量，飞眼群改为独立掠袭事件。每波结束保留残怪并进入30秒整备，停止自然刷怪；阮狗出现，靠近可免费领取一次「急救」，为全队各自恢复已损生命的50%，交易期间战斗继续。支持跳过整备直达下一波，阮狗可被残怪碰撞和敌弹击杀；波次、整备时间与领取状态支持继续存档。故事和开发者模式保留原独立流程。

- 轻剑攻击速度加成由 +50% 调整为 +30%，伤害倍率 -25 个百分点不变。

- 轻剑数值调整为攻速 +50%、伤害倍率 -25 个百分点；地裂半径改为 1750，圆形裂地视觉同步缩放，1.5 秒后造成当前普攻倍率 200% 的伤害。重剑维持攻速 -50%、范围 +200%、倍率 +65 个百分点，有连击时连击间隔 0.5 秒。

- 重剑调整：攻击速度 -50%，普攻范围 +200%，伤害倍率 +65 个百分点；有连击效果时连击间隔为 0.5 秒，刀光视觉继续随实际范围同步放大。

- 剑士战意回血限定为普通攻击命中触发：基础触发率由 5% 提高至 10%，同一次攻击的多目标判定上限由 2 次提高至 4 次；技能、分裂、地裂及反弹伤害不触发，延迟伤害共用本次攻击判定上限。保留原回复量及 1 秒冷却，同步人物页与特性说明。

- 技能点高亮收淡为 1 像素半透明黄色细边，移除外扩光晕，仅保留轻微提示。

- 调整技能点 UI：移除技能点数量提示，将技能栏上方的“＋”改为醒目的黄色按钮；有未分配技能点时，普通攻击、已有技能和空技能槽统一显示黄色高亮边框，分配完毕后恢复原样。修复技能图标裁剪导致上方加号不可见的问题。

- 重构经验升级奖励：角色每升一级获得 1 个技能点，不再自动弹出旧的“四选二”升级菜单。已有技能与普通攻击的图标上方显示独立“＋”，点击直接消耗 1 点升一级；空技能槽的“＋”只提供当前角色尚未拥有技能的三选一，不包含通用祝福。技能点与未完成选择支持运行档保存恢复，开发者等级提升也遵循该规则。

- 重绘愤怒豪猪、亡灵牧师、幽影树怪、幽影树怪·幼年、藤蔓怪、骷髅法师的本体外观：不再沿用这几只怪的旧造型，改为参照游戏其他怪物与角色的细颗粒写实像素风，分别为冠豪猪、送葬牧师、垂柳树人与种荚幼体、猪笼草、骷髅学者；技能特效保持不变。新增受击特效：闪白、以脚为支点的挤压回弹与后仰，以及按材质区分的碎屑迸溅。只改表现不改数值。素材由 `scripts/tools/enemy_pixel_art/` 生成。

- 移动减速统一逐项乘算：最终速度＝减速前速度×各项（1－减速率）；同一技能重复命中只刷新持续时间，不同技能独立计时。覆盖玩家、敌人、持续领域与装备减速，补齐存档恢复、净化和对象池回收。

- 无限装填重构为LV0～9：基础40%攻击力/0.25秒、持续4秒，结束后开始36秒基础冷却；新增轻盈步伐/瞄准、灵魂形态/灵魂冲击、火力调控/双发冲击。瞄准按150°/秒追随鼠标，双轨全额独立命中，灵魂冲击跳过护甲与减伤且保留易伤/护盾/无敌/转阶段保护；同步分支卡、开发者菜单、技能详情和施放中存档。

- 合并 PR #15 最新机械师成长、天赋与营地界面改进，保留三角色普攻和剑刃风暴 LV0～9 构筑及易伤独立乘区；修正构筑读取异常角色存档时的空值处理。

- 接入易伤独立乘区：易伤倍率为 `1 + 当前易伤率`，位于护甲之后、减伤之前；敌方已有易伤状态开始影响普通受伤结算，角色新增易伤读取接口，暂无来源时倍率为 1。

- 合并本地玩法改动与 PR #15 的机械师美术、选卡、技能信息及人物页；人物页保留基础攻击速度、增伤、状态抗性，接入现行LV0～9构筑与LV4/8/9分支，并补齐剑刃风暴、风息及骷髅法师效果的属性来源。波次与技能点新方案仍仅处于讨论阶段。

- 豪猪针刺新增向四周快速射出的尖刺视觉：24根尖刺以900速度飞至150半径并淡出，愤怒时变为红橙色；跨生命阈值触发视觉，伤害目标规则仍待确认。
- 新增亡灵牧师，开发者模式可生成、上限2只且分居地图左右；实现普攻及其构筑衍生伤害免疫、每5秒全场恢复30%已损失生命、半径250亡灵印记将生命回复转换为可致死的直接扣血且保留枪手被动Buff。新增祭袍骨杖外观、施法特效和印记状态显示，支持存档及对象池重置。
- 新增藤蔓怪、幽影树怪与仅种子孵化的幽影树怪·幼年，接入开发者模式，暂不加入正常刷怪；实现只禁移动的缠绕与周期伤害、定向寄生种子及落地延迟爆炸、可击毁树种与落地孵化，新增植物外观和种子预警，支持战斗存档与对象池重置。
- 骷髅法师死亡汲取触发半径改为200、维持距离250，不洁领域半径改为300；全场同时最多一个领域，保留各法师独立冷却，领域结束后其他就绪法师可立即接续释放。
- 开发者模式击杀任何怪物不再掉落经验晶块；统一在掉落入口阻止生成及合并经验。
- 修复骷髅法师死亡汲取向玩家 `take_damage` 多传参数导致的运行错误；新增真实玩家逐秒伤害、回血和脱离结算回归验证，测试替身与真实接口保持一致。
- 新增骷髅法师，当前仅开发者模式可生成，场上存活上限4只；实现死亡汲取、刚毅身躯、寒冰护甲、不洁领域及N3一次性死灵身躯。新增紫袍骷髅法杖外观、汲取光束、寒冰晶体和领域法阵，玩家减攻速/领域负面状态显示在Buff栏；技能状态、临时生命和领域支持存档及对象池重置。
- 刚毅身躯不再被眩晕、破盾或转阶段阻止，各行动状态下存活怪物仍按原碰撞伤害与 1 秒冷却触发；保留角色特殊状态免疫，死亡和墓碑等待复活时不触发。
- 风息新增瞬杀同款 HUD Buff 显示：青绿色“息”图标、持续进度及悬停完整效果/剩余时间；切换角色后保留显示，到期自动移除。

- 剑刃风暴验收修复：未解锁时角色面板保留解锁提示；补充真实伤害边界、牵引/减速、属性恢复与GPU截图验收。

- 剑刃风暴重构为 LV0–9：半径150、每0.3秒80%攻击力、持续2.7秒、冷却32秒；LV4台风/狂风、LV8烈风/风息、LV9龙卷/风刃。烈风削甲每层独立15秒且无上限；龙卷脱离瞬间触发风息、恢复普攻，移动速度70并额外持续同等时长；风刃触发普攻攻击特效及被动并翻倍概率。同步角色属性、分支卡、开发者菜单、面板和战斗存档。

- 重剑调整：普攻范围改为 +150%；重剑命中敌人时触发轻微屏幕震动；重剑连击间隔改为 0.5 秒。
- 修复剑士普通攻击刀光尺寸固定的问题：按实际斩击长度与宽度缩放，重剑范围加成同步放大刀光，并使用相同的镜像偏移尺寸。

- 法师普攻新增攻速代价：狂雷基础攻速 -0.15、天雷 -0.1、雷震 -0.15 次/秒；LV6 普攻攻速 -10%（按既有加法公式计入 -0.10）。面板基础攻速显示分支修正，降级与替换分支自动移除对应代价；最终攻速下限调整为 0.15 次/秒。

- 新增全单位基础属性「状态抗性」：剑士 10%，枪手/法师/机械师及非 Boss 敌人 0%，所有大小 Boss 20%。独立来源按 `1-∏(1-R)` 叠加，有时长负面状态按剩余比例缩短，Boss 演出待兑现眩晕也折算；角色面板显示最终抗性，敌人存档保留抗性来源，读档不重复缩短状态。

- 法师普攻重构为 LV0–9：狂雷/通电、聚雷/天雷、神绛/雷震分支；狂雷锁定首次落点，间隔 0.2 秒、0.45 秒并逐次增强震动，第三道结束后开始普攻间隔。新增永久三层感电、动态能量攻速、穿护盾直接伤害与黄色追加雷，同步升级卡、面板、开发者菜单。
- 新增按技能时长直接生效的眩晕，无控制条或积累机制。眩晕停止移动和主动攻击，打断普通蓄力，刚毅身躯仍可触发；Boss 演出及收尾每轮只将首次眩晕时长加到下一次瘫痪，瘫痪、破盾及转阶段免控。冷却和已有弹道、地面效果继续运行，恢复后重新决策；状态支持存档及对象池重置。

- 枪手普攻重构为 LV0–9：基础倍率 150%，LV4 连射/狙击、LV8 爆裂/强震、LV9 贯穿/狂猎；强震伤害倍率加 50 个百分点并可击退 Boss，连射每颗分别判定狂猎，分裂弹不触发攻击特效。接入批量子弹、攻速、升级卡、角色详情及开发者菜单。

- 开发者菜单顶部固定“收起菜单”按钮，敌人子菜单不再遮挡；收起后仅保留“展开菜单”，展开后保留当前分类、搜索和选择。
- 重构开发者菜单为祝福、角色 build、商店物品、战斗调试四页，加入搜索和效果详情；移除旧祝福、旧等级天赋与技能阶级入口。支持七种现行祝福按阶级/数量增减、全部现行商店物品份数调整、技能等级设置/重置，以及剑士 LV4/8/9 分支替换与降级清理；操作立即刷新角色属性，仅修改本局开发者状态。
- 重构剑士普通攻击构筑：从 LV0 到 LV9，LV4/8/9 分别选择并保留重剑或轻剑、分裂或地裂、守势或勇猛；加入 0.25 秒当前位置追加斩击、裂地延迟伤害、扇形派生伤害、护甲跳过、敌方弹道镜面反弹、弹道对象池与战斗存档支持。角色面板和升级卡同步显示新等级与分支。
- 新增「经验引力晶核」掉落：击杀任意单位时有 0.05% 概率出现，外观尺寸接近回复爱心；拾取后吸引当时场上的全部经验晶体飞向玩家，支持对象池与战斗存档。
- 修复返营清空永久携带物品、同一商品按钮阻止重复购买、匕首暴伤未计入战斗、毒石不在售卖/保存白名单及 11 件商品缺少累计预览。营地商店改为四分类列表与详情、分离购买/逐份退款，写盘失败不改变物品和骨头。
- 补齐机械师驻营，四角色提供定位/基础属性/技能介绍；营地形象跟随阵容首位。队伍整备支持替换、前后重排和属性预览，存档失败回滚。营地增加骨头/N/阵容/携带/最近结算概览、出击配置确认、铁匠装备入口及现有像素素材分区；统一面板移动锁、Esc/F 与焦点。最近通关摘要随幂等奖励保存，补充设计、截图及端到端回归；不新增货币、设施等级或打造树。

- 实现机械师八条技能线的 16 个专属天赋：离线工厂/精密堆叠、双机接应/预装弹链、蜂群指令/穿甲履足、双机编队/应急维修、环形雷阵/震荡装药、强磁共振/随行维保、双联供弹/超频枪架、集束炮击/高爆弹芯。沿用 5 级先选一个、10 级补齐与已有存档槽位；选卡、悬停、人物页和 HUD 显示真实效果。登场与主动机炮分开消费天赋，恢复不重放多机施放，高爆每发一次且不受特效预算吞伤害，对象池不串效果。补充战斗设计文档与回归；按要求暂不做平衡调参。

- 补齐机械师八条技能线的 1–10 级成长：零件效率、蜘蛛伤害/距离/速度、两类机炮与重炮的火力/时长、地雷伤害/半径、力场伤害/半径、守卫冷却与格挡里程碑。升级卡、人物页和 HUD 共用当前数值；力场画面与伤害/回复判定同步。登场和主动机炮分别记录并保存部署来源，兼容旧档；增加战斗、预览、等级上限、保存恢复与 UI 回归。

- 规整架构职责：战斗技能栏的五类绘制控件拆到 `scripts/ui/hud/widgets/`，由控件自身管理动画生命周期；隐藏、未就绪或锁定时停止无效逐帧更新，切换角色、布局和隐藏 HUD 时清理拖拽状态。角色天赋与旧 108 节点定义分别放入独立数据目录，保留现有接口、存档 ID 和停用入口。
- 技能等级与构筑查询改为只读，不再遍历整个玩家属性表或补写缺失状态；初始化与修复留在写入/存档边界。补充异常状态、写入初始化和 HUD 生命周期回归；修复五个技能测试未释放的 Node 替身和特效。
- 整理设置页：全部按键可滚动访问，分类有选中态，静音有明确标签；Tab/Enter/Space 可正确改键，Esc 取消改键或关闭设置，键盘焦点留在弹窗内并在关闭时归还。共用弹窗保留入树前设置的标题，统一中文阅读字体与按钮焦点/禁用样式。
- 校正切人能量、12:00 Boss 到场、法师名称和中文结算提示；对齐技能等级、天赋停用状态及阮狗物品经济的文档与路线图。配置检查接受 Godot 4.6.2 省略的窗口默认值，同时拒绝显式错误配置；补充实际 UI 截图与整理评审记录。

- 弹丸像素回归兼容软件渲染的 8 位通道舍入差异：玩家弹丸容差 1/255，Boss 透明叠层容差 2/255，超限立即失败退出；保留实例与画面比较，CI 作业增加 20 分钟上限。

- 修复完整检查入口：像素回归使用 OpenGL 绘制，CI 通过 Xvfb / Mesa 提供虚拟显示，避免 headless 等待绘制信号；补齐角色、敌人和投射物测试替身，按现有护甲、复活及 Boss 移动规则校正断言。渲染测试自行准备快照目录，不再依赖 Windows 的 TEMP 变量；Graphify 仅更新已有索引。

- C 键人物页改为总览、技能、祝福、装备四栏目与固定来源区：11 项属性首屏可见，按实际战斗运算追溯加值、倍率及闪避/减伤合成；技能先显示当前效果，祝福按所有阶级与附加属性合计，装备提供明确的赠与按钮。保留角色查看隔离、共享阮石、原赠与验证及奖励暂停上下文，增加键盘导航和只读角色强化清单；同步运行截图与回归检查。显式保留可调整窗口与 keep 比例配置。

- 保留原有四张纸面卡牌、弹出动画与单卡刷新，重排角色归属、类型、等级变化、主要收益和次要变化；增加已选计数与标记。悬停约 0.18 秒后在卡牌下方展示完整说明，剑士普攻显示等级成长对照，祝福显示本阶持有份数变化，新技能展示能力与冷却。修复摘要硬截断、等级字段漏显及黑底黑字；天赋占位和缺失成长说明明确标注。
- 两种战斗 HUD 共用新的暗金技能详情，显示所属角色、技能等级、自动/手动、冷却与待命状态；可见冷却随 HUD 更新，浮层放到技能栏上方。定点机炮和重型炮台的倍率、射击间隔与持续时间读取运行时 getter；复用原有伤害规则与存档字段。

- 校准重做后的机械师体型：战斗与营地显示缩放从 1.25 调为 1.1，待机/奔跑身高约 86–89 场景像素，与其他英雄接近；战斗基准位置从 `(0,-8)` 调为 `(0,-4)`，使脚底与队友处于相近位置。

- 重做机械师人物、头像与 8 组机械装置/特效：参考玛利亚的蓝发、圆眼镜、红发带与米色工具外套，采用独立的 4 帧待机、8 帧奔跑、4 帧控制器操作动画；普攻、部署与大招接入操作动作。炮台朝左/斜向瞄准和读档后保持底座直立，炮弹从对应炮口发出，开火后回到静止帧。同步营地、角色面板、透明边界和特效半径；保留技能数值与存档字段。新增原始生成图、提示词、Aseprite 导入脚本、动画预览与视觉回归检查，替换旧法师改色/几何绘制脚本。

- 精英冲锋骷髅同步 N3 冲锋强化：前摇 0.3 秒、固定冲锋速度 300；所有难度的地面区域默认尺寸调整为 200×80，显示和碰撞一致。保留冲锋伤害、距离、冷却及区域伤害、减速、持续时间。
- 普通冲锋怪 N3 及以上强化冲锋：前摇 0.6→0.3 秒、固定冲锋速度 250→300，预警同步加快；最大距离 500、伤害和冷却保持原规则，精英冲锋怪不受影响。
- 重甲南瓜 N3 及以上强化「重甲形态」：持续时间 3→5 秒、冷却 20→18 秒、额外护甲 +20→+100，实际损失生命值反弹 5%→15%；N1/N2 及非 N 层保持原数值。
- 飞眼群在 N3 及以上解锁被动「群疫」：造成伤害后施加 1.5 秒「瘟疫」，减速 20%、治疗效果降低 30%；重复命中刷新时间、不叠加幅度。接入治疗、移速、状态栏、暂停与存档，保留原目盲规则。
- 疾行史莱姆在 N3 及以上解锁「疾行」：移速 +50、持续 4 秒、施放后冷却 15 秒，出生及冷却就绪时自动施放；接入普通与批量更新、运行存档和对象池清理。
- 阮狗商店新增物品「失败刺客的短匕」：全队角色移动速度 +2%、普通攻击速度 +3%；同一物品可重复购买，效果按份数线性叠加。
- 普通攻击频率改由角色基础攻击速度决定，间隔为 `1 / 最终攻击速度`；剑士/枪手/法师/机械师基础攻击速度为 0.7/0.85/0.4/2.0 次/秒。普攻构筑与「王国：祷告」改为普攻攻速百分比加成，不影响主动技能冷却；角色面板新增基础攻速与当前攻速、攻击间隔。
- 恢复最终 Boss 破盾后的常驻被动牵引：基础强度 50/秒，保留原顺向/逆向修正，基础、预告、演出、收尾和瘫痪期间生效，破盾/转阶段演出暂停；主动引力球期间不会重复结算。等待演出弹丸结束时恢复基础环形炮弹，沿用当前血条的弹数、射速和 80% 攻击力伤害；新炮弹自然飞完且不拖延进入 9 秒瘫痪，支持存档及对象池复用。
- 按用户要求，将最终 Boss 技能分支截至 `0808750` 的改动全部合入 main：包括暗属性球弹与六套演出、完整收尾、全阶段弹幕优化、9 秒瘫痪及四角色基础属性提升；同步补齐新增脚本的 Godot 资源标识。
- 最终 Boss 收尾时已有引力球继续绕行，直到残留攻击自然结束，不再因剩余自机弹发完而停住；不会额外启动新连发。“能量平息”更名为“瘫痪”，4→9 秒，保留期间护甲降低 50；仅瘫痪期间显示 Boss 状态文字和倒计时，其他阶段保留场景预警。旧运行档沿用已过时间。
- 最终 Boss 全阶段弹幕优化：四层球弹外观共享 MultiMesh 实例数据，保留原几何、柔光、描边、亮芯与弹丸间叠加顺序；池复用保留实例位置，只提交变化，取消逐弹四层节点及重复默认初始化；内置敌弹直接批处理，共享玩家受击范围查询并在命中后刷新。保持弹量、攻击方式、伤害、轨迹、寿命和完整收尾。OpenGL 固定 Boss 场景 13 项同次对照玩法数据一致，末条血六主题平均帧耗时下降约 60%～67%，详细证据见 `docs/performance/2026-09-20/boss-all-phases.md`。
- 魔法石演出增加自然收尾：计时结束后补完待发波次、自机弹、激光与蓄力攻击，等待现有弹丸及分裂子弹结束再进入平息，避免刚发射就清空。平息 2→4 秒，期间护甲降低 50（基础 10→−40），结束自动恢复；状态与减甲支持存档。护盾完整只释放基础环弹，破盾首条血仅污染迸发，第二条血加入暗流回旋/裂隙脉冲及分裂弹，末条血开放六主题和激光/引力组合。旧基础环弹、分裂弹和裂晶齐射统一为新紫色/紫黑球体。
- 四名可操控角色基础移速 +10、攻击 +5、最大生命 +50：剑士 150/25/200、枪手 160/20/170、法师 140/30/170、机械师 140/23/170（依次为移速/攻击/生命）。旧运行档同步基础模板，保留升级、装备、祝福和当前生命，重复载入不会累加。
- 魔法石技能分支的弹体改回与原 Boss 一致的紫色/紫黑色球形风格：移除碎块、尖晶及裂纹外形，改用圆形亮芯和略增强的柔光，基础深紫球弹与分裂球弹也稍提亮。保留全部弹路、弹量、伤害、寿命和碰撞判定；上一版外观随读档迁移为球弹。
- 魔法石技能分支统一为暗属性石质风格：移除蝶形/花瓣外观、整体蝶翼图案及相关命名，替换为黑曜碎块、尖晶、暗矛、暗能球和紫蓝能量裂纹。六主题改为「污染迸发、暗流回旋、魔核过载、裂隙脉冲、蚀晶风暴、深渊倾泻」，十二小节同步改名。保留分段时长、弹量与伤害；旧运行档外观自动迁移，普通敌弹外观不受影响。
- 技能分支参考幽幽子的樱花与蝶群意象，将魔法石扩为 6 套主题、12 种弹路，每套内部三段变招。新增蝶翼轮廓、层叠花扇、交织弹网、S 形蝶群、双花旋转、花雨和减速悬停再变向；增加蝶形、花瓣、米粒弹体，HUD 显示小节名。后两条血以「冥蝶之舞」「返魂蝶潮」开场；保留基础/演出循环时长、既定伤害和每组弹量，补齐新轨迹与图案编号的存档恢复。
- 技能分支将被污染的魔法石改为分段战斗：前两条血按「基础 12 秒→预告 1.5 秒→演出 15 秒→收尾 2 秒」循环，第三条血调整为基础 8 秒、演出 18 秒。「污染绽放」「双螺旋回廊」「魔核过载」依次展开和变招；HUD 显示招式名及倒计时，激光提前 1.2 秒锁定方向预警，牵引仅在第三条血过载开头单独安排。段落切换清弹且淡出弹无伤害，打空血条立即打断演出。补齐段落、事件、预警及淡出弹的存档；保留既定伤害数值。
- 技能分支继续延长被污染的魔法石技能：直射与旋转弹丸 7.5→10 秒、分裂子弹 5.7→7.6 秒、激光 3.7→5 秒、自机弹 3.9→5.2 秒；旋转弹幕连续发射 0.8→1 秒、自机弹连发 0.54→0.72 秒。单发伤害及激光每秒伤害不变，旋转弹幕完整发完后才启动下一轮；Boss 独立弹幕容量随留场时间增加至 5120。
- 独立分支 `feature/polluted-magic-stone-danmaku` 重构被污染的魔法石技能：环形直射和三种轮换旋转弹幕均为 80% 攻击力，分裂子弹为 50%，激光按接触时间结算 100% 攻击力/秒，原追踪链替换为发射后不转向的三路连续自机弹。增加波次、曲线、分裂伤害和激光接触存档；最终 Boss 使用独立固定弹幕容量，普通敌人保留原上限且不被 Boss 占用。扩大 Boss 弹幕复用池并避免整池复制，修复远处敌弹重复扣寿命。基础属性先行保存在 main，技能现已随上述后续改动一并合入；详见 `docs/design-reviews/2026-09-20-polluted-magic-stone-danmaku.md`。
- 最终 Boss 改名“被污染的魔法石”。N1 实际攻击 80、护甲 10、减伤率 10%、移速 30、总生命 45000、初始护盾 5000；护盾存在时护甲 25、减伤率 25%，破盾后恢复基础防御。该 Boss 去除旧生命/移动倍率，攻击以 N1 为基线保留高层成长；保留三阶段与原技能，补齐护盾存档。
- 第三轮性能优化聚焦玩家弹幕与渲染提交：同物理帧共享有序候选列表，只有几何相交目标才检查存活状态；场景切换和战斗清理同步失效缓存。批量弹幕改为整块上传 MultiMesh 数据，复用未变化外观及默认子弹材质；大型怪物遮挡排序由反复遍历改为共享排序阈值。保留原画质、动画、描边、弹幕数量、命中顺序与技能规则；新增查询等价测试及 Vulkan/OpenGL 逐像素渲染对照。
- 继续优化密集战斗：怪物体型缓存改为尺寸变化时失效，避让先用保守半径排除远处目标；敌方直线弹幕复用朝向计算、跳过未变化的透明度更新；Boss 连续受击复用闪光 Tween 与材质。保留怪物数量、伤害与技能密度；同一连续压力测试相对第一轮优化后平均逻辑步耗时由 29.257 ms 降到 16.721 ms，新增运行态与实机闪光渲染回归测试。
- 优化密集战斗：直接/排队伤害调用共享接口签名缓存，避免每次命中枚举方法；怪物避让复用同物理帧的邻居候选并缓存体型半径；击杀回能刷新改用轻量 HUD 数据；主存档和备份复用一次 JSON 序列化，保留原子写入与保存频率。新增热点与连续战斗基准及回归测试。
- 修复烈石减甲计时未进入敌人正常逐帧更新的问题，独立减甲状态也会在2秒后到期；重设敌人模板时清除残留减甲。

- 烈石改为普攻命中降低目标5点护甲，持续2秒，重复命中刷新、多份叠加减甲量；支持存档和对象池清理。地上的树枝改为攻击速度+5%、攻击力+2；残破胸甲减伤率改为+3%；冒险者破剑为攻击力+2、增伤+2%，同步商店文案。

- 焰阳调整为 I级攻击力+2、II级攻击力+5、III级攻击力+10且增伤+5%、IV级攻击力+15且增伤+10%；同步祝福卡片与详情文案。

Entries within each section are newest first. Earlier experiments remain recorded for history and may be superseded by a newer entry above them; they are not all simultaneous current behavior.

### Fixed
- 修复战斗中实际回血后，治疗飘字累计错误调用玩家对象的 `get()`，导致运行中断的问题；保留小数治疗累计与实际回复量显示。
- 统一玩家与敌人的受伤结算顺序：总伤害 → 护甲防御 → 减伤 → 扣血；易伤乘区暂不参与伤害结算，敌方的战吼减伤与玩家剑士近身减伤均在减伤阶段结算。
- 技能等级追加的弹道看不出效果：剑士普通攻击与月牙剑气在 2/4/6/8 级追加的斩击/剑气此前与第一道同帧、同方向、同位置发射，视觉上完全重叠，玩家看不到“多了一道”。现在改为依次发射（普通攻击每道间隔 0.15s，月牙剑气每道间隔 0.35s），方向与体积不变、伤害倍率不变。
- 审判之誓追加冲击波后巨剑提前消失：巨剑精灵的显示时长写死为基础 `SWORD_DURATION`（2s），追加冲击波把留场时间延长到「道数 × 2s」后，视觉仍在 2s 时消失。现在视觉时长跟随实际留场时间，并且留场时间在创建视觉之前就已结算。
- Infinite reload hotkey without its talent: the hotkey branch required the `无限装填 I` talent, so a manual-release infinite reload silently did nothing for players without that talent. It is now treated as a normal single-cast skill (hotkey casts it when set to manual), while talent builds keep the toggle on/off behavior.
- HUD switch widget in legacy layout never learned the actual team: `combat_skill_bar.update_team_role_statuses` returned early when `team_role_rows` was empty (legacy layout builds no team rows), so `set_switch_role_order` was never called and the switch portraits stayed on the hardcoded fallback trio swordsman/gunner/mage — with 机械师 on the team she never appeared in the switch widget and the top portrait fell back to index 1 until the layout was switched in the settings menu. Role-order extraction now runs before the rows check, so both layouts feed the real team order every frame.
- Level-up UI mechanic avatars: `TRAIT_HEAD_SCENES["level_trait_mechanic"]` and `LEVEL_TALENT_ROLE_SCENES["mechanic"]` in `scripts/level_up_ui.gd` pointed at the gunner's `gunhead.tscn` / `gunchange.tscn`, so mechanic trait cards and level-talent role entries showed the gunner portrait; they now use `mechanichead.tscn` / `mechanicchange.tscn`.

### Changed

- 地瑰灵模板改为攻击力 80、移速 0、护甲 -20、减伤率 0%、生命值 2800；刚毅身躯保持 150% 攻击力（基础 120）。普通射击、分裂弹、轰炸爆炸、轰炸弹丸均改为 100% 当前攻击力（基础 80），分身生成时继承本体攻击力作为每枚弹丸伤害；移除旧独立弹丸伤害配置及分裂/爆炸额外倍率，其他技能参数不变。
- 引渡人模板改为攻击力 30、移速 60、护甲 20、减伤率 10%、生命值 3800。巨型冲锋碰撞增加 150% 攻击力，与刚毅身躯合计 300%（基础 90）；衰老光环半径 750，每秒造成当前生命 12%＋最大生命 0.5% 的伤害，跳过护甲但计算减伤。死亡领域仅对三角形内玩家施加禁疗和 10% 减速，固定于施法开始时的位置，持续 7 秒并持续补齐近战冲锋怪，不再额外召唤 10 只远程骷髅；保留近战骷髅 5 秒双倍移速与免伤。首次致命伤后墓碑持续 5 秒，玩家减速 75%、三类远程骷髅攻击频率 +30%，随后满血复活一次，移除旧墓碑近战加速。同步衰老、领域文案及领域/墓碑存档恢复。
- 幽影树人模板改为攻击力 50、移速 20、护甲 30、减伤率 10%、生命值 2500；吞噬每秒检查，每次完整成长增加 2 移速与 0.005 缩放，额外移速上限 120。战争践踏改为原地施法 3 秒、持续 6 秒、结束后冷却 16 秒，移速加成 10%、额外减伤 10%，每秒造成 80% 攻击力伤害；缠绕每秒造成 20% 攻击力伤害，补齐进入残留区域后的持续伤害；木刺造成 80% 攻击力伤害。技能不再读取旧碰撞伤害；践踏额外减伤与基础减伤相乘，合计减伤 19%。
- 精英分裂骷髅模板改为攻击力 50、移速 40、护甲 10、减伤率 0%、生命值 600；刚毅身躯基础伤害 75。分裂射击改为主弹造成发射时攻击力 100%（基础 50）、分裂弹造成该攻击力 60%（基础 30），不再叠乘旧全局弹丸伤害倍率；其余射击、分裂与弹速参数保持不变。
- 精英冲锋骷髅模板改为攻击力 30、移速 100、护甲 10、减伤率 0%、生命值 100；「精英冲锋」与普通冲锋共用实际速度 250、最大距离 500、前摇 0.6 秒、结束后冷却 10 秒以及 100%＋刚毅身躯 150% 的碰撞伤害。原红色地面区域长宽各扩大 2 倍、持续 3 秒，进入时及其后每秒造成玩家当前最大生命值 1% 的伤害，在区域内减速 30%，离开立即解除；区域独立更新，施法者死亡后仍会正常消失。开始冲锋时使全场存活普通冲锋怪移动速度 +10%、持续 3 秒，重复触发刷新、不叠加，剩余加速时间支持战斗存档。
- 散弹骷髅模板改为攻击力 25、移速 60、护甲 5、减伤率 0%、生命值 80。保留刚毅身躯，新增与远程骷髅同款的独立普通射击（100% 攻击力、基准间隔 6.5 秒、弹速 132、存在 4.2 秒）；散弹每 15 秒发射 5 枚，每枚造成 200% 攻击力伤害、基准实际弹速 200，保留相邻间隔 0.22 弧度与 4.6 秒存在时间。两种攻击分别计时并支持存档，均不重复套用旧全局弹丸伤害倍率。
- 冲锋怪模板改为攻击力 20、移速 80、护甲 10、减伤率 0%、生命值 60。冲锋期间碰撞造成额外 100% 攻击力＋刚毅身躯 150%（基础合计 50），共用 1 秒碰撞冷却；冲锋实际速度固定 250、最大距离 500、持续最多 2 秒，保留 0.6 秒前摇，结束后冷却 10 秒，首次生成 10 秒后进入前摇。冲锋距离与剩余时间可存档恢复，预警长度同步为 500；精英冲锋逻辑保持原值。
- 重甲南瓜模板改为攻击力 15、移速 60、护甲 20、减伤率 0%、生命值 60。新增「重甲形态」：生成 20 秒后首次释放，此后释放起计冷却 20 秒，持续 3 秒；基础移速降至 30、额外护甲 +20，全身银色，向玩家反弹实际扣除生命值的 5%（反伤仍走玩家受伤结算）；形态与冷却支持存档恢复，对象池回收时清理。
- 远程骷髅模板调整为攻击力 25、移速 50、护甲 -10、减伤率 0%、生命值 20；刚毅身躯造成 150% 攻击力伤害、独立冷却 1 秒；远程射击改为发射时读取当前攻击力的 100%，不再使用独立弹丸伤害及旧全局弹丸伤害倍率，其他射击参数不变。
- 飞眼群模板调整为攻击力 10、护甲 -10、移速 200、减伤率 0%、生命值 20；新增「啄眼」：实际造成伤害后施加 1.5 秒目盲，世界视野限制为玩家周围半径 160，范围外全黑、HUD 保留；玩家共享 10 秒触发冷却，效果不叠加、不刷新，状态与冷却随存档恢复。
- 疾行史莱姆模板调整为攻击力 20、护甲 -5、移速 150、减伤率 0%、生命值 20；刚毅身躯基础碰撞伤害为 30，独立冷却 1 秒。
- 追击菇模板调整为攻击力 15、护甲 5、移速 60、减伤率 0%、生命值 30；刚毅身躯按攻击力 150% 造成碰撞伤害，独立冷却 1 秒。
- 角色面板核心属性统一为指定的 11 项，补充暴击率、暴击伤害、增伤，冷却倍率改为冷却缩减百分比，生命回复纳入神恩平均每秒回复；仅调整面板展示。
- 删除旧精英遗物 `elite_last_stand` 的识别入口及全部低血效果（22% 增伤、18% 移速、18% 等效减伤），清理专用状态判断接口。
- 删除已失效的「梅塔领域提供的减伤值 +15」旧升级定义、专用数值接口及其升级投影说明；梅塔领域现有护甲效果保持不变。
- 魔眼聚合基础效果改为每次命中后降低敌人 5 点护甲，每升一级额外降低 0.75 点护甲，可累计；同步技能说明与升级预览，未启用的角色天赋选项保持原有数值。
- 法师技能线升级效果接入：奥数充能每级 +2% 击杀叠加概率与 +0.3% 每层大招回能效率；奥法盈余（挂在「密集雷群」登场技线上）每级 +1.5% 大招回能、切人回能与伤害，只作用于当前站场角色；普通攻击每级 +10% 雷击范围（相对乘法）与 +10% 伤害倍率（绝对加法），2/4/6/8/10 级各追加一道落在随机敌人密集处的雷击；梅塔领域每级 +10 减伤值与 +7.5 半径；波涛汹涌每级 +10% 伤害倍率与 +0.2s 持续时间；火球术每级 +20% 伤害倍率与 +0.5% 灼烧倍率，3/6/9 级灼烧地面持续时间各 +1s；黑暗契约每级 +2.5 球体速度、+15 最大移动距离、+7.5 吸引半径与 +10% 碰撞/爆炸伤害；火焰之径每级 +2.5% 路径每秒伤害与 +0.5% 法师移速倍率。
- 枪手技能线升级效果接入，并且枪手特性拆成两条独立技能线：`gunner_trait` 改名为「瞬杀」，新增「猎杀」`gunner_hunt`，两者各有独立的升级卡与天赋位。瞬杀每级每层 +0.5% 增伤、+0.5% 移速、+2 闪避值，2/4/6/8/10 级瞬杀最大层数 +1（基础 10 层，满级 15 层）；猎杀每级猎杀圈半径 -5、圈外伤害 +1%（绝对加法）；枪火典礼每级每颗子弹伤害 +10%、弹道速度 +10；枪手普攻每级 +15 射程、+10 弹道速度，3/6/9 级各获得一枚伤害与主弹相同的分裂弹（方向交替 +20°/-20°/+40°）；无限装填每级 +20 射程、+1% 每跳倍率、+0.5% 移速倍率；散弹每级 +2% 每跳伤害，3/6/9 级各多一个散弹圈；爆破弹每级命中与扇形伤害 +10%、扇形半径 +7.5，3/6/9 级各多发射一枚（间隔 0.2 秒、方向与主弹一致，全部发射完毕后才进入冷却）；魔法榴弹每级 +10% 伤害、+5% 额外暴击率，2/4/6/8 级各多一枚且同时发射；魔眼聚合每级 +2% 每次伤害、+2.5 击中减伤值。爆破弹存档新增 `pending_shots`/`shot_timer`，旧的 `second_shot_remaining` 读档时自动转入待发队列。
- 剑士技能线升级效果接入，统一由新模块 `player_skill_level_effect_flow.gd` 读取（加成按 `等级 - 1` 线性累加）：战意每级 +0.5% 触发概率与 +0.5% 最大生命/已损失生命回复，骑士荣耀每级 +0.2s 濒死无敌；普通攻击每级 +10% 伤害倍率（绝对加法，基础 150% 起）与 +10% 范围（相对乘法），2/4/6/8 级各追加一道同方向、60% 伤害的斩击；月牙剑气每级 +15% 伤害倍率与 +10 飞行速度，2/4/6/8 级各追加一道同方向、75% 伤害的剑气且体积不变；剑刃风暴每级 +2% 每跳倍率与 +7.5 半径；冲锋每级 +10% 伤害倍率与 +20 可指定距离；骑士突每级 +5% 伤害倍率与 +1 临时血量，3/6/9 级各追加一道间隔 0.5s、60% 伤害的连击突刺，本次技能所有突刺共享命中登记，只有尚未被命中过的敌人才提供临时血量，命中时触发画面震动；审判之誓每级 +50% 巨剑伤害与 +10% 冲击波倍率，3/6/9 级各追加一道冲击波，巨剑留场时间随之延长到「道数 × 2s」，最后一道在巨剑消失时释放；王者之剑每级 +10% 伤害倍率与 +10% 范围。升级卡会显示该技能下一级的具体收益，满了 10 级或技能未解锁时不显示。
- 技能等级系统取代角色属性构筑卡：每条技能线现在有 1~10 级，角色槽卡池改为「未解锁技能的获得技能卡 60% + 已解锁技能的技能升级卡 40%」，旧的属性强化卡（普攻伤害、技能冷却、角色特性数值等）不再出现在升级卡牌中。升级卡写明某技能等级 +1（如「无限装填等级+1」），应用后该技能等级 +1；满 10 级后该技能不再进入升级卡池。升级池包含角色特性、登场技、普通攻击和所有已解锁技能，大招不参与，未解锁的主动技能必须先通过获得技能卡解锁。技能达到 5 级时弹出该技能的天赋二选一（当前两个天赋位为占位条目，具体效果待设计），达到 10 级时自动获得另一个天赋位。玩家等级 3 倍数的等级天赋入口停用：`pending_level_talent_choices` 不再累积，`LEVEL_TALENT_DEFINITIONS` 及其 `has_level_talent()` 运行时读取代码全部保留，等待后续重新设计；旧属性卡定义与数值 getter 同样保留，只是不再发牌。角色面板技能页改为显示「技能 Lv.x / 10」与两个天赋位的状态。技能等级与天赋位写入 `role_special_states[role_id].skill_levels` / `.skill_talent_slots`，随运行档保存与恢复。
- 无限装填默认伤害跳频由每 0.1s 一跳改为每 0.25s 一跳（基础单跳倍率 50% 攻击力不变）。
- Ruan Dog shop carry rules reworked: every item still costs a flat 5 bones, but the **carry limit now equals the profile's highest unlocked N** (N1 → 1 item, N2 → 2, …), purchases take effect immediately (no separate equip step), and the **same item can be bought repeatedly with purely additive stacking** (e.g. two Adventurer Broken Swords = +4 attack / +10% damage; two Thunder Stones = 60% chain damage with 2 chain targets). Buying a carried item's button again now cancels one purchase and refunds its 5 bones (repeated until the item reaches 0; the "carry limit reached" state only disables purchases of items you are not carrying). Duplicate purchases are stored in the carried list, proc stones aggregate by count and trigger once per damage event, and the no-longer-meaningful level/upgrade cost formula was removed. Shop status, HUD status and the character-panel slot now show carried count/limit plus an item summary.
- Skill hotkeys are now a first-class system: the basic-attack slot is visually separated from the skill slots, each active skill slot shows its hotkey (gold when the skill is set to manual release), and the hotkeys are rebindable actions (`skill_slot_1`–`skill_slot_6`) in the settings keybind page. Every active skill has an auto/manual release state (auto by default): auto skills cast on their own and ignore hotkeys, while manual skills stop auto-casting and cast when their hotkey is pressed. Toggle a skill's state with `Ctrl` + its hotkey, or by right-clicking its slot in the combat skill bar. Auto-release slots show a clockwise sweeping border glow. Left-dragging a skill slot onto another slot of the same role swaps the two skills (drag ghost follows the cursor, then a flight/ pulse swap animation plays); the resulting slot order is stored per role in the global settings and hotkeys follow the new order. Both the release state and the slot order live in the global settings file (shared by all saves, like BGM), not in run saves. The previous "hotkeys only work for talent-enabled infinite reload" rule is replaced by this general system.
- 审判之誓默认效果重做：巨剑落地（范围100/200%伤害）后留场2s，2s后只释放一道全图冲击波（100%伤害/削20减伤值），不再每2s循环；天赋I/II的"冲击波间隔-1s"改为"冲击波提前1s释放"（即1s后放冲击波）。
- 新增法师天赋：火球术 I/II（爆炸半径+75+伤害+150% / 第一次爆炸外圈8方向各炸一个200%伤害半径50的小爆炸）。
- 新增法师天赋：火焰之径 I/II（灼烧减敌减伤20点 / 移速+30%+击杀1.5倍回能）、黑暗契约 I/II（吸引半径150+移动/吸引速度+50+距离+200 / 终点暂留3秒持续吸引伤害后爆炸）。
- 爱心掉落与回血量调整: 普通小怪 0.6%→0.1%, 精英 1.2%→0.5%, 小BOSS/大BOSS 100%必掉, 每颗回血 25→50.
- 地瑰灵 (smallboss_turret): base projectile speed 320→352 (+10%), projectile damage 15→16.5 (+10%, all derived attacks scale automatically), bombard warning 1.9s→1.5s.
- Mechanic weapons swapped: the inherited wizard wand/orb are flood-erased from the amber seed color family per frame and replaced by an open-end wrench (left hand) and a pistol-grip electric drill (right hand); frames where detection fails get the tools redrawn at the glasses-lens anchor plus the median offset, and detached amber sparkles are purged. The round glasses keep the previous iris-anchored version (a face-bbox redraw pass caused visible jitter and was reverted).
- Mechanic sprite refined further toward Maria Custard via `scripts/tools/refine_mechanic_maria.py`: hair family shifted from deep navy toward Maria's brighter blue (+Δ(14,48,58) on the navy cluster family, sheets and both facility portraits) and her iconic red necktie painted at the collar of the lab coat on all idle/run frames (anchored to the stable glasses-lens pixels).
- 机械蜘蛛 tuning: crawl speed 300→100 (one third) and visual scale ×1.8, so the spider reads as a crawling machine instead of a fast bullet; damage, range and hit radius unchanged.
- Turret art replaced: the old flat-blob `tulip_turret` frames (which were also shared by the heavy cannon and the field tower) are replaced by purpose-drawn mechanical pixel art generated via `scripts/tools/gen_mechanic_turrets.py` (PIL, drawn at 64×64 and NEAREST-upscaled to the existing 256×256 canvases): 定点机炮 keeps `effects/mechanic/tulip_turret/` (armored dome + single barrel on tripod, muzzle-flash frame), 重型炮台 gets its own `effects/mechanic/heavy_cannon/` (treaded siege hull with hazard stripes and twin barrels) and 力场塔 gets `effects/mechanic/field_tower/` (coil pylon with a pulsing orb, 3-frame loop). The heavy cannon's blue modulate tint is softened (0.6,0.72,1.0 → 0.85,0.9,1.0) so the new amber accents stay visible.
- 磁滞力场 `emp_burst` reworked from a player-following field into a stationary field tower: casts deploy a small tower at the current position (dedicated `field_tower` frames, cyan tint, scale 0.33) projecting a radius-450 field (3× the previous diameter) for 10s, rendered as expanding concentric ripple rings via a new procedural `FieldRippleVisual` (Node2D `_draw` arcs) instead of the old 6-frame flipbook. Enemies inside take 30% damage per 0.5s and are slowed 40%; the self buffs (+30% move speed, 1.5% max-health per 0.5s) now apply only while the on-field role stays inside the field radius. Save data gains `field_position`.
- 机械蜘蛛 (mechanic basic attack) now deals damage under a `mechanic_basic:` source id (`player._create_basic_attack_source_id("mechanic")`), so spider hits proc the equipped 阮石 (thunder/frost/poison/flame/fury) exactly like the other three roles' direct basic attacks; the off-field background spider keeps the plain `mechanic` source and does not proc stones.
- 重型炮台 `missile_volley` visuals scaled up to read clearly above the定点机炮: cannon scale 0.42→0.8 with offset (0,-104) and a stronger blue tint, deploy offset 48→64, big-bullet hit radius 18→24 and visual scale 2.4→3.6.
- Mechanic kit rework (skill ids unchanged, saves stay compatible): basic attack 铆钉枪 is replaced by 机械蜘蛛 — a homing mechanical spider projectile (new `effects/mechanic/spider/` 4-frame set, rendered via bullet.gd's new `custom_sprite_frames` hook) that chases its target and is destroyed on hit; the previously dead `basic_attack_range` build card now applies to the spider's acquisition range. The five active skills are now: 定点机炮 `tulip_turret` (stationary 8s turret, renamed from 郁金香炮塔), 感应地雷 `mine` (unchanged behavior), 磁滞力场 `emp_burst` (reworked from a one-shot EMP into a 5s player-following field: enemies inside take 30% damage per 0.5s and are slowed 40%, while the field grants +30% move speed and 1.5% max-health per 0.5s to the on-field role), 守卫机器人 `drone` (reworked from the orbiting gun drone into an untimed follower that blocks 3 incoming hits — hooked into `player_survival_flow.take_damage` — with at most 5 active at once, spawning past the cap destroying the oldest; each bot is destroyed only when its charges run out), and 重型炮台 `missile_volley` (reworked from the missile barrage into a stationary 10s heavy cannon firing big bullets every 1.2s at 200% damage). All mechanic summons persist across role switches and only end on their own condition (duration/charges). The ten mechanic skill build cards (drone/mine/emp/turret/missile pairs) previously had no runtime consumers and are now wired: guard block count +1 / guard active cap +1, mine damage +15% / mine count +1, field damage +25% / field cooldown −2s, turret damage +20% / turret duration +1s, cannon damage +20% / cannon duration +2s. Mechanic level-talent texts updated to match (机械蜘蛛 I/II, 守卫机器人 I 抵挡+2 / II 上限+2, 定点机炮 I/II); HUD skill-slot order is now turret → mine → field → guard bot → heavy cannon.
- Roster/team architecture: `role_database.gd` `ROLE_IDS` now lists four roles (swordsman/gunner/mage/mechanic) alongside a new `DEFAULT_TEAM_IDS` (swordsman/gunner/mage). Combat teams stay fixed at exactly three roles, driven by the save's `team_order` field — both story profiles and the endless `endless_profile` persist it, and legacy saves normalize to the default team automatically. Four-card/select-two level-up offers, level-talent role entries, and the three-row HUD status band are unchanged in shape but now derive their role lists from the current team; mechanic level talents appear only while she is on the team. Formal level talents grow from 56 options in 28 mutually exclusive groups to 70 options in 35 groups (swordsman 11, gunner 10, mage 7, mechanic 7).
- Endless difficulty projectile speed bonus per tier reduced from 50 to 20.
- Swordsman 骑士突 (knight_thrust) base temporary health per enemy hit raised from 5 to 10 (5s duration unchanged); 骑士突 I bonus per enemy hit raised from +5 to +10 (20 total with the talent), both combo strikes grant temporary health normally; 骑士突 II damage bonus raised from +50% to +80% (160%→240% linear) and now heals the swordsman for 10% of missing health on each cast that hits at least one enemy (heal triggers only once per cast, including when 骑士突 I is also selected).
- Gunner base attack range increased by 75 (350→425).
- Swordsman 审判之誓 II shockwave heal raised from 1.5% to 30% of the on-field role's missing health per shockwave (the -1s shockwave interval and +80 damage-reduction value while the sword is planted are unchanged).
- Endless difficulty tiers now scale player experience gain: N1 = 100%, N2 = +10%, N3 = +20%, N4 = +30%, N5 = +40% (tiers above N5 are capped at N5; story difficulties easy/normal/hard/hell remain at 100%). Implemented via `main._get_difficulty_experience_multiplier()` applied inside the player experience pipeline.
- Gunner 魔法榴弹 (magic_grenade) gains a level-talent variant pair (`gunner_level_talent_magic_grenade_1` / `_2`, group `gunner_magic_grenade_variant`, requires the skill unlocked): I adds +75 blast radius (75→150), +100% linear damage per grenade (300%→400%), and +20% extra crit chance (20%→40% total; the crit-chance getter now receives the owner so the talent is readable in both damage-resolution paths); II adds +1 grenade (3→4) and −2s cooldown (16s→14s, cooldown-slot duration follows the talent).
- Gunner 魔眼聚合 (magic_eye) gains a level-talent variant pair (`gunner_level_talent_magic_eye_1` / `_2`, group `gunner_magic_eye_variant`, requires the skill unlocked): I adds +50% linear damage per pulse (80%→130%) and +1.2s duration (7 pulses over 2.8s instead of 5 over 1.6s, first pulse delayed to 0.4s when the talent is held); II adds +30 armor shred per hit (30→60). Cooldown-slot descriptions are synchronized to match.
- Gunner 爆破弹 (explosive_round) gains a level-talent variant pair (`gunner_level_talent_explosive_round_1` / `_2`, group `gunner_explosive_round_variant`, requires the skill unlocked): I raises the impact damage by +50% linear (280%→330%) and turns it into a radius-100 area hit, raises the cone blast damage by +50% linear (160%→210%) and its radius by +100 (375→475), and makes enemies killed by the explosive round explode for 150% damage in a radius-75 blast — kill blasts use a separate damage-source prefix (`gunner_explosive_round_killblast:`) so they do not chain, and are queued for the next frame to avoid damage-resolution re-entry; II fires a second projectile 0.8s after the first. Damage sources now use a dedicated `gunner_explosive_round:` prefix registered in both damage-resolution paths (direct + batched), and the cooldown-slot description is synchronized to match.
- Gunner 火箭弹幕 I/II level talents are now linear like the other "+X% damage" talents: the per-wave ±10% is applied directly to the damage ratio (±0.10 on the ultimate base ratio) instead of multiplying the whole cast multiplier by ×1.10 / ×0.90; gunner skill-talent smoke expectations were corrected to the real linear values (e.g. shrapnel II 4.5 = 10 × (0.40 + 0.05)).
- Swordsman 审判之誓 now has a level-talent variant pair (swordsman_level_talent_judgement_sword_1/_2, group `swordsman_judgement_sword_variant`, requires the skill unlocked): I adds +100% linear impact damage (200%→300%), cuts the shockwave interval by 1s, adds +50% linear shockwave damage, and adds +10 armor shred per shocked enemy; II cuts the shockwave interval by 1s, heals the current on-field role for 1.5% of missing health per shockwave, and grants the swordsman +80 damage-reduction value while the sword is planted (queried in the role stat pipeline, so it persists across role switches and resumes on load). All percentage bonuses are additive (linear), not multiplicative.
- Knight Thrust's temporary-health grant is reduced: it no longer grants a base 80% of the swordsman's max health on hit; it now grants only 5 temporary health per enemy hit (5s duration), and the skill description is synchronized to match.
- Three new active skills, one per role, all fully wired into unlock build cards, cooldown skill bars, developer panel, run save, and character-panel progress:
  - Swordsman 审判之誓 (`judgement_sword`): a giant sword falls at the mouse-pointed location (aim range up to 400), dealing 200% damage on impact and staying planted for 8s (survives role switches); every 2s it releases a full-map shockwave dealing 100% damage to all live enemies and reducing each damaged enemy's damage-reduction value by 20 (stacks). Cooldown 18s starts only after the sword expires.
  - Gunner 魔眼聚合 (`magic_eye`): a sustained blue cannon beam deals 5 × 80% damage (0.4s apart) in front of the gunner; every hit reduces the target's damage-reduction value by 30 (stacks per hit, up to 5). Cooldown 16s starts only after all 5 shots land.
  - Mage 火球术 (`fireball`): a fireball explodes at the mouse-pointed location (aim range up to 450) for 600% damage in a 200-radius blast, leaving burning ground for 5s that burns standing enemies for 2% of their max health per second (direct max-health-ratio damage, bypassing the player damage pipeline). Cooldown 28s.
- Mage gains a new active skill 黑暗契约 (`dark_contract`): 24s cooldown, throws a dark orb forward at 50 speed for up to 600 distance, pulls nearby non-boss enemies (100 radius, 200 speed) while dealing 30% damage three times per second, deals 300% damage on contact, then 300% blast damage on a 75-radius explosion. Fully wired into the unlock build card, cooldown skill bar, developer panel, run save, and character-panel progress.
- Gunner gains a new active skill 魔法榴弹 (`magic_grenade`): 16s cooldown, launches 3 magic grenades that arc toward random dense enemy clusters in front of the gunner and explode only at their landing points (no mid-flight collision), each dealing 300% damage in a 75-radius blast with a larger camera shake than basic attacks; magic-grenade hits gain an extra +20% critical chance on top of the gunner's current critical chance (new per-source critical-bonus channel, default 0 for all other sources). Fully wired into the unlock build card, cooldown skill bar, developer panel, run save, and character-panel progress.
- Swordsman gains a new active skill 王者之剑 (`king_blade`): 24s cooldown, auto-slash at a random dense enemy cluster within 350 range dealing 600% damage, and each kill permanently (for the run, persisted with the run save) raises the swordsman's base attack by 0.01. Fully wired into the unlock build card, cooldown skill bar, developer panel, run save, and character-panel progress; the flame-path `UNLOCKABLE_PROGRESS` entry is restored and the developer cooldown-clear map now covers all current active skills.
- Knight Thrust (`骑士突`) damage ratio raised from 80% to 160% of the swordsman's damage, with its skill description synchronized.
- Restored the full project-check gate by synchronizing two enemy smoke doubles with current runtime fields and removing smoke assertions that exercised only the retired 108-node skill-talent path.
- Audited the current build at `323c687` and corrected the live documentation boundary: formal rewards expose seven general blessings and direct role-build skill unlocks; legacy blessing-recipe materials are not generated by the formal reward chain. Endless now consistently treats `12:00` as final-Boss arrival, with settlement occurring only after the Boss is defeated. Added the evidence-based current-build baseline review under `docs/design-reviews/`.
- Synchronized the repository documentation with the current formal progression: ordinary four-card/select-two rewards are followed by one player-level talent choice at every multiple of three, using three role entries, up to three role-specific candidates, per-card refresh, skill prerequisites, 42 active definitions, and 21 mutually exclusive groups. The former 18-tree/108-node Lv.3/Lv.6/Lv.9 player path is now explicitly historical: its definitions and compatibility tooling remain, but formal offer/apply/query/save paths are disabled and legacy `skill_talents` are cleared.
- Updated current controls, switch-energy ownership, disabled exit-skill boundary, character-panel contents, endless final-Boss settlement, 1280×720 baseline, BGM-only audio scope, canonical documentation labels, roadmap, known issues, and release checks; historical three-stage design documents now carry non-current status and reactivation gates.
- Raised the three-role survivability baseline to 150 / 120 / 120 health, eased Gunner's base damage-reduction penalty from -80 to -40, strengthened Divine Grace to 15% / 20% / 25% / 30% maximum health with improved regeneration, raised Unyielding to 10 / 18 / 26 / 34 reduction value, and increased every one of the 45 repeatable role-build upgrades while preserving linear stacking, stable IDs, talent inheritance, and cooldown floors. Legacy run saves now adopt the current authored base health and damage-reduction values instead of restoring stale snapshots.
- Strengthened `贪婪`: up to four hits per attack event now each roll a fixed 10% proc chance, each tier heals a stable 1% / 2% / 4% / 6% of maximum health instead of becoming weaker as health falls, and its proc cooldown is now 0.2 seconds.
- Added an endless-battle-only `1×/2×` speed toggle beneath the bone/Ruan-stone HUD. It accelerates the complete combat simulation and always resets to `1×` on death, restart, or scene exit.
- Fixed HUD-layout controls overflowing the main settings and pause panels at the 1280×720 baseline, with scrolling retained for smaller windows. The alternate three-row combat HUD now reuses the three authored role portraits and shows the existing circular switch-energy/cooldown progress instead of generic silhouette emblems.
- Flame Stone now triggers when a direct basic attack kills an enemy, exploding for 8% of the dead enemy's maximum health in a 260-unit radius; each further level adds 0.5 percentage points, and explosion kills do not recursively trigger more explosions.
- Split the endless camp exits: the blue endless portal now starts or resumes combat directly, while a separate gold tutorial entrance opens the movement-tutorial confirmation and cancelling stays in camp.
- Replaced the four endless difficulty choices and post-Boss cycle scaling with an unlocked N1→N∞ ladder. Every N tier is a fresh Lv.1, 12-minute run: N1 matches the former easy anchor, N11 the former hell anchor, health/damage continue linearly beyond N11, and speed/density/attack/projectile/performance axes cap there. The final Boss now settles 8 bones plus a first-clear `5 + 3N` bonus, unlocks N+1, clears the run, and returns to camp without an ephemeral skill reward. Profiles store highest/selected tier and idempotent reward IDs; run saves store `run_tier/run_id`; incompatible legacy runs are archived. Save cards, camp selector, HUD, N3 achievement, and non-persistent Developer Mode N testing are synchronized.
- Added the first endless-mode meta loop: normal enemies have a 1% bone drop, elites drop 1, and small Bosses 3; the final Boss reward is credited directly by N-tier settlement. Collected bones persist immediately while uncollected pickups survive continue-save restoration. Ruan Dog now opens a five-card collection panel for permanent, uncapped thunder/frost/poison/flame/fury stone upgrades with linear `5 + 3L` costs and one shared active stone. Direct basic attacks carry authored event IDs so thunder chains once per event, Flame Stone explodes once per direct-basic kill, target statuses deduplicate per enemy, and secondary stone damage cannot recursively trigger combat talents. HUD, character panel, legacy endless-profile migration, and non-persistent developer controls are synchronized.
- Implemented all 18 fixed three-stage skill-talent trees for swordsman, gunner, and mage: 108 stable nodes unlock from the owning skill build at Lv.3/Lv.6/Lv.9, keep ordered stage IDs, and derive `111`—`222` paths without creating path-specific skill pools.
- Gunner authored attacks now carry stable damage-event IDs across piercing hits and delayed triple-shot bullets: execution is consumed only by the first real hit, applies one locked multiplier to the whole event, and empty attacks consume nothing; entry repulse is likewise bound to the first real projectile collision.
- Skill displays now evolve after every selected stage: full names append selected node names, compact HUD labels use the latest node’s first two characters, and character-panel trees expose each stage’s unlock, pending, selected, and unselected state. Ordinary build IDs remain stable; 270 exact talent/build mappings describe how every selected node inherits—or deliberately does not inherit—each later ordinary upgrade without guessing from free-form text.
- Skill-talent saves now normalize legacy single-string selections into stage-I arrays, preserve active talent-choice context, and reject invalid, duplicate, or gapped stage selections. Developer mode can grant or replace a stage, clear a stage and its successors, or construct a complete `111`—`222` path while raising the required skill build level.
- Active-skill saves now store six cast-talent snapshots in `ability_runtime` with compatibility for legacy flat keys: blade storm, infinite reload, and meta field restore their counters and active instance state; crescent projectiles and shrapnel fields are rebuilt from serialized state. Existing generic player bullets and queued scheduler callbacks are intentionally not persisted, so in-flight tidal waves and unexecuted delayed callbacks are lost after loading.

- Removed character-panel interaction stalls by keeping role cards, skill selectors, talent-tree controls, and blessing rows alive and updating them in place; the local 1280×720 headless probe reduced synchronous skill-hover handling from roughly 486ms to 4ms on average, panel opening from roughly 453ms to 18ms, and role preview switching from roughly 445ms to 19ms.
- Rebuilt the character panel's skill-build tab as a six-skill selector plus one focused three-stage left/right talent tree: current single-tier choices show `1--` / `2--`, unavailable future stages stay explicitly locked, and repeatable build stacks plus post-mutation upgrade behavior remain separate below the tree; the blessing ledger remains grouped by team-shared role blessings and skill-type effects.
- Documented the 2026-07-29 meeting goals and the confirmed but unimplemented three-tier fixed binary skill-talent direction, including `221` path semantics, the current single-tier gap, migration/UI/testing boundaries, deferred ideas, and a prioritized roadmap; corrected current documentation to note that periodic background attacks are globally disabled and legacy final-core applicators are not offered by the current final-Boss menu.
- Skill talents now rename their live skill, ultimate, character-panel, and upgrade-card displays to `base skill·talent`; subsequent build cards keep stable IDs while explaining and applying their bonuses to the transformed form. Swordsman trait builds now also extend Blood Battle duration and improve Last Guard rescue health/invulnerability.
- Removed the retired `I x3 -> II x1` blessing composition flow from the blessing system and character panel.
- Fixed leaving the movement-tutorial role introduction so input is marked handled before the scene switch, avoiding a null viewport script error.
- Endless camp now includes the CC0 pixel-art NPC `阮狗`: standing in front of it shows the configured interact key, opens a three-line portrait dialogue, pauses camp movement, advances with interact, and closes with `Esc`.
- GitHub project checks now install a checksum-pinned Godot 4.6.2 binary instead of silently skipping engine validation; project checks import assets before parse and launch both the real main-menu entry and battle scene.
- Cleaned smoke-test fixture ownership so the Godot test process exits without the previously reported test-only CanvasItem/ObjectDB leaks.
- Documentation now matches the upstream four-card, select-two level-up flow: one card per role slot plus one general blessing, with per-card refresh.
- Removed unreachable progression entry points for the retired opening-trait choice, unused build-choice level schedule, and unused mixed blessing picker; existing skill-unlock/build rules remain upstream-owned.
- Local project checks now discover and run every ordinary `*_smoke.gd` test automatically; the timed dense-combat benchmark remains a separate evidence check.
- Enemy profile verification now locks stable archetype/behavior/visual identities instead of duplicating tunable balance values, and the glutton/spawn smokes track the current war-stomp and late-enemy-limit ramp contracts.
- Dense-combat evidence now exercises real projectile hits and gates projectile damage, hit count, pickup value, entity counts, and duplicate ticks across baseline/candidate runs; unused experimental performance flags were removed.
- Combat HUD layout is now selectable in settings: the legacy centered bottom skill bar is the default, while the newer three-row team status stack remains available as an alternate HUD layout and can be switched from the pause menu.
- The alternate combat HUD uses a three-row team status stack anchored bottom-left: `Q` previous role, highlighted current role, and `E` next role each keep six fixed skill slots, HP, MP / ultimate energy, and hover details while preserving empty slots for locked skills.
- Character panel now uses a dark-gold build-archive layout inspired by the selected design reference, with a left role stack, existing player pixel run sprites as role portraits, ornamental frames, central role stats/equipment, right blessing list, and skill recipe details while preserving equipment gifting.
- Swordsman trait healing now triggers on attack hits instead of kills: base 5% proc chance plus 5% per trait level, each proc heals 5% of max health plus 7.5% of missing health, and the effect has its own 1-second trigger cooldown.
- `贪婪` now triggers on attack hits instead of kills, heals 1% of the attacker's max health on proc, uses tier-based proc chances of 1% / 5% / 10% / 20%, and has its own 1-second trigger cooldown.
- Mage `奥法盈余` now grants the caster 3 stacks of `奥数充能` when the 5-second surplus window expires naturally.

- Swordsman entry state now displays as `嗜血` instead of a generic `无敌`, shows a blue `嗜` buff icon in the combat buff bar, and shares entry lifesteal healing to the other two roles during its 3-second window.
- Reduced post-switch invulnerability from 0.2s to 0.1s to tighten role-swap safety windows.
- Cleaned Mac/archive metadata from imported asset folders and ignored future `.DS_Store`, `__MACOSX/`, and `._*` files.
- Normalized script encodings by removing UTF-8 BOM from local code/check scripts.
- Project display config now explicitly keeps resizable 16:9 `canvas_items + keep` settings required by project checks.
- Local project checks now include level-up scroll reopen, player targeting, player damage resolver, runtime registry, and player projectile pool smoke tests.
- Fixed consecutive reward/level-up panels so the second skill list keeps a valid scrollbar range.
- Runtime enemy, enemy projectile, projectile-pool, and pickup registries now use instance-id dictionaries behind the existing Array-returning API to avoid linear duplicate/removal scans in dense combat.
- Player projectile counts now use the runtime registry in performance checks/monitoring, and player bullet nodes can be recycled through a keyed runtime pool instead of always instantiating/freeing.
- Dense-combat CPU optimizations now throttle repeated HUD stat rebuilds, centralize global enemy feedback updates, reuse shared enemy sprite-frame resources, and keep visual feedback pools guarded without changing enemy counts, projectile counts, or damage rules.
- Dense-combat follow-up optimizations now cache reusable geometry/projectile visual data, pool turret bombard warning nodes, and remove duplicate vector math in enemy movement, separation, projectile, and damage checks without changing combat rules.
- Dense-combat enemy simulation now batch-updates simple normal chasers from the main scene and disables their per-node physics callbacks, preserving the same movement/damage rules while reducing late-wave scheduler overhead.
- Enemy projectile and pickup ticking now run through scene-level batch simulation where possible, keeping projectile motion, hit, attraction, despawn, and recycle rules unchanged while removing more high-density per-node physics callbacks.
- Dense-combat optimization now has an evidence-first benchmark/evaluator gate with frame-time p95/p99/max, gameplay-equivalence counters, CPU/core artifacts, and feature-flagged batch simulation wiring.
- Developer performance metrics now include rolling frame-time percentiles and the active performance feature-flag snapshot for dense-combat comparisons.
- Refactor verification docs now use the local Linux Godot CLI command paths instead of stale Windows examples.
- Combat HUD presentation now refreshes cooldown/energy/time/minimap feedback at 30 FPS, and project display settings explicitly avoid the 60 FPS render cap by disabling VSync with a 120 FPS project cap.
- Large telegraphed enemy waves now drain their spawn queue over smaller frame-budgeted chunks, reducing new-enemy instantiation spikes while preserving total wave size.
- Runtime performance metrics now include automatic-save peak timing/payload counters; automatic combat saves now run as a fixed background save about every 2 seconds and no longer expose a main-menu or pause-menu toggle.
- Enemy, enemy-projectile, and pickup batch simulation flags are now enabled by default, with the developer performance panel showing batch flag state and batch tick peaks.
- Added a default-off performance trace toggle in main-menu and pause settings that writes periodic and slow-frame JSONL samples to `user://performance_trace_latest.jsonl`.
- Reduced long-run main-thread HUD/spawn overhead by caching gameplay settings reads, caching combat HUD key labels, and using a lightweight spawn-growth score path.
- Combat HUD redraws now skip unchanged labels/cooldown widgets, and the ultimate-energy fill uses cheaper geometry so 30 FPS cooldown presentation creates less main-thread UI work.
- Per-frame HUD stats now use a lightweight payload that omits role-detail text not rendered by the live HUD, while full stat summaries remain available for explicit refreshes.
- Per-frame combat HUD cooldown payloads no longer rebuild blessing-skill evolution requirement text; hover/detail paths still use full descriptions when explicitly requested.
- Fixed 三命诡影 rebirth timing so target loss during revive no longer leaves it frozen/undamageable, and kept the authored 祸月星核 boss visual alive across repeated visual refreshes.
- Developer mode now includes a configurable normal-enemy batch spawner for each small enemy archetype, bypassing the normal active-enemy cap for dense-combat and enemy-specific reproduction.
- Runtime enemy caps no longer shrink based on low FPS, so endless-mode enemy density is controlled by spawn rules and difficulty profile rather than current frame rate.
- Level-up and skill-reward flow now avoids same-frame spikes by deferring level-up offer construction to the next frame, using lightweight immediate HUD stat notifications, deferring full HUD/save maintenance, and spacing chained pending level-up popups by a short delay.
- Added a performance optimization and validation record documenting dense-combat boundaries, root causes, trace workflow, and PR review checks.
- Reused player projectile nodes now restore their own scene-specific exported defaults, preventing pooled mage wave projectiles from inheriting generic bullet visual bounds.
- Batched damage queries now collect candidates from per-shape/per-radius grid bounds instead of one merged bounding box, and frame caches are isolated per current scene.
- Player per-frame timer and developer no-cooldown updates now route through `player_timer_flow.gd`, reducing `player.gd` responsibilities and covering temporary buff expiry with a smoke test.
- Player authored/primitive effect wrappers are thinner and route scene-specific setup into `player_authored_effects.gd` / `player_effect_primitives.gd`, with a bridge smoke covering common effect spawns.
- Runtime player save/load now restores role health after roles, equipment, attributes, and blessings are applied, preserving boosted health pools and standby-entry labels across roundtrips.
- Local project checks now include a player save roundtrip smoke covering health/mana, blessings, equipment, cooldowns, temporary buffs, and story style state.
- Blessing-driven skill unlock/evolution events now include consumed material details and show a battle UI popup when recipe materials are locked.
- Local project checks now run the player blessing system smoke so recipe-consumption notice payloads remain covered.
- Player blessing skill query, composition, binding-choice, and unlock notice bridge code moved from `player.gd` into `player_blessing_skill_bridge.gd`, keeping `player.gd` closer to a compatibility coordinator.
- Fixed developer blessing options for role-bound blessings so shared role counts display and disable correctly instead of always appearing as 0/6.
- Cleaned legacy progression runtime and documentation entry points.
- Level-up progression now uses the blessing system as the active progression model.
- Developer upgrade flow now points at blessing offers instead of old card pools.
- Player upgrade application was reduced to the current reward types: blessings, equipment, small boss training, final core rewards, and blank continuation options.
- Documentation was rewritten around current blessing, equipment, skill unlock, enemy spawning, HUD, and architecture boundaries.

### Added

- Added the fourth roster role 机械师 (mechanic), a summoner-engineer (deep-navy hair, round glasses, white lab coat after Maria Custard; amber-themed effects and badges): 120 base health, 0 damage-reduction value, mage movement speed. Basic attack 铆钉枪 is a 300-range single-target shot at 100% damage. Trait 战场改装 produces 1 part every 4s while she is on field (cap 10), each part granting +4% summon and volley damage. Full-energy entry skill 紧急部署 deploys a tulip turret (8s duration, one shot per 0.8s, 120% damage). Ultimate 机械全开·郁金香齐射 shows a landing warning, then lands 3 salvos of 300% AoE damage (radius 150). She has five fully automatic active skills — 浮游炮 `drone` (14s), 感应地雷 `mine` (16s), 电磁脉冲 `emp_burst` (18s), 郁金香炮塔 `tulip_turret` (20s), 导弹齐射 `missile_volley` (22s) — 23 build cards including 5 direct unlock cards, and 7 mutually exclusive level-talent groups (14 formal + 3 placeholders).
- Added the team-swap panel (`scenes/UI/team_swap_panel.tscn` + `scripts/ui/team_swap_panel.gd`): the endless camp gains a 整备台 interaction point (interact key, default `F`) and the story prep screen gains an 调整队伍 button, both opening the same panel — left column lists the current 3-role team, right column lists bench candidates; a confirmed swap writes `team_order` into the corresponding save and takes effect next battle. Teams must stay exactly 3 unique roles; illegal operations (locked, duplicate, wrong team size, unknown role) are rejected with feedback.
- Added mechanic art matching the existing three roles' chibi style and size, visually modeled after Maria Custard (Rance) — long deep-navy hair, round glasses, white lab coat: the `assets/players/mechanic/` sheets (idle 2940×138 with twelve 245×138 frames, run 1024×768 with twelve 256×256 frames in a 4×3 grid, with frame-faithful .aseprite sources and mechanic.tscn sharing wizard.tscn's structure: internal scale 0.65, external scale 1.7) are derived from the wizard sheets via k-means (24 clusters) palette mapping — hair → deep navy, robe → off-white lab coat, teal accents → steel blue, orb → amber energy core — plus per-frame iris-anchored round glasses; camp facility portraits (`assets/UI/facility/机械师head.png` 36×36 + mechanicchange.tscn, `assets/UI/facility/机械师.png` 128×128 + mechanichead.tscn) are derived from the mage badges (hair lavender → navy via flood-fill background separation, badge ring → amber, round glasses on the 128 version); the concept sketch `assets/sketch/人设草图/机械师草图.jpg` (589×527); and seven `effects/mechanic/` flipbook sets (drone 4 / mine 8 / emp_burst 6 / tulip_turret 3 / missile_volley 2 / ult_warning 3 / ult_explosion 7 frames; all 256×256, ≤8 colors) whose per-frame visual radii are measured against the actual damage radii per the docs/07 effect-fit principle. Tooling: locally compiled Aseprite + aseprite-live-mcp (see docs/07).
- Added `scripts/tests/mechanic_roster_smoke.gd` and `scripts/tests/team_swap_smoke.gd`, both discovered by the check_project.sh smoke glob and passing. Six other smoke failures currently reported by check_project.sh (endless_tier_scaling, gunner_authored_event_projectile, mage_surging_wave_level_talents, player_temporary_health_stacks, shared_talent_runtime, skulltomb_charge_decision) already existed on HEAD before this change and are unrelated to it.
- Added a repository-wide game-design analysis and review process covering evidence authority, state/mechanism mapping, chains and feedback loops, player cognition and agency, pacing, build and enemy ecology, run lifecycle, production risk, validation gates, implementation handoff, and post-implementation review, plus a reusable decision-record template under `docs/design-reviews/`.
- Added the complete implementation specification for all 18 three-stage skill-talent trees: 108 stable nodes, Lv.3/Lv.6/Lv.9 triggers, per-choice naming changes, ordinary-upgrade inheritance, save/UI contracts, and path validation boundaries.
- Added a character-panel UI smoke covering the six-skill selector, fixed left/right talent tree and path state, concrete build stacks, mutation upgrade explanations, blessing I–IV display, role preview isolation, empty states, scrolling, and supported viewport bounds.
- Added 36 mutually exclusive Lv.3 skill-build talents across the swordsman, gunner, and mage, with one derived build level for each role trait, entry, basic attack, two active skills, and ultimate.
- Added a serial reward step for skill-talent choices after normal four-card/select-two upgrades and blessing binding, including continue-save restoration without duplicating pending level-ups.
- Added developer-mode controls to select, replace, or clear skill talents; direct selection automatically unlocks and raises the corresponding skill build to Lv.3 for testing.
- Blessing-driven skill unlock state.
- Role-shared role blessings and separate skill-bound blessings.
- Character panel blessing display and composition support.
- Map-bounded wave spawning with warnings.
- Runtime performance guard for dense combat scenarios.

### Notes

- BGM files under `assets/` are non-commercial placeholder materials for development testing only and will be replaced before commercial release or public distribution.
- 技能点加点改为类 MOBA 技能栏交互：已有技能与普通攻击直接点击槽位上方“+”升级；空技能槽点击“+”后只提供当前角色尚未拥有技能的三选一。全局按钮仅显示技能点数量。
- 剑士普攻分裂与地裂范围改为随当前普攻斩击长度动态计算：分裂半径为 100 + 长度一半，地裂半径为 75 + 长度一半；地裂视觉、伤害、存档和区域不重叠判定同步使用动态半径。
- 枪手普通攻击 LV9「贯穿」改为每颗主弹 60% 概率贯穿全部敌人，贯穿后继续飞行至最大射程消失；与爆裂组合时仅分裂前主弹享受贯穿，分裂弹不再贯穿，可与强震同时生效。
