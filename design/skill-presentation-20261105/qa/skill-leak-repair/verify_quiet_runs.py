#!/usr/bin/env python3
"""Three isolated, consecutive quiet runs of this specific exit-lifecycle repair."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
SCRIPT = ROOT / 'scripts/tests/chronicle_skill_presentation_smoke.gd'
sys.path.insert(0, str(ROOT / 'scripts/tests'))
from check_smoke_log import validate

fingerprint = hashlib.sha256(SCRIPT.read_bytes()).hexdigest()
records = []
for number in range(1, 4):
    assert hashlib.sha256(SCRIPT.read_bytes()).hexdigest() == fingerprint
    with tempfile.TemporaryDirectory(prefix='skill-exit-quiet-', dir='/tmp') as isolated:
        env = os.environ.copy()
        env['XDG_DATA_HOME'] = str(Path(isolated) / 'data')
        env['XDG_CONFIG_HOME'] = str(Path(isolated) / 'config')
        log = OUT / f'fixed-quiet-{number}.log'
        report = OUT / f'fixed-results-{number}.json'
        argv = ['/home/weathour/.local/bin/godot-4.6.2', '--headless', '--path', str(ROOT), '--script', str(SCRIPT), '--', f'--report={report.relative_to(ROOT)}']
        with log.open('w') as stream:
            result = subprocess.run(argv, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, check=False)
        content = log.read_text()
        problems = validate('chronicle_skill_presentation_smoke', content)
        if 'ObjectDB instances leaked' in content or 'resources still in use' in content:
            problems.append('exit leak diagnostic')
        payload = json.loads(report.read_text())
        records.append({'run': number, 'returncode': result.returncode, 'log': log.name, 'validator_errors': problems, 'checks': payload['checks'], 'failures': payload['failures'], 'abilities': payload['ability_rows_checked'], 'actors': payload['actors_checked'], 'verbose': False, 'lifecycle_trace_enabled': False, 'audio_teardown': payload.get('audio_teardown', {})})
        assert result.returncode == 0 and not problems and payload['checks'] == 3934 and payload['failures'] == 0, records[-1]
        print(json.dumps(records[-1]), flush=True)
assert hashlib.sha256(SCRIPT.read_bytes()).hexdigest() == fingerprint
(OUT / 'quiet-validation.json').write_text(json.dumps({'status': 'PASS', 'script_sha256': fingerprint, 'consecutive_quiet_runs': records}, indent=2) + '\n')
print('SKILL_EXIT_REPAIR_QUIET_3_OK', flush=True)
