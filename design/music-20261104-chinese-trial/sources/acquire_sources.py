#!/usr/bin/env python3
"""Acquire the bounded trial bank, retain evidence, and inspect SF2 regions.

Only cache holds sample data. The repository receives hashes and metadata.
Requires requests; optional --export-wav writes mono PCM samples into cache.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import wave
import zipfile

import requests


CACHE = Path.home() / '.cache/my-game/chinese-instruments-20261104'
HERE = Path(__file__).resolve().parent
BANK = CACHE / 'DSK_Asian_DreamZ/DSK Asian DreamZ.SF2'
URL = 'https://rekkerd.org/samples/DSK_Asian_DreamZ_sf2.zip'
NAMES = {0: 'pipa', 1: 'pipa_trem', 2: 'luan', 3: 'guzhen',
         4: 'erhu', 5: 'ban_di', 6: 'chinese_percussion', 7: 'unused_duplicate'}
EVIDENCE = {
    'dsk-product.html': 'https://www.dskmusic.com/dsk-asian-dreamz/',
    'dsk-soundfont-distribution.html': 'https://rekkerd.org/dsk-soundfonts/',
    'berklee-pack.html': 'https://remix.berklee.edu/bisa-chinese-erhu/',
    'berklee-erhu-a4.html': 'https://remix.berklee.edu/bisa-chinese-erhu-oneshots-vibrato/7',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def session():
    result = requests.Session()
    result.trust_env = False
    result.headers['Accept-Encoding'] = 'gzip, deflate'
    # ALL_PROXY is deliberately ignored; never print proxy values.
    for scheme in ('http', 'https'):
        value = os.environ.get(scheme.upper() + '_PROXY') or os.environ.get(scheme + '_proxy')
        if value:
            result.proxies[scheme] = value
    return result


def acquire():
    CACHE.mkdir(parents=True, exist_ok=True)
    sess = session()
    archive = CACHE / 'DSK_Asian_DreamZ_sf2.zip'
    if not archive.exists():
        reply = sess.get(URL, timeout=45)
        reply.raise_for_status()
        if len(reply.content) > 20_000_000:
            raise ValueError('Unexpected archive size')
        archive.write_bytes(reply.content)
    with zipfile.ZipFile(archive) as archive_file:
        allowed = {'DSK Asian DreamZ.SF2', 'DSK Music - Readme.txt'}
        if set(archive_file.namelist()) != allowed:
            raise ValueError('Unexpected archive members')
        archive_file.extractall(BANK.parent)
    for name, url in EVIDENCE.items():
        path = CACHE / name
        if not path.exists():
            reply = sess.get(url, timeout=30)
            reply.raise_for_status()
            path.write_bytes(reply.content)


def inspect(export_wav=False):
    data = BANK.read_bytes()
    chunks = {}

    def scan(start, end):
        while start + 8 <= end:
            tag = data[start:start + 4]
            size = struct.unpack_from('<I', data, start + 4)[0]
            if tag in (b'RIFF', b'LIST'):
                scan(start + 12, start + 8 + size)
            else:
                chunks[tag] = data[start + 8:start + 8 + size]
            start += 8 + size + size % 2

    scan(0, len(data))
    def unpack(tag, fmt):
        return list(struct.iter_unpack(fmt, chunks[tag]))
    def name(value):
        return value.split(b'\0')[0].decode('latin1')
    ph = unpack(b'phdr', '<20sHHHIII')
    pb = unpack(b'pbag', '<HH')
    pg = unpack(b'pgen', '<HH')
    ih = unpack(b'inst', '<20sH')
    ib = unpack(b'ibag', '<HH')
    ig = unpack(b'igen', '<HH')
    sh = unpack(b'shdr', '<20sIIIII BbHH')
    samples = []
    for sid, row in enumerate(sh[:-1]):
        sample_name, start, end, ls, le, rate, root, correction, link, kind = row
        entry = dict(id=sid, name=name(sample_name), root=root, pitch_correction_cents=correction,
                     sample_rate=rate, frame_count=end-start, duration_seconds=(end-start)/rate,
                     loop_start_frames=ls-start, loop_end_frames=le-start,
                     sf2_sample_type=kind)
        if export_wav:
            wav = CACHE / 'dsk_wav' / f'{sid:02d}.wav'
            wav.parent.mkdir(exist_ok=True)
            with wave.open(str(wav), 'wb') as output:
                output.setparams((1, 2, rate, end-start, 'NONE', 'not compressed'))
                output.writeframes(chunks[b'smpl'][start*2:end*2])
            entry.update(wav_path=str(wav), wav_sha256=sha(wav))
        samples.append(entry)
    patches = []
    for pi, row in enumerate(ph[:-1]):
        patch_name, program, bank, bag_start, *_ = row
        regions = []
        for pbag_id in range(bag_start, ph[pi + 1][3]):
            preset_gen = dict(pg[pb[pbag_id][0]:pb[pbag_id + 1][0]])
            iid = preset_gen.get(41)
            if iid is None:
                continue
            for ibag_id in range(ih[iid][1], ih[iid+1][1]):
                gen = dict(ig[ib[ibag_id][0]:ib[ibag_id+1][0]])
                sid = gen.get(53)
                if sid is None:
                    continue
                key = gen.get(43, 32512)
                velocity = gen.get(44, 32512)
                regions.append(dict(sample_id=sid, key_low=key & 255, key_high=key >> 8,
                                    velocity_low=velocity & 255, velocity_high=velocity >> 8,
                                    root_override=gen.get(58), loop_mode=gen.get(54, 0),
                                    instrument_generators={str(k): v for k, v in gen.items()},
                                    preset_generators={str(k): v for k, v in preset_gen.items()}))
        roots = [r['root_override'] if r['root_override'] is not None else samples[r['sample_id']]['root'] for r in regions]
        patches.append(dict(id=NAMES[program], sf2_name=name(patch_name), bank=bank,
                            program_zero_based=program, sampled_root_range=[min(roots), max(roots)],
                            mapped_key_range=[min(r['key_low'] for r in regions), max(r['key_high'] for r in regions)],
                            use=program != 7, regions=regions))
    metadata = dict(schema_version=1, sf2_path=str(BANK), sf2_sha256=sha(BANK),
                    sf2_bytes=BANK.stat().st_size, generator_amount_encoding='raw unsigned 16-bit; signed operators use two-complement',
                    samples=samples, patches=patches)
    (HERE / 'dsk-regions.json').write_text(json.dumps(metadata, indent=2) + '\n')
    return metadata


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--offline', action='store_true')
    parser.add_argument('--export-wav', action='store_true')
    args = parser.parse_args()
    if not args.offline:
        acquire()
    result = inspect(args.export_wav)
    print(json.dumps({k: result[k] for k in ('sf2_path', 'sf2_sha256', 'sf2_bytes')}, indent=2))


if __name__ == '__main__':
    main()
