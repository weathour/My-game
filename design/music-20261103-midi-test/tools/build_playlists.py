#!/usr/bin/env python3
"""Create per-cue and batch A/B/C playlists with paths relative to each list."""
import json, os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]; BASE=ROOT/'design/music-20261103-midi-test'
MAN=json.loads((BASE/'experiment-manifest.json').read_text())
batch=Path(MAN['inputs'][0]['existing_gm_comparison_report']).parent.parent
global_lines=['#EXTM3U']; c_only=['#EXTM3U']
for item in MAN['inputs']:
 folder=Path(item['existing_gm_comparison_report']).parent; title=item['title']; idx=item['index']
 pair=[('A - 原伴奏.mp3','A - 原伴奏'),('B - MIDI重放.mp3','B - MIDI重放'),('C - 游戏音色.mp3','C - 游戏音色')]
 lines=['#EXTM3U']
 for name,label in pair:
  p=folder/name
  if not p.is_file(): raise SystemExit(f'missing playlist item: {p}')
  lines += [f'#EXTINF:-1,{title} — {label}',name]
  rel=os.path.relpath(p,batch).replace(os.sep,'/')
  global_lines += [f'#EXTINF:-1,{idx:02d} {title} — {label}',rel]
 cpath=folder/'C - 游戏音色.mp3'; c_only += [f'#EXTINF:-1,{idx:02d} {title}',os.path.relpath(cpath,batch).replace(os.sep,'/')]
 (folder/'A-B-C对照播放.m3u8').write_text('\n'.join(lines)+'\n',encoding='utf-8')
(batch/'全部A-B-C对照播放.m3u8').write_text('\n'.join(global_lines)+'\n',encoding='utf-8')
(batch/'全部C音色试听.m3u8').write_text('\n'.join(c_only)+'\n',encoding='utf-8')
print(json.dumps({'songs':len(MAN['inputs']),'batch_abcs':str(batch/'全部A-B-C对照播放.m3u8'),'c_only':str(batch/'全部C音色试听.m3u8')},ensure_ascii=False))
