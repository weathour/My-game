"""Validate shipped story content before importing or packaging the game."""
import json
import re
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parents[2]
data = json.loads((root / "assets/story/chapter1.json").read_text())
assert data["status"] == "runtime"


def catalog(rows):
    result = {row["id"]: row for row in rows}
    assert len(result) == len(rows), "Duplicate ID"
    return result


speakers = catalog(data["speakers"])
stages = catalog(data["stages"])
items = catalog(data["items"])
quests = catalog(data["quests"])
dialogues = catalog(data["dialogues"])
journals = catalog(data["journal_entries"])
runtime_source = (root / "scripts/story_data.gd").read_text()
runtime_stages = set(re.findall(r'"id":\s*"(chapter\d+_stage\d+)"', runtime_source))
assert set(stages) <= runtime_stages
assert len(quests) == len(stages) == 3
assert {q["stage_id"] for q in quests.values()} == set(stages)
assert data["rules"] == {
    "single_active_main_quest": True,
    "stage_reward_policy": "first_clear_only",
    "replay_permanent_rewards": False,
    "dialogue_replay_read_only": True,
    "turn_in_commit": "costs_progress_receipt_and_checkpoint_together",
}

for item in items.values():
    assert item["source_stage_id"] in stages
    assert item["turn_in_quest_id"] in quests
    assert item["actions"] == ["inspect", "turn_in"]
    assert not any(item[k] for k in ("droppable", "sellable", "occupies_endless_capacity"))
    if item["kind"] == "quest_item":
        assert item["storage"] == "story.quest_items" and item["max_stack"] == 1
    else:
        assert item["id"] == "material.boss_core"
        assert item["storage"] == "boss_core_fragments" and item["max_stack"] is None

completed, order, receipts, balance = set(), [], set(), Counter()
earned_journals, flags = set(), set()
while len(completed) < len(quests):
    available = [q for q in quests.values() if q["id"] not in completed
                 and set(q["requires_completed_quests"]) <= completed]
    assert len(available) == 1, "Cycle, unknown dependency, or ambiguous main route"
    quest = available[0]
    quest_id = quest["id"]
    assert quest["accept_npc"] in speakers and quest["turn_in_npc"] in speakers
    reward, turn_in = quest["first_clear_reward"], quest["turn_in"]
    assert reward["receipt_id"] == f'stage:{quest["stage_id"]}:first_clear'
    assert turn_in["receipt_id"] == f"quest:{quest_id}:turn_in"
    for receipt in (reward["receipt_id"], turn_in["receipt_id"]):
        assert receipt not in receipts
        receipts.add(receipt)
    for grant in reward["items"]:
        item_id, amount = grant["item_id"], grant["quantity"]
        assert item_id in items and type(amount) is int and amount > 0
        assert items[item_id]["source_stage_id"] == quest["stage_id"]
        assert items[item_id]["turn_in_quest_id"] == quest_id
        balance[item_id] += amount
        limit = items[item_id]["max_stack"]
        assert limit is None or balance[item_id] <= limit
    for cost in turn_in["costs"]:
        item_id, amount = cost["item_id"], cost["quantity"]
        assert item_id in items and type(amount) is int and amount > 0
        assert balance[item_id] >= amount, "Unreachable required item cost"
        balance[item_id] -= amount
    assert set(turn_in["journal_entries"]) <= set(journals)
    earned_journals.update(turn_in["journal_entries"])
    flags.update(turn_in["flags"])
    for kind, dialogue_id in quest["dialogues"].items():
        dialogue = dialogues[dialogue_id]
        assert dialogue["quest_id"] == quest_id and dialogue["kind"] == kind
        expected_npc = quest["turn_in_npc"] if kind == "turn_in" else quest["accept_npc"]
        assert dialogue["npc_id"] == expected_npc
    completed.add(quest_id)
    order.append(quest_id)

assert order[0] == data["initial_quest_id"]
assert not any(balance.values()), "Unassigned story item remains after chapter delivery"
assert earned_journals == set(journals)
assert flags == {data["completion_flag"]}

node_count = 0
command_counts = Counter()
for dialogue in dialogues.values():
    assert dialogue["npc_id"] in speakers
    assert isinstance(dialogue.get("location"), str) and dialogue["location"].strip()
    assert isinstance(dialogue.get("scene"), str) and dialogue["scene"] in {"radio", "outpost", "rift"}
    nodes = catalog(dialogue["nodes"])
    node_count += len(nodes)
    assert dialogue["entry"] in nodes
    for condition in dialogue["conditions"]:
        if condition["type"] == "quest_state":
            assert condition["quest_id"] in quests
            assert condition["value"] in {"available", "active", "ready_to_turn_in", "completed"}
        else:
            assert condition["type"] == "flag"
            assert condition["flag_id"] in flags and condition["value"] is True
    if dialogue["kind"] in {"accept", "reminder", "turn_in"}:
        expected_state = {"accept": "available", "reminder": "active", "turn_in": "ready_to_turn_in"}[dialogue["kind"]]
        assert dialogue["conditions"] == [{"type": "quest_state", "quest_id": dialogue["quest_id"], "value": expected_state}]
    edges, terminals = {}, set()
    for node_id, node in nodes.items():
        assert node["speaker"] in speakers and node["text"].strip()
        if "narration" in node:
            assert isinstance(node["narration"], str) and node["narration"].strip()
            assert len(node["narration"]) <= 40, "Environmental narration must stay brief"
        assert sum(key in node for key in ("next", "choices", "end")) == 1
        if "end" in node:
            assert node["end"] is True
            terminals.add(node_id)
        choices = node.get("choices", [])
        if "choices" in node:
            assert choices
        catalog(choices)
        edges[node_id] = [node["next"]] if "next" in node else [c["next"] for c in choices]
        assert set(edges[node_id]) <= set(nodes)
        for choice in choices:
            assert choice["text"].strip()
            if "command" not in choice:
                continue
            command = choice["command"]
            assert command["type"] in {"accept_quest", "turn_in_quest"}
            assert command["quest_id"] == dialogue["quest_id"]
            assert dialogue["kind"] == {"accept_quest": "accept", "turn_in_quest": "turn_in"}[command["type"]]
            command_counts[(command["quest_id"], command["type"])] += 1
    reachable, pending = set(), [dialogue["entry"]]
    while pending:
        node_id = pending.pop()
        if node_id not in reachable:
            reachable.add(node_id)
            pending.extend(edges[node_id])
    assert reachable == set(nodes), "Unreachable dialogue node"
    can_end = set(terminals)
    while True:
        expanded = can_end | {n for n, targets in edges.items() if set(targets) & can_end}
        if expanded == can_end:
            break
        can_end = expanded
    assert can_end == set(nodes), "Dialogue node cannot reach an exit"
    for start in nodes:
        seen, cursor = set(), start
        while "next" in nodes[cursor]:
            assert cursor not in seen, "Automatic dialogue cycle"
            seen.add(cursor)
            cursor = nodes[cursor]["next"]

for quest_id in quests:
    assert command_counts[(quest_id, "accept_quest")] == 1
    assert command_counts[(quest_id, "turn_in_quest")] == 1
print(json.dumps({
    "status": "STORY_CONTENT_CHECK_OK",
    "scope": "runtime_content_structure_reachability_and_item_budget",
    "stages": len(stages), "quests": len(quests), "speakers": len(speakers),
    "items": len(items), "dialogues": len(dialogues), "dialogue_nodes": node_count,
    "unique_reward_receipts": len(receipts), "quest_order": order,
}, ensure_ascii=False, indent=2))
