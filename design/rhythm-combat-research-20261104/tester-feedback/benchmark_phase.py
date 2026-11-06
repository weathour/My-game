"""Cold and cached build latency on the12 fixed D2 inputs; no Qt/UI clock."""
import json,time,sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT))
from tools.rhythm_tester.analysis import parse_midi,build_plan
rows=[]
for path in sorted((ROOT/'design/music-20261104-chinese-12/arrangements').glob('*/D2.mid')):
 start=time.perf_counter();data=parse_midi(path);parse_ms=(time.perf_counter()-start)*1000
 start=time.perf_counter();cold=build_plan(data);cold_ms=(time.perf_counter()-start)*1000
 timings=[]
 for i in range(20):
  start=time.perf_counter();warm=build_plan(data,layer=(.5,1.,2.)[i%3],phase=(0.,.5)[i%2]);timings.append((time.perf_counter()-start)*1000)
 baseline=build_plan(data)
 assert np.array_equal(cold.times,baseline.times) and cold.metadata==baseline.metadata
 rows.append({'cue_id':path.parent.name,'note_count':len(data.notes),'parse_ms':parse_ms,'cold_build_ms':cold_ms,'cached_median_ms':float(np.median(timings)),'cached_max_ms':max(timings),'candidates':len(cold.metadata['candidate_rankings']),'rate':cold.metadata['selected_rate'],'phase':cold.metadata['selected_phase']})
report={'method':'perf_counter within already imported Python process; one cold build +20 cached modifier applications per parsed MIDI','rows':rows,'max_cold_ms':max(r['cold_build_ms'] for r in rows),'max_cached_ms':max(r['cached_max_ms'] for r in rows),'cache_policy':'MidiData intrinsic notes/tempo/trim key; detached ranking rows; no layer/phase state in cache','scope':'local engineering latency, not perceptual quality or a universal device guarantee'}
Path(__file__).with_name('build-latency.json').write_text(json.dumps(report,indent=2)+'\n')
print('BUILD_LATENCY',report['max_cold_ms'],report['max_cached_ms'])
