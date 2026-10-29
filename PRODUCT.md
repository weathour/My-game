# Product Context

Updated 2026-10-29. Approved rules are documented in [the design consensus](docs/00_当前设计共识.md). The default UI supports the 18 configured White Gate battles, character growth and isolated campaign saves. The prior navigation and enemy-codex revision passed its automated and visual checks, but the user found the main map too simple. The main screen has been rearranged and checked at three sizes; the reference states, data mapping and test evidence are documented in [the module review](docs/design-reviews/2026-10-29_兰斯10主页面逐模块复核与重排.md).

## Experience

A desktop real-time roguelike combat game with character collection and growth across a forward-moving campaign. The fixed male protagonist is 贾苇索 (Jia Weisuo), a strong melee fighter. His name combines a reed cord used to bind harmful spirits with a pun on apparent lechery; his righteous choices and serious wrongdoing are both part of the current story. He is native to this world; his specific background and nature remain undecided. A new game starts with Jia Weisuo alone and two empty auxiliary slots. After the first stage, the player completes the normal five-card/two-pick reward, or three picks after defeating the card elite, before Emma's introduction begins. Emma (艾玛), an adult displaced Western mage using the existing mage character assets, joins and enters the pool only when that story ends; she does not consume a pick. In the new flow, she can appear as a duplicate in later draws; already generated candidates in old saves are retained. Jia flirts and forces her to travel with him; her resistance and reluctance remain clear, and joining does not imply trust or affection. The swordswoman is rescued later; the gunner and mechanic appear in later campaigns. These companions are travelers from other worlds. Up to two selected auxiliaries provide background help and can become the controlled character. Expedition companions have no numerical cap: between stages, choose from all owned, living characters eligible for the campaign, including new acquisitions. Later campaigns may exclude specific characters.

Campaign conquest and flirtation, romance and intimate companionship with a large cast of women are co-primary attractions. The user wants the latter to carry roughly half the experience's weight. The exact content and playtime allocation, relationship progression and handling of multiple relationships remain undecided. Discuss the combined experience first; the sources and reinterpretation of the female cast are deliberately left open.

The user specifically asks for Rance's direct, desire-driven adult-adventure tone, including exaggerated interactions and bawdy comedy. Earlier proposals for elaborate courtship or a mandatory gradual relationship arc have been withdrawn. Plan memorable character events alongside the adventure; a separate dating-simulation system is not a prerequisite.

The first-campaign plot now includes Jia Weisuo abducting and sexually assaulting the adult Lü Lingqi before he defends the city against the ghost Cao army. The event is stated without depicting the act. The later rescue and this harm both remain part of the story and the conflict with Lü Bu; forgiveness or recruitment is not predetermined. The protagonist's righteous choices coexist with serious wrongdoing.

Keep fighting continuous. Character levels unlock skills automatically. Within each small stage, optional corner fields offer supplies, experience or an extra elite challenge. When the Boss appears, ordinary spawning stops, while existing enemies and optional elites remain. Boss-specific reinforcements are limited and have a finite experience budget. Defeating the Boss immediately clears the stage; an unbeaten optional elite gives no bonus reward. Every clear gives character-card draws. Faster clears grant extra experience.

Basic attacks, routine skills and aiming are automatic. Players move, switch characters and manually trigger key skills; there may be multiple key skills. In-stage play must be possible without a mouse, with low overall complexity across movement, switching and skill inputs. Switching has only a short shared cooldown and preserves individual health, mana and skill cooldowns, without generic invulnerability or a skill reset. Character-specific entry effects are allowed, but frequent rotation is not a required universal loop.

The same skill keys invoke only the currently controlled character's key skills; background support triggers automatically. Mana is reserved for manually triggered key skills, while basic attacks, routine automatic skills and automatic support cost no mana. Background characters continue their cooldowns and recover mana at their own regeneration rate. Health recovery requires an explicit ability, supplies or a level-up. Living characters refill health and mana when leveling; fallen characters remain fallen. Switching itself restores neither resource. Unselected reserves freeze their state and cooldowns, while explicit events such as duplicate-card leveling and fountains still apply.

Normally only the controlled character takes direct enemy damage. An auxiliary may explicitly protect the protagonist by taking damage on their behalf. Each auxiliary has separately designed foreground abilities, background support and an owned-character passive that also works without joining the expedition. A fallen auxiliary stops providing background support but retains the owned-character bonus.

## Meaningful choices

Ordinary clears offer five random eligible cards, from which the player takes two. New characters start at a level set for their story unlock stage; duplicates add one level while preserving experience. Combat experience is split equally among the characters configured at stage entry: one gets all, two get half each, and three get one third each. Fallen members retain their share; reserves and characters joining after the battle receive none. Defeated enemies drop experience pickups that grant growth when collected. Victory collects the remaining experience, including the defeated Boss's reward, without awarding experience for surviving enemies. Owned characters provide bonuses even when absent from combat. Strong noncombat utility generally trades against field combat strength.

Equipment uses three shared slots: armor, weapon and accessory. Weapons can change the protagonist's attack form, accessories enchant attacks, and armor provides effects related to receiving hits. Weapon form affects only the protagonist; generic equipment stats affect the stage party. Enchantment defaults to the controlled actor’s direct basic attacks and skills; background support and summons inherit only when stated. Armor effects follow the actual recipient of damage. Specific values remain open. Players choose whom to field, train and keep in reserve, which field to approach, and how to equip the fixed slots. Show effects and conditions clearly without prescribing a best build. Avoid frequent skill-card interruptions and additional progression layers introduced merely to preserve legacy systems.

Health, mana and auxiliary deaths carry across small stages. Fountains and a completed expedition's return to camp restore the party and revive auxiliaries; ordinary stage transitions do not. Only protagonist death fails the stage; failure restores the pre-entry state without spending another campaign action. Cleared stages cannot be revisited for farming.

The campaign takes place in an alternate world after the Three Kingdoms have fallen. Ruins and supernatural beings fill the land; famous figures primarily reappear as spirits or transformed beings. The cause of the collapse, the protagonist's nature and the presence of surviving humans remain undecided. See [world setting and style](docs/16_世界背景与风格.md).

The campaign uses two map layers: a world overview for information and campaign choices, and a regional route through combat, elite, recovery and event nodes to a final boss. A major campaign is one expedition, and story phases have limited expedition actions. There is no limited preselected expedition roster. Campaign restrictions determine eligibility; each stage uses the protagonist and up to two auxiliaries. Exact routes and action counts remain undecided.

## References and presentation

Rance 10 is a reference for character-card growth, roster-wide value and campaign organization, as well as framed campaign presentation. The previous restriction to visual reference only is withdrawn. Its turn-based/AP combat is not the target of this real-time game.

The long-term content scale targets Rance 10 Part 1, delivered incrementally. The first campaign is 白门楼鬼城: Jia Weisuo sets out after hearing of Princess 吕玲绮, gains followers and territory through local conflicts, saves the city and Lü Bu's family from the ghost Cao army, and ultimately fights Lü Bu, beginning his rise as a regional lord. This plot outline is approved; exact nodes, the reason for the final confrontation, character recruitment and postwar territory remain open in the [first-campaign scope and development draft](docs/design-reviews/2026-10-26_首段教程战役与分阶段开发.md).

Retain this repository's own art, prose, audio and controls. Campaign controls now follow the requested Rance 10-style framing: dark green surfaces, fine aged-gold edges, selective corner ornaments and wine-red primary buttons, with desolate Three Kingdoms landscapes on the maps. Existing battle HUD components remain in use. Existing four-hero artwork is reusable source material, not a fixed roster or party rule. See [the visual system](DESIGN.md).

Black Myth: Wukong is one reference for the world's atmosphere. The user has accepted ancient grandeur, expansive landscapes, folklore's strangeness and humor, and heroic emotion, with a substantial addition of romantic allure and intimacy. Concrete scenes and palettes remain under discussion. Existing interface colors do not fix the appearance of the new world.

Ordinary rewards are five cards with two picks, increased to three picks after the optional card elite. Chapter finales offer seven cards with three picks, or four after that elite, and contain at least two eligible important-character cards. Story unlock gates still apply. Switching preserves temporary effects and summons; stage completion clears ordinary temporary effects and summons while health, mana, fallen status and skill cooldowns carry on.

Multiple manual saves coexist with automatic continuation. Leaving an unfinished battle resumes from its pre-entry state; a completed battle with pending rewards restores the same candidates. Loading an older manual save restores the whole earlier campaign state, without merging later character growth or rewards. See [save semantics](docs/06_UI_菜单_存档_音频.md).

## Interface requirements

- Keep the world overview and regional campaign route map distinct; inspecting information does not spend an expedition action.
- Organize the main screen around chapter and current march, a configured living female companion or the protagonist, the map, current task or route options, selected details, and the real party and equipment. Put menu and preparation at the bottom corners and current-position control on the map; omit a legend.
- Use contextual map navigation, keep party and equipment under preparation, and offer a read-only enemy codex; navigation and inspection do not advance or save the campaign.
- Show all owned characters, campaign eligibility and up to two auxiliary slots without an expedition capacity limit; empty slots are valid, including both at the start.
- Allow card dragging or equivalent keyboard actions to deploy, replace, exchange and remove auxiliaries. Inspect abilities, attributes and growth in context from a single detail entry; keep the current party and return context intact.
- Distinguish directly controlled skills, auxiliary support and owned-character bonuses.
- Show independent health/mana, unavailable fallen auxiliaries and recovery results.
- Show five-card/two-pick ordinary rewards, automatic unlocks and three shared equipment slots. Each character has at most two manual key skills.
- Present story scenes with a background, transparent character portraits and a bottom dialogue box; advance line by line, identify and highlight the speaker, and arrange expressions, poses, transitions and music to suit the event. Current assets and visual acceptance are tracked separately.
- Keep core information readable at 1280×720; use labels and shapes alongside color.
- Preserve keyboard focus and scrolling, and avoid requiring hover for essential information.

## Current delivery boundary

The White Gate chapter has 18 configured battle nodes and 38 initial character definitions; enemy integration and two continuous automated routes have been checked. Battle balance and remaining story detail still need their appropriate review. Legacy combat remains a separate entry; its skill-point and talent systems are not requirements for the new game. [Current status](docs/08_当前实现状态与后续重点.md) owns the execution boundary.

## Approved interface and current delivery

The user chose probe D for its Romance of the Three Kingdoms map and Rance 10 information layout; the earlier A/B probes were rejected for excessive browser-game styling. The later request adds Rance 10-style frames and buttons, replacing the former blanket prohibition on metal borders and ornament. See DESIGN.md and the [current reflow record](docs/implementation/2026-10-27_人物卡与主线界面重排.md).

The Godot default entry provides both maps, roster/equipment, events, rewards, formal campaign saves, settings, music and the configured White Gate battles with XP progression. Existing battle maps, character/enemy animations, portraits, effects and HUD components are reused; new rules remain in an independent battle core. Owned numerical passives add within their category; strong utility such as dispel/revival/interception requires a configured stage auxiliary. The seven base stats are HP, MP, attack, defense, attack speed, move speed and mana regeneration.

The latest HUD preference is the existing simple bottom-bar composition. Keep the three-row presentation as an option; both use the same battle rules and saved display setting. Campaign reflow gives rewards and party comparison more character-card presence. The preceding navigation and enemy-codex checks are recorded in the [redesign record](docs/design-reviews/2026-10-29_敌情图鉴与地图导航改版.md); the later main-screen rearrangement and its checks are in the module review above.
