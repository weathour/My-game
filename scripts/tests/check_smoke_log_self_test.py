#!/usr/bin/env python3
from check_smoke_log import FAULTS, validate

assert not validate("legacy", "LEGACY_SMOKE_OK\n")
assert not validate("legacy", "LEGACY_SMOKE: PASS\n")
assert not validate("legacy", "enemy_glutton_occlusion_smoke: PASS\n")
assert not validate("new", "NEW_SMOKE PASS checks=26 failures=0\n")
assert not validate("new", "NEW_SMOKE PASS failures=0\n")
assert not validate("new", "NEW_SMOKE PASS\n")
assert not validate("new", "NEW_SMOKE PASS checks=672 failures=0 authored_moves=30 sessions=18 routes=2 portrait_capture=/tmp/boss.png\n")
assert validate("new", "NEW_SMOKE PASS checks=26 failures=1\n")
assert validate("new", "NEW_SMOKE PASS checks=26 failures=0 failures=1\n")
assert validate("new", "NEW_SMOKE PASS checks=26 failures=0 failures=0\n")
assert validate("new", "NEW_SMOKE PASS checks=26 failures=0 note=FAIL\n")
assert validate("new", "NEW_SMOKE PASS checks=26 failures=0 note=SCRIPT_ERROR\n")
assert validate("new", "NEW_SMOKE PASS checks=26 failures=0 unstructured note\n")
assert validate("new", "NEW_SMOKE PASS checks=not-a-count failures=0\n")
assert validate("new", "NEW_SMOKE PASS checks=26 failures=bogus\n")
assert not validate("new", '{"outcome":"failed","failed_signals":0}\nNEW_SMOKE PASS checks=26 failures=0\n')
assert validate("new", "This is not a successful smoke result\n")
skill_notes = "MECHANIC_REAL_CAST_CONTRACT_OK: five skills\nACTIVE_SKILL_DISPATCH_CONTRACT_OK: 20 skills, four roles\n"
assert not validate("skill_manual_mode_smoke", skill_notes + "SKILL_MANUAL_MODE_SMOKE_OK\n")
assert validate("skill_manual_mode_smoke", skill_notes) == ["missing successful smoke result"]
assert validate("new", "SCRIPT ERROR: unexpected\nNEW_SMOKE PASS\n")
assert validate("new", "NEW_SMOKE FAIL 1\nNEW_SMOKE PASS\n")
assert validate("new", "Godot Engine\n")
for name, faults in FAULTS.items():
    for marker, error in faults.items():
        assert not validate(name, marker + "\n" + error + "\nSMOKE_OK\n")
        assert validate("another_test", marker + "\n" + error + "\nSMOKE_OK\n")
        assert validate(name, marker + "\nERROR: unrelated failure\nSMOKE_OK\n")
        assert validate(name, marker + "\nintervening output\n" + error + "\nSMOKE_OK\n")
        assert validate(name, marker + "\n" + error + "\n" + error + "\nSMOKE_OK\n")
        assert validate(name, error + "\nSMOKE_OK\n")
        assert validate(name, marker + "\n" + error + "\nSCRIPT ERROR: unexpected\nSMOKE_OK\n")
# A new campaign fault remains scoped to one exact marker/error pair.
campaign_name = "chronicle_character_campaign_smoke"
campaign_marker = "EXPECTED_FAULT_INJECTION: post-battle story save rejected"
campaign_error = "ERROR: Could not create directory: '/proc/character-campaign-story-write-rejected'."
assert not validate(campaign_name, campaign_marker + "\n" + campaign_error + "\nCHRONICLE_CHARACTER_CAMPAIGN_SMOKE PASS checks=44 failures=0\n")
assert validate(campaign_name, campaign_marker + "\n" + campaign_error.replace("write-rejected", "write-rejected-other") + "\nSMOKE_OK\n")
assert validate(campaign_name, campaign_marker + " (unexpected)\n" + campaign_error + "\nSMOKE_OK\n")
assert validate(campaign_name, campaign_marker + "\n" + campaign_error + "\n")
print("SMOKE_LOG_SELF_TEST_OK")
