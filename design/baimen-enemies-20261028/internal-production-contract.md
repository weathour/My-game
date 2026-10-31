# White Gate full enemy production contract — root, 2026-10-28
User authorization: complete ideal-state White Gate enemy function/form/stats/runtime first, then standing illustrations/combat animation/VFX and actual integration/verification. Goal is active; not merely first6 prototype. All18combatnodes,12ordinary,6elite modules,10Boss families,5active derivative categories. No commits/push. Do not touch archive/legacy. Huge pre-existing dirty tree must remain. Workers are not alone.

## Ownership
W1 runtime: all scripts/battle/ enemy runtime/system/director/session/targeting/resolver/mechanics and NEW pure enemy action/scheduler/geometry helpers. Own runtime tests. No content or UI writes.
W2 content: scripts/content/enemy_catalog.gd (new), stage_catalog.gd, optional separate boss data; scripts/campaign/ only necessary full chapter compatibility; content/campaign tests. Own data completeness and all18 battle availability. Not combat_catalog character skills unless approved by root.
W3 rendering/UI: scripts/ui/chronicle/battle_canvas.gd, battle_art.gd, battle_view.gd; new enemy actor/codex/UI resource mapping and own tests; route detail enemy-inspection entry as coordinated. No runtime damage or catalog edits. Existing player art preserved.
Root coordinates integration and phase gate; Terra owns deliverable prose/docs/names. Art generated only AFTER mechanics/data checks pass. Do not autonomously generate assets or copy legacy scripts. Use temporary existing art only during mechanics, never call it final.

## Frozen data API (W2 producer, W1 and W3 consumers)
EnemyCatalog static definition(id:String)->Dictionary deep duplicate, ordinary_ids(), elite_ids(), boss_ids(), validate()->Array. Constants ORDINARY/ELITES/BOSSES/DERIVATIVES may be dictionaries. Every definition returns fields:
`id` (stable E01–E12, L00–L06, B01–B18, D01/D03/D05/B10_R; M03_WAR/M04_WAR for visual-only ifneeded), `name`, `behavior_id`(E01–12 or A–J), `rank`(ordinary/heavy/field_elite/boss/object/proxy), `visual_id`(normallysameid), `hp`,`damage`,`speed`,`radius`,`xp`,`body_height`, `attacks`(Array[Dictionary]), `params`(Dictionary), `elite_rule_id`(empty orL01–06), `description`,`counterplay`(Array2strings), `portrait_path`,`actor_path`(canemptyuntilart), `palette`.
Human names/description/counterplay finalized byTerra, seed only accepted names below. Worker may askTerra for copy; don't write long new lore.
Attack dictionaries minimum `id`,`shape`,`range`,`windup`,`recovery`,`damage_scale`; optional`length`,`half_width`,`radius`,`count`,`spread`,`speed`,`life`,`delay`,`slow`,`duration`,`spawn_id`,`spawn_count`,`limit`,`gap_angle`,`gap_width`,`major`. Attacks actions list: swipe/shot/charge/fan/pot/command/heal/slam/hook/pulse/summon/anchor/collaboration; keep strike/nova aliases for old fixtures. W1 may add narrowly necessary fields and notifyW2+W3 before use, not silently mismatch.
StageCatalog existingAPI preserved. Eachstage new `boss_definition` =Bxx, `field_elites`=[idforcard,idforequipment], `action_budget`={major:1or2,melee:2}, `derivative_cap`=6, `boss_derivative_cap`=4, `role_caps`={support:1,heavy:2,ranged:4}, wavescycle usesEIDs. Existingboss_hp/boss_name/seed/map/time/kill/bonus fields retained. Boss configHP overridesprofileHP; enemy_hp/damage applynormal scale and damage according documentedrules, not doubleBossHP.
L00 is plain amplified beginner fieldelite, no seventh rule. L01–06 standalone authored forms attach one rule. `kind` legacy economic type preserved for fixtures, but explicit rank/reward_tag/counts_for_threshold separates behavior. Fieldspawn picksdefinition fromstagebasedrewardslot; does not create extra reward system.

## Ordinary initial stats and style (base beforestage scale)
ID/name/HP/damage/speed/radius/body_height/XP:
E01 草甲鬼卒 38/10/58/13/52/3 — straw/wood/rag low irregular humanoid; close swipe.
E02 骨弓伥 32/12/40/13/64/4 — thin invertedV bonebow; lockedshot, no infinite retreat.
E03 轭骨奔兽 58/16/82/16/70/5 — fourleg bone-yoke beast; committed charge+recovery.
E04 扉甲卒 90/15/42/18/74/6 — asymmetric door-shield thinlegs; frontdirectdamage reduction40% duringlockedguard, periodicdrop. DOTnotcleansed/immune.
E05 纸灯蛛 48/12/36/16/62/5 — lanternbody/spiderypaperlegs;5widefans.
E06 背瓮行脚 56/14/38/17/68/5 — roundceramicback/squat; delayedpotpatch max1/source.
E07 鸣幡吏 72/10/34/17/82/6 — tallbanner/commandtokens; command<=3existingfollowers, no spawn.
E08 供碗祠巫 68/8/18/18/74/6 — lowaltar/blankwoodmask/offerbowl; fixedanchorheal<=2, totalreceivedhealing<=15%maxHP pertarget acrossallpriests; notBoss/elite/healer; neverfollowtosustainleash.
E09 撼钟尸卫 160/22/32/25/112/10 — broadbellarmor/greatbellhammer; twoclearlyseparatedslams, recovery.
E10 钩轮牵阵者 130/18/42/23/108/9 — tiltedwheel/diagonalhook; linehook/briefslowstrip, noforcedpull.
E11 负棺驮役 150/14/30/26/104/10 — lowmulti-legcoffincarrier; max2wavesx2D01, visibleeggcoffinD05 first.
E12 碑背石傀 185/22/24/28/116/12 — squatfourlegstonetortoise/steleback; sequentialarcs/gappedpulse.
LightE01–08; heavyE09–12. Body sizesworldunitsrelativeJia72, radiiindependentandclearlyfootmarked.
Normalmajorwindup .8–1.2; heavy1–1.4; singlemeleestrike.45–.6; recover1–1.6heavy. Initial tuning only, evidence canjustifyadjustments, notifyrootfor meaningfulbalance changes.

## Elite6 initial forms/rules
L00 HP280 damage20 speed44 radius24 body116, E01base, no addedrule.
L01 command/banner colossus (baseE07) HP340 damage22 speed42 radius26 body140: bind<=3EXISTINGordinary, stopfuturecommandswhenrootdies, followerskeeppreviousXP/gateidentity; nofollowers->normalattack.
L02 lanternmother (E05) HP340 damage20 speed36 radius26 body138:2targetableanchorsD03, finitepositionswithsafeopening; no immunity.
L03 fetteredshieldtwin (E04) HP400 damage22 speed40 radius28 body146:1finiteD01escort, visible220-distance tether; bounded5s25%reduction (notHPregrowth), breakbydistance/escortdeath; cooldown8s. Describeaslimitedlinkprotection, nofullimmunity.
L04 hatchingcoffin (E11) HP420 damage22 speed30 radius30 body150:2wavesx2D05eggs->D01; budgetnotrenewonkill.
L05 mourningecho (E10shape ornewmirrorghost) HP360 damage22 speed44 radius26 body144: echooneattackonce fromlockedoldorigin withnewtell; norecursion, sameactionbudget.
L06 lightningexecutionghost (E09base) HP430 damage24 speed42 radius28 body152:afterdesignatedownattack1delayedmarker, max2; notauto-playerhitreflection.
Rewardcard/equipmentassignedbyfieldslotnotdefinition,XP18default root only. StageenemyHPscaleapplieselite, damage scaleappliesonce. Oneoptionalfieldeliteperstage.

## Boss identities and family/sequence
Keepall18specificvisual IDs evenwherekitshared. Familiesmapping: A B01/B02; B B04/B03/B08/B13; C B05/B11; D B06/B09/B10; E B07/B14; F B12; G B15; H B16; I B17; J B18.
Terra fullnames/copy path /tmp/my-game-baimen-enemy-art-direction-candidates.md (latest form revision). Normal humanoid-with-armor is insufficient as finalBoss:
B01 empty-faced stele-armored patrol;B02 huge eaves/copperdeitymaskbody;B04 wagon/yokeboneox/demonfusion;B05 hangingmasklantern/longjointedrobe;B03 three-mask/rippedbannerhulk;B06 shrineroofstonebeast;B07 giantsealbody/scrollarms;B08 floodgate-toothedcrocodilelongbody;B09 furnacebellyfourlegs;B10 lock-facedtwinwardens(twoindependentvisualsB10/B10_R);B11 many-eyedumbrella-lanternspirit;B12 multiarmbanner-lanternwitch;B13 battlementstoneowlbeast;B14 boatcoffinlongbodyspectralmarshal.
B15 CaoXiu ghosthunterbeastform retainsface+bow; G attacks must include lockedvolley plus staggeredshortcharge/finitecommand (do not makehimjustanotherCaoChuncharger).
B16 CaoChun tigerpantherarmoredridergiant retainsface+weapon; longcommittedrush/escortdifferentinterval.
B17 ZhangLiao yaksha wedge/longweapon; oneprimary -> GaoShun fortress-armor OR ChenGong scroll-spirit ->sharedrecovery. OnlyZhangLiaoBossHP; othersnon-targetableapparitionpresentations, truefiniteD01soldierscanbetargeted.
B18 LuBu fourarmghostgod (2physical2spectral), doublefeathers, halberd, retainedhumanface;100–70/70–35/35–0thresholdsequencesskippablebydamage; nophaseHPgate, nocurseclear, noimmortaladdshield.
A basicpursuit/sweep/recovery, B committedcharges withseparatenewtells, C fan+delayedlamps, D two-beatheavy, E finitecommandcycles, F destructibleanchorschanginggap+sourceopen, G rangedhunter+stepcharge, H longheavycharge, Icollaboration, Jextendedreadablecombo. EveryBossremainsdamagable; sequencecontainsrealrecovery1.5–2.5s.
Bossbodyheights: B01128,B02148,B03172,B04164,B05166,B06184,B07184,B08176,B09184,B10each170,B11178,B12202,B13188,B14188,B15204,B16218,B17220,B18248. Radius28–46 notbodyhalfscreen; largeposemustnotconcealtelegraphs. XPbase30exceptfeatured40–60, neverclonedproxyXP.
InitialbossHP B01=550 B02=900 B04=1250 B05=1150 B03=1750 B06=2150 B07=2400 B08=2700 B09=2850 B10=3200(shared) B11=3150 B12=3600 B13=3650 B14=3650 B15=4300 B16=4800 B17=6200 B18=7600.
NormalHPmultipliers inthatrouteorder:1,1.05,1.2,1.2,1.35,1.5,1.55,1.65,1.65,1.75,1.8,1.9,2.0,2.0,2.15,2.25,2.35,2.5. Damagegradual1.0to1.8, nohiddenadaptivepowerbalancing. Stagecapinitial28–42 ordinary(heavy<=2/support<=1/ranged<=4), notcountboss/fieldeliteasordinary; derivativesseparate. Preserveoldfirst6time/killgatesinitially unlessclearplaytestneed, laterboss_time90–120/kill45–64; bonus_time~time+70–100 (rewardonly,nofaildeadline). Allinitialvaluesdocumentednotclaimbalanced.

## Runtime and geometry handshake W1->W3
Retain commonoldfields; adddefinition_id,behavior_id,elite_rule_id,visual_id,rank,reward_tag,parent_id,hp_owner_id,targetable,counts_for_threshold,death_reason/body_height/action_serial/state/telegraph. Every runtime configuredfromEnemyCatalog; no UI guessingfromkind.
Persistentbattle.telegraphs/hazards orenemy.telegraphdescriptors; defineuniformshapegeometryonce(W1exportshelper). ShapeIDsdisc/sector/line/ring_gap/fan/marker;fieldsowner_id,action_serial,phase,origin,direction,length,radius,half_width,gap_angle/gap_width,remaining,total,visual_id,damage. Rendererconsumesactualcollisiondescriptor. Allhitswithplayer-radiuspaddingmatchwarnedarea; nosecondUIradiusformula. Projectilesneedsource_id/visual_id/hit_radius/TTL; telegraphmustlockdirectionwithtimelefttomove. Alltimersbattle-delta/pausedsafe. Eventsareone-shot,notpersistentstate.
Source deatheffects: cancelfuturecommands/unhatchedeggs/anchors/echo; existingliveD01remainuntilkill/end; grounddamageendsimmediatelywithvisualfade<=.6, firedboltsfinishshortTTL. Endcombatclearsall withoutdeathrewards. Slots:major1wholeB01/B02(includingBoss+fieldelite), later2onlycompatible; normalmeleeactive2. Derivativecaps6preboss4boss. Admitgeometrywithwalkableexit; waitincompatibleactions, notdespawnexistingmobs.
ShareddamageB10: realownerisBoss, partnerkindproxy/targetabletrue, noownreward/gate. Deduponeindependentshape/pulsebyhp_owner, NOTallcastglobally (DOTcast0/repeatedfieldpulsesmuststillhurt). ownerdamagecanonicalforcurse/statusstate. Aliveproxiesmustnotblockprojectileswithoutcontributingdamage. Testparent/childorder.
Incomingdamagecontextincludesimmutableimpactorigin/direction forfrontshield. DOTbypassesdirectionshield anddoesn'tsilentlygetdeleted. Unifiedtargetablefilter fornearest/in_shape/projectiles/cursepropagation; objectsD03/D05canhit/curse/procbutnotlivingkill, ghostsnotarget.
Targethysteresiscandidate nearer~30%andhold~.25s asstart; actualnewattackreeval, projectiles/onecastremainfixed. Preservefinitebackgroundreactivecastlimits. No newmouse/keys.
Rewardsemantics: kindboss/fieldtags ONLYrealrewardowners. D01/D03/D05/proxiesxp0thresholdfalse; cancellationnotkill; truefiniteenemyonhittriggersstillvalid. BOSSdeathimmediatevictory (JIAdeathsameframefailspriority), collectearnedgems, donotawardlivingelite. Donotchangecampaignresultkeys/transactionorder/pendingchoices/oldsave.

## Stage/content gate
18configs mean18available viaC.stage. Deliver completeenemydefinitioncoverageandwavequotasbeforeclaimingchapterdone. Reuseexisting36routeIDs/events; nonewworldcampaigns/gear/cards/forcedstoryrewrites. B17heroesonlyaftervictory+story/reward; B18resourcescarrynoextrafountain. E/l introduction tableinapprovedcurrentproposal; noeachroutealltypesguarantee.
W2 tests18isolatedrealbattlefixtures +64topologywithoutlonggames +representativefullcampaigntransactionpaths; don'tfakecombatvictoryasbalanceevidence. Existingchapter_two_smoke expectsB07locked mustbeupdatedonlywithfullcontentdelivery. Stateclearlytransactionfixtures vsactualplay.

## Art/output contract aftermechanicalgate
Newdir design/baimen-enemies-20261028; assets/enemies/baimen/<visual_id>/ withportrait.png, idle.png, move.png, attack.png, special.png, hit.png or validatedsheet/framesresource. Nativeeditableaseprite, srcgenpng/prompts/hashmanifest mandatory. FinalrasterdrawbybuiltinImageGen, Asepriteforpalette/crop/export; Pillowread-onlyaudit. NoSVG/proceduralbodyplaceholderasfinalart. ExistingVFXtextureframesmaybereusedwithsourceaudit; newneededrastereffectsgeneratedseparately.
All12ordinary +6elite +18Bossvisualidentities(B10has2bodies) +2B17collaborators =39combatvisualslots (L00reusesE01). Needstandingillustrationandcombatbody/actionsforeach; clone/D01canreusewithexplicitmanifest, D03/D05needseparateobjectsprites notinventwholecharacterart. 4featuredBoss+2collabidentityreferencesmustbeconcretebeforetransformation, preserveface/weapon, noadditionaluserapprovalflowinabsenceofaspecificblock.
W3 runtimeAPI pathfallbacksupportsmechanicswhileartnotready, finalassetverifymustfailmissingplannedassets ratherthansilentlyclaimfallbackcomplete. Standingartaccessiblefromread-onlyenemyinspection/codex(doesn'trequire newsaveunlocksystem), stagepreviewentry; fullportrait notjustthumbnailonlyonsprite.
Acceptance: data/runtimechecks -> requiredGodotheadlessstartup -> actualplayablecontrol/campaign checks -> artstage -> 3resolutionactualGodotframes+animation+VFX/provenance -> finaldocs/status/CHANGELOG/graphupdateexistingonly. Ownmeaningfultests, preserveothers'work, failuresrepairwithowner. No graphrebuildofhome, consultdocs/GRAPHIFYifupdaterrejectsGDScript.
