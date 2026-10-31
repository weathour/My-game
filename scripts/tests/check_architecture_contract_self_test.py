#!/usr/bin/env python3
"""The architecture guard accepts formatting, but rejects extra business logic."""
from check_architecture_contract import delegates

CALL = "\tFLOW.handle(self, enemy)\n"
assert delegates("func on_defeat(enemy: Node) -> void:\n" + CALL, "on_defeat", CALL)
assert delegates("""func on_defeat(
    enemy: Node,
) -> void:
    # The coordinator owns this operation.
    FLOW.handle(
        self,
        enemy)

func unrelated():
    pass
""", "on_defeat", CALL)
assert not delegates("func on_defeat():\n\tpass\nfunc other():\n" + CALL, "on_defeat", CALL)
assert not delegates("func on_defeat():\n" + CALL + "\tgrant_reward()\n", "on_defeat", CALL)
assert not delegates("func on_defeat():\n\t# FLOW.handle(self, enemy)\n\tpass\n", "on_defeat", CALL)
print("ARCHITECTURE_CONTRACT_SELF_TEST_OK")
