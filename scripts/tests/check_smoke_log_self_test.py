#!/usr/bin/env python3
from check_smoke_log import FAULTS, validate

assert not validate("legacy", "LEGACY_SMOKE_OK\n")
assert not validate("legacy", "LEGACY_SMOKE: PASS\n")
assert not validate("legacy", "enemy_glutton_occlusion_smoke: PASS\n")
assert not validate("new", "NEW_SMOKE PASS checks=26 failures=0\n")
assert not validate("new", "NEW_SMOKE PASS failures=0\n")
assert not validate("new", "NEW_SMOKE PASS\n")
assert validate("new", "NEW_SMOKE PASS checks=26 failures=1\n")
assert validate("new", "SCRIPT ERROR: unexpected\nNEW_SMOKE PASS\n")
assert validate("new", "NEW_SMOKE FAIL 1\nNEW_SMOKE PASS\n")
assert validate("new", "Godot Engine\n")
for name, faults in FAULTS.items():
    for marker, error in faults.items():
        assert not validate(name, marker + "\n" + error + "\nSMOKE_OK\n")
        assert validate("another_test", marker + "\n" + error + "\nSMOKE_OK\n")
        assert validate(name, marker + "\nERROR: unrelated failure\nSMOKE_OK\n")
        assert validate(name, error + "\nSMOKE_OK\n")
        assert validate(name, marker + "\n" + error + "\nSCRIPT ERROR: unexpected\nSMOKE_OK\n")
print("SMOKE_LOG_SELF_TEST_OK")
