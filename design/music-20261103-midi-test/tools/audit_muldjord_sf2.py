#!/usr/bin/env python3
"""Audit preset, key zones and sample names in the pinned FreePats SF2."""
import argparse, collections, hashlib, json, struct
from pathlib import Path
import mido

BASE=Path(__file__).resolve().parents[1]
GM_MAP={35:48,36:49,37:65,38:50,40:51,41:64,42:52,43:63,44:52,45:62,46:53,47:61,49:58,51:54,53:55,54:None,57:59}
ROLE={48:'kick left',49:'kick right',50:'snare',51:'snare',52:'closed hi-hat',53:'open hi-hat',54:'ride cymbal left',55:'ride bell left',56:'ride cymbal right',57:'ride bell right',58:'crash left',59:'crash right',60:'china cymbal',61:'rack tom 1',62:'rack tom 2',63:'rack tom 3',64:'floor tom',65:'snare rest / side-stick role',66:'snare rest / side-stick role'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def pdta_chunks(data):
 out={}; pos=0
 while pos+8<=len(data):
  tag=data[pos:pos+4]; size=struct.unpack_from('<I',data,pos+4)[0]; out[tag]=data[pos+8:pos+8+size]; pos+=8+size+(size&1)
 return out
def read_sf2(path):
 b=Path(path).read_bytes(); p=12; chunks={}
 while p+8<=len(b):
  tag=b[p:p+4]; size=struct.unpack_from('<I',b,p+4)[0]; d=p+8
  if tag==b'LIST' and b[d:d+4]==b'pdta': chunks=pdta_chunks(b[d+4:d+size])
  p=d+size+(size&1)
 def records(tag,size):return [chunks[tag][i:i+size] for i in range(0,len(chunks[tag]),size)]
 ph=records(b'phdr',38); pb=records(b'pbag',4); pg=records(b'pgen',4); ih=records(b'inst',22); ib=records(b'ibag',4); ig=records(b'igen',4); sh=records(b'shdr',46)
 presets=[]
 for i,row in enumerate(ph[:-1]):
  name=row[:20].split(b'\0')[0].decode(errors='replace'); preset,bank,bag=struct.unpack_from('<HHH',row,20); end=struct.unpack_from('<H',ph[i+1],24)[0]
  gens=[]
  for bi in range(bag,end):
   gs=struct.unpack_from('<H',pb[bi])[0]; ge=struct.unpack_from('<H',pb[bi+1])[0]; ops={}
   for j in range(gs,ge):
    op,amount=struct.unpack_from('<HH',pg[j]); ops[op]=amount
   if 41 in ops: gens.append(ops[41])
  presets.append({'name':name,'bank':bank,'program':preset,'instrument_indexes':gens})
 zones=collections.defaultdict(set)
 for i,row in enumerate(ih[:-1]):
  name=row[:20].split(b'\0')[0].decode(errors='replace'); first=struct.unpack_from('<H',row,20)[0]; stop=struct.unpack_from('<H',ih[i+1],20)[0]
  for bi in range(first,stop):
   gs=struct.unpack_from('<H',ib[bi])[0]; ge=struct.unpack_from('<H',ib[bi+1])[0]; ops={}
   for j in range(gs,ge):
    op,amount=struct.unpack_from('<HH',ig[j]); ops[op]=amount
   if 53 not in ops: continue
   kr=ops.get(43,0); lo=kr&255; hi=kr>>8; sample=ops[53]
   sn=sh[sample][:20].split(b'\0')[0].decode(errors='replace').removesuffix('_L').removesuffix('_R')
   for key in range(lo,hi+1): zones[key].add(sn)
 p0=next((p for p in presets if p['bank']==0 and p['program']==0),None)
 return b,presets,p0,zones
def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--sf2',required=True); ap.add_argument('--manifest',required=True); ap.add_argument('--out',required=True); a=ap.parse_args()
 sf,presets,preset,zones=read_sf2(a.sf2); manifest=json.load(open(a.manifest)); used=collections.Counter()
 for item in manifest['inputs']:
  local=Path(item['repo_midi_file']) if item.get('repo_midi_file') else BASE/'inputs'/f'midi_test_{item["index"]:02d}.mid'
  if not local.is_absolute(): local=BASE.parent.parent/local
  midi=mido.MidiFile(local)
  for tr in midi.tracks:
   for msg in tr:
    if msg.type=='note_on' and msg.velocity>0 and msg.channel==9: used[msg.note]+=1
 keyrows=[]
 for key in range(48,67): keyrows.append({'sf2_key':key,'role':ROLE[key],'sample_name_families':sorted(zones[key])})
 mapped={}
 for gm,n in sorted(used.items()):
  sk=GM_MAP.get(gm,gm)
  mapped[str(gm)]={'used_note_on_count':n,'muldjord_key':sk,'role':ROLE.get(sk,'unmapped'),'sample_names':sorted(zones[sk]) if sk is not None else [],'fallback':'GeneralUser GM tambourine' if sk is None else None}
 result={'status':'PASS' if preset and preset['name']=='MuldjordKit' else 'FAIL','sf2_path':str(Path(a.sf2).resolve()),'sf2_sha256':sha(a.sf2),'preset':preset,'presets':presets,'sample_zone_keys':sorted(zones),'sf2_keyzone_audit':keyrows,'source_used_gm_keys':mapped,'gm_to_sf2_map':GM_MAP,'interpretation':'GM source pitch and SF2 destination key are separate domains. Each destination sample name identifies the kit component used; e.g. source GM 40 maps to SF2 key 51, whose sample families are Snare, not hi-hat.'}
 Path(a.out).write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n'); print(json.dumps({'status':result['status'],'preset':preset,'used_gm_keys':len(used),'missing_muldjord_keys':[k for k,v in mapped.items() if v['muldjord_key'] is None]},ensure_ascii=False))
if __name__=='__main__':main()
