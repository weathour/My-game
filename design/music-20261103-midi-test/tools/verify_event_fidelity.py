#!/usr/bin/env python3
"""Compare renderer event logs to frozen MIDI note-on/off pairs exactly."""
import argparse, collections, hashlib, json
from pathlib import Path
import mido

def sha(p):
 h=hashlib.sha256();
 with open(p,'rb') as f:
  for b in iter(lambda:f.read(1<<20),b''): h.update(b)
 return h.hexdigest()

def source_events(path):
 mf=mido.MidiFile(path); out=[]
 for ti,tr in enumerate(mf.tracks):
  name=next((m.name for m in tr if m.type=='track_name'),f'track_{ti+1}')
  tick=0; active=collections.defaultdict(collections.deque); notes=[]
  for m in tr:
   tick+=m.time
   if m.type=='note_on' and m.velocity:
    active[(m.channel,m.note)].append((tick,m.velocity))
   elif m.type=='note_off' or (m.type=='note_on' and not m.velocity):
    q=active[(m.channel,m.note)]
    if q:
     st,v=q.popleft(); notes.append((m.channel,m.note,v,st,tick))
  for (ch,p),q in active.items():
   while q:
    st,v=q.popleft(); notes.append((ch,p,v,st,tick))
  if notes: out.append((ti,name,notes))
 return out

def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--midi',type=Path,required=True); ap.add_argument('--report',type=Path,required=True); ap.add_argument('--expected-sha256'); a=ap.parse_args()
 h=sha(a.midi)
 if a.expected_sha256 and h!=a.expected_sha256: raise SystemExit(f'SOURCE_HASH_MISMATCH {h}')
 report=json.loads(a.report.read_text());
 if report['source_midi_sha256']!=h: raise SystemExit('REPORT_SOURCE_HASH_MISMATCH')
 actual={(x['track_index'],x['name']):[(n['channel'],n['pitch'],n['velocity'],n['start_tick'],n['end_tick']) for n in x['events']] for x in report['tracks']}
 expected={(i,n):[(e[0],e[1],e[2],e[3],e[4]) for e in notes] for i,n,notes in source_events(a.midi)}
 if actual.keys()!=expected.keys(): raise SystemExit(f'TRACK_SET_MISMATCH expected={expected.keys()} actual={actual.keys()}')
 for key in expected:
  if collections.Counter(actual[key])!=collections.Counter(expected[key]): raise SystemExit(f'NOTE_EVENT_MISMATCH track={key}')
 print(json.dumps({'status':'pass','source_sha256':h,'tracks':len(expected),'note_events':sum(map(len,expected.values()))},ensure_ascii=False))
if __name__=='__main__':main()
