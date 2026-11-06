#!/usr/bin/env python3
"""Build explicit ability/enemy sound bindings from the frozen combat snapshot.

Every assigned family is chosen from authored identity, ability title/mechanic,
or enemy name plus move geometry. This is production metadata, not a runtime
physical-vs-magic fallback.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / "design/skill-audio-20261103/runtime/combat-content-baseline.json"
OUT = ROOT / "assets/data/audio/skill_sound_profiles.json"
ABILITY_MAP = ROOT / "design/skill-audio-20261103/profiles/ability-family-map.json"
FAMILIES = {
    "blade", "heavy_blade", "thrust", "blunt", "bow", "dash", "earth",
    "fire", "ice", "lightning", "wind", "water", "poison", "arcane",
    "curse", "heal", "shield", "mana", "cleanse", "summon", "buff",
    "beast", "bone", "armor", "command", "flesh", "boss_hunter",
    "boss_cavalry", "boss_general", "boss_demon",
}

ENEMY_ACTION_OVERRIDES = {
    # Named bosses are split by actual attack mechanics. Boss family remains on tells.
    ("B15",0,"hunter_aim"): ("bow", "曹休人形定点射击"),
    ("B15",0,"hunter_volley"): ("bow", "曹休人形扇形箭雨"),
    ("B15",0,"hunter_reposition"): ("bow", "曹休人形退阵射击身份；释放层使用突进声，命中层保持弓箭声"),
    ("B15",1,"beast_hunt"): ("bow", "兽相扇射追猎"),
    ("B15",1,"beast_leap"): ("beast", "兽相扑跃"),
    ("B15",1,"hunt_mark"): ("earth", "兽相地面落点标记"),
    ("B15",1,"beast_rend"): ("heavy_blade", "兽相近身大范围撕裂挥击"),
    ("B16",0,"rider_lance"): ("thrust", "曹纯骑枪冲刺；释放层使用突进声，impact保留枪刺音"),
    ("B16",0,"rider_cleave"): ("heavy_blade", "曹纯近身枪戟横斩"),
    ("B16",0,"rider_return"): ("thrust", "曹纯骑枪折返冲击；释放层突进，命中保留刺击"),
    ("B16",1,"tiger_long_charge"): ("armor", "虎豹甲骑巨相装甲长冲；释放层突进，命中落在甲骑重体"),
    ("B16",1,"tiger_trample"): ("blunt", "巨相踏击"),
    ("B16",1,"leopard_return"): ("armor", "虎豹甲骑巨相装甲折返冲锋"),
    ("B16",1,"cavalry_break"): ("earth", "骑兵巨相环形地面震击"),
    ("B17",0,"general_lunge"): ("thrust", "张辽人形突刺；释放层突进，impact保留兵器刺击"),
    ("B17",0,"general_cut"): ("blade", "张辽人形横斩"),
    ("B17",0,"human_formation"): ("command", "张辽与友军协同布阵"),
    ("B17",1,"yaksha_break"): ("heavy_blade", "夜叉将相重甲冲阵；释放层突进，命中层使用重兵器声"),
    ("B17",1,"yaksha_cleave"): ("heavy_blade", "夜叉相重型横斩"),
    ("B17",1,"war_formation"): ("command", "夜叉相与友军协同布阵"),
    ("B17",1,"yaksha_pulse"): ("earth", "夜叉相环形震击"),
    ("B18",0,"halberd_sweep"): ("heavy_blade", "吕布方天戟横扫"),
    ("B18",0,"halberd_charge"): ("heavy_blade", "吕布持戟冲锋；释放层突进，impact保留戟刃身份"),
    ("B18",0,"halberd_fall"): ("earth", "吕布落戟地面标记"),
    ("B18",0,"halberd_finish"): ("heavy_blade", "吕布终结横扫"),
    ("B18",1,"demon_fourfold"): ("heavy_blade", "鬼神相多臂挥戟"),
    ("B18",1,"demon_skybreaker"): ("heavy_blade", "鬼神相持戟长冲；释放层突进，impact保留重戟身份"),
    ("B18",1,"demon_quake"): ("earth", "鬼神相环形震击"),
    ("B18",1,"demon_heavenfall"): ("earth", "鬼神相落戟地面标记"),
    ("B18",1,"demon_final_cleave"): ("heavy_blade", "鬼神相终结重斩"),
}

# Identity family for every authored boss. Action cues remain separately
# matched to weapon/geometry; this table owns the boss tell, phase and defeat.
BOSS_IDENTITY = {
    "B01": ("boss_general", "碑甲鬼校以重甲军将身份出现"),
    "B02": ("boss_general", "守街尸将是近战军将身份"),
    "B03": ("boss_demon", "三面裂旗鬼魁以异相首领身份出现"),
    "B04": ("boss_cavalry", "轭骨牛督是押粮兽骑重击首领"),
    "B05": ("boss_demon", "冥灯术士以灯法异相首领身份出现"),
    "B06": ("boss_demon", "祠脊石兽是祭祠异兽首领"),
    "B07": ("boss_general", "悬印司令以军令统帅身份出现"),
    "B08": ("boss_cavalry", "闸齿鳄首以冲击型水门首领身份出现"),
    "B09": ("boss_demon", "炉腹铁鬼以熔炉异相重甲首领身份出现"),
    "B10": ("boss_cavalry", "封库双禁卫以双重装禁卫身份出现"),
    "B11": ("boss_hunter", "伞眼灯灵以巡城远程灯师身份出现"),
    "B12": ("boss_demon", "多手幡灯大巫以瘟灯异相首领身份出现"),
    "B13": ("boss_cavalry", "石鸱裂垛以城垣冲击首领身份出现"),
    "B14": ("boss_general", "引舟鬼帅以渡口军令统帅身份出现"),
    "B15": ("boss_hunter", "曹休及鬼猎兽相保持猎手身份声纹"),
    "B16": ("boss_cavalry", "曹纯及虎豹甲骑巨相保持骑军身份声纹"),
    "B17": ("boss_general", "张辽及夜叉裂阵将相保持将军身份声纹"),
    "B18": ("boss_demon", "吕布及四臂鬼神相保持鬼神身份声纹"),
}


def ability_family(owner, a, mapping):
    # Explicit owner/ability table is authoritative; runtime combat type and
    # string matching never choose a hidden physical/magic fallback.
    entry=mapping.get(owner,{}).get(a["id"])
    if not entry: raise ValueError(f"missing explicit ability family {owner}/{a['id']}")
    return entry["family"],entry["design_basis"]


def enemy_family(eid, name, form, form_index, move):
    text = f"{eid} {name} {form} {move['id']} {move['action']} {move['shape']}"
    if (eid, int(form_index), move["id"]) in ENEMY_ACTION_OVERRIDES:
        return ENEMY_ACTION_OVERRIDES[(eid,int(form_index),move["id"])]
    boss = {"B15":"boss_hunter", "B16":"boss_cavalry", "B17":"boss_general", "B18":"boss_demon"}
    if eid in boss: return boss[eid], f"{name}（{form}）专属招式"
    if any(x in text for x in ["弓", "箭", "射", "弩", "shot", "fan"]): return "bow", "敌人/动作是射击、扇箭或投射攻击"
    if any(x in text for x in ["骨", "尸", "骷", "bone"]): return "bone", "敌人视觉身份为骨/尸类"
    if any(x in text for x in ["灯", "符", "巫", "阵", "术", "祠"]): return "arcane", "敌人身份/动作属于仪式、符术或灯阵"
    if any(x in text for x in ["兽", "豹", "牛", "骑", "奔"]): return "beast", "敌人/攻击身份为兽类或骑兵冲击"
    if any(x in text for x in ["钩", "肉", "牵", "flesh"]): return "flesh", "敌人动作以钩拽/肉身牵引为特征"
    if move["action"] in {"command", "heal", "summon"}: return "command", f"动作类型{move['action']}是指挥/治疗/召唤"
    if move["action"] == "charge": return ("beast", "兽类敌人以身体冲撞") if any(x in text for x in ["兽", "牛", "豹", "奔"]) else ("thrust", "直线冲击按敌人兵器/动作身份归为刺击")
    if move["shape"] in {"ring_gap", "marker"} or move["action"] in {"pulse", "anchor", "pot"}: return "earth", "落点/环形震击/地面标记机制"
    if move["action"] in {"slam"}: return "blunt", "近身重击/砸击动作"
    if move["action"] == "hook": return "flesh", "钩索牵引动作"
    return "blade", "近身挥击动作"


def cue(family, phase): return f"{family}.{phase}"


def build():
    src = json.loads(BASE.read_text())
    ability_map=json.loads(ABILITY_MAP.read_text())
    profiles = {"schema_version": 1, "character_abilities": {}, "enemy_actions": {}, "enemy_action_aliases": {},
                "boss_events": {}, "trait_bindings": {}, "ability_aliases": {},
                "global_cues": {"hurt":"feedback.hurt", "guard":"feedback.guard", "death":"feedback.death",
                                "pickup":"feedback.pickup", "level":"feedback.level", "elite":"feedback.elite"}}
    coverage = {"schema_version":1, "source_snapshot":str(BASE.relative_to(ROOT)), "characters":0,
                "abilities":0, "traits":0, "enemy_definitions":len(src["enemies"]), "enemy_actions":0,
                "unique_enemy_move_keys":0, "duplicate_move_id_records":[], "boss_actions":0,
                "boss_action_forms":0,"boss_event_contexts":0,"runtime_enemy_action_aliases":1,
                "priority_policy":{"ordinary_tell":"1–2; any major=4", "elite_tell":"3; any major=4", "boss_tell":"5",
                                    "ordinary_release_impact":1,"elite_release_impact":2,"boss_release_impact":4,
                                    "character_cast":2,"character_impact":1},
                "silent":[], "owned_stat_silence":[], "bindings":[]}
    for owner, kit in sorted(src["kits"].items()):
        coverage["characters"] += 1
        profiles["character_abilities"][owner] = {}
        coverage["owned_stat_silence"].append({"owner":owner,"modifiers":kit.get("owned",{}),
            "reason":"owned字段仅为持有/等级属性修正，不是战斗触发事件；无需独立音效。"})
        for slot in ["basic", "automatic", "manual", "support"]:
            val = kit.get(slot, []) if slot != "basic" else [kit["basic"]]
            for a in val if isinstance(val, list) else [val]:
                if not a: continue
                fam, reason = ability_family(owner, a, ability_map)
                if fam not in FAMILIES: raise ValueError(f"unknown family {fam}")
                impact_family = fam
                effect_family={"HEAL":"heal","MANA":"mana","WARD":"shield"}.get(a["kind"])
                if effect_family and not (a["kind"]=="WARD" and a.get("mechanic") in {"guard","rally","temper","extend","field"}):
                    impact_family=effect_family
                    impact_cue=cue(impact_family,"impact")
                    impact_silence=""
                    reason += "; 成功HP/MP/护盾增量由ability_effect确认后发对应impact，满值无增量则无声"
                elif a["kind"] in {"HEAL","WARD","MANA"}:
                    impact_cue=""
                    impact_silence="纯临时强化/窗口效果没有实际HP/MP/护盾增量事件；只播cast，不把数值状态变化伪装成命中。"
                else:
                    impact_cue=cue(impact_family,"impact")
                    impact_silence=""
                cast_family = "dash" if a.get("mechanic")=="dash" or a["id"] in {"M02_dash","M05_dash","M06_dash","N10_dash","N11_dash","N12_charge"} else fam
                ent = {"family":fam, "cast":cue(cast_family,"cast"), "impact":impact_cue,
                       "gain_db":0, "pitch_scale":1.0, "design_basis":reason}
                if impact_silence: ent["impact_silence_reason"]=impact_silence
                if owner == "JIA" and a["id"] == "JIA_basic":
                    ent["family"]="blade"; ent["cast"]="blade.cast"; ent["impact"]="blade.impact"
                    ent["kind_overrides"]={"THRUST":{"family":"thrust","cast":"thrust.cast","impact":"thrust.impact","design_basis":"破阵长枪装备改变基础普攻THRUST几何"}}
                profiles["character_abilities"][owner][a["id"]] = ent
                coverage["abilities"] += 1
                coverage["bindings"].append({"type":"ability","owner":owner,"id":a["id"],"slot":slot,"family":ent["family"],"basis":reason})
        trait = kit.get("trait", "")
        if trait:
            # Trait sounds occur at the originating ability/cast or damage event;
            # no extra periodic cue is emitted by this metadata.
            profiles["trait_bindings"][owner] = {"trait":trait,"family":"buff" if trait in {"mark","refund","ammo","relay","echo"} else "curse",
                "cue":"", "silence_reason":"被动通过原技能/实际伤害事件触发；独立trait仅改标记、资源、回响或结算，不增加周期性音效，避免重复播报。"}
            coverage["traits"] += 1
            coverage["silent"].append({"type":"trait","owner":owner,"trait":trait,"reason":profiles["trait_bindings"][owner]["silence_reason"]})
    for row in src["attacks"]:
        eid=str(row["enemy_id"]); fi=str(row["form_index"]); a=row["attack"]
        form_index=int(row["form_index"])
        fam, reason = enemy_family(eid,row["enemy_name"],row.get("form_name", ""),form_index,a)
        rank=src["enemies"][eid]["rank"]
        # Tell identifies what the move is (arrow, charge, ground mark, etc.);
        # boss identity is preserved by per-form phase/defeat cues.
        tell_family="dash" if a["action"]=="charge" else fam
        release_family="dash" if a["action"] in {"charge"} or fam=="dash" else fam
        profiles["enemy_actions"].setdefault(eid,{}).setdefault(fi,{})[a["id"]]={
            "family":fam,"tell":cue(tell_family,"tell"),"release":cue(release_family,"cast"),"impact":cue(fam,"impact"),
            "gain_db":(1 if form_index==0 else 3) if rank=="boss" else 0,
            "pitch_scale":(0.95 if form_index==0 else 0.82) if rank=="boss" else 1.0,
            "stage_priorities":{"tell":5 if rank == "boss" else 4 if a.get("major",False) else 3 if rank == "field_elite" else 2 if rank in {"heavy","proxy"} else 1,
                                "release":4 if rank == "boss" else 2 if rank == "field_elite" else 1,
                                "impact":4 if rank == "boss" else 2 if rank == "field_elite" else 1},
            "design_basis":reason}
        coverage["enemy_actions"]+=1
        if eid in {"B15","B16","B17","B18"}: coverage["boss_actions"]+=1
        coverage["bindings"].append({"type":"enemy_action","enemy":eid,"form":fi,"move_id":a["id"],"family":fam,"basis":reason})
    move_records = {}
    for row in src["attacks"]:
        key=(row["enemy_id"],str(row["form_index"]),row["attack"]["id"])
        move_records.setdefault(key,[]).append(row)
    coverage["unique_enemy_move_keys"]=len(move_records)
    coverage["duplicate_move_id_records"]=[{"enemy":k[0],"form":k[1],"move_id":k[2],"count":len(v),"shared_family":profiles["enemy_actions"][k[0]][k[1]][k[2]]["family"]} for k,v in move_records.items() if len(v)>1]
    for eid,(fam,basis) in BOSS_IDENTITY.items():
        profiles["boss_events"][eid]={}
        form_indices=sorted({str(row["form_index"]) for row in src["attacks"] if row["enemy_id"]==eid},key=int)
        coverage["boss_action_forms"] += len(form_indices)
        for form in form_indices:
            coverage["boss_event_contexts"] += 1
            profiles["boss_events"][eid][form]={"phase":cue(fam,"phase"),"defeated":cue(fam,"defeat"),
                "gain_db":(1 if form=="0" else 3) if eid in {"B15","B16","B17","B18"} else 0,
                "pitch_scale":(1.0 if form=="0" else 0.86) if eid in {"B15","B16","B17","B18"} else 1.0,
                "design_basis":basis + (f"；阶段{form}相较人形更低沉、更强" if form=="1" else "") + "; 独立身份阶段/终结提示"}
    # Only real emitted identities are aliases. Echo replay and temper spark
    # retain their source ability id, as verified in combat_mechanics.
    profiles["ability_aliases"]={
        "curse_dot":{"family":"curse","cast":"","cast_silence_reason":"持续咒伤没有独立施放动作。","impact":"","impact_silence_reason":"周期伤害由原施加技能的短命中音覆盖；不为每tick增添噪声。","design_basis":"combat_mechanics._queue_dot显式标记curse_dot；profile仅记录其身份，周期tick静音以避免重复提示。"},
        "guard_counter":{"family":"shield","cast":"","cast_silence_reason":"防御能力的被动反击由guard事件反应触发，没有独立施放事件。","impact":"blunt.impact","design_basis":"combat_mechanics guard处理在命中队列显式写ability=guard_counter；使用盾挡后的钝击反击音","gain_db":-2}
    }
    profiles["enemy_action_aliases"]={
        "command_fallback_swipe":{"family":"blade","tell":"blade.tell","release":"blade.cast","impact":"blade.impact",
            "stage_priorities":{"tell":1,"release":1,"impact":1},
            "design_basis":"enemy_system.gd无跟随者时把command降为近身swipe，此运行时动作不在静态87条表中，按fallback近战挥击绑定。"}
    }
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps(profiles,ensure_ascii=False,indent=2)+"\n")
    audit=ROOT/"design/skill-audio-20261103/profiles/coverage-audit.json"
    audit.write_text(json.dumps(coverage,ensure_ascii=False,indent=2)+"\n")

if __name__ == "__main__": build()
