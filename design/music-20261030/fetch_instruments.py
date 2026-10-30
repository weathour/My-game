#!/usr/bin/env python3
"""Fetch only pinned CC0 instrument files; never place raw libraries in this repo.

Normal use: python3 fetch_instruments.py --instruments flute violin piano
The checked-in manifest is the authority. Downloads are atomically verified
against their upstream Git blob hash, and a local SHA256 receipt is written.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import urllib.parse

HERE = Path(__file__).resolve().parent
DEFAULT_CACHE = Path.home() / '.cache/my-game/music-instruments'
DEFAULT_MANIFEST = HERE / 'instrument-manifest.json'
GIT_LOCKS = {}
GIT_LOCK_GUARD = threading.Lock()


def apply_mapping_overrides(manifest):
    """Build effective local regions without editing pinned upstream files.

    The checked-in regions retain upstream values. Each reviewed exception is
    explicit, checked against that value, idempotent, and attached to the
    resulting region for render provenance. Fetch and render use this function.
    """
    if not manifest.get('local_mapping_overrides'):
        return manifest
    effective = copy.deepcopy(manifest)
    for override in effective['local_mapping_overrides']:
        regions = [region for region in effective['patches'][override['patch']]['regions']
                   if region['file'] == override['sample_file']]
        if len(regions) != 1:
            raise ValueError(f'Local mapping override must identify one region: {override["id"]}')
        region = regions[0]
        opcode = override['opcode']
        prior = region.get('local_mapping_override')
        if prior and prior['id'] == override['id'] and region.get(opcode) == override['local_value']:
            continue
        if region.get(opcode) != override['upstream_value']:
            raise ValueError(f'Upstream value changed under local override: {override["id"]}')
        region[opcode] = override['local_value']
        region['local_mapping_override'] = dict(override)
    return effective


def load_manifest(path=DEFAULT_MANIFEST):
    return apply_mapping_overrides(json.loads(Path(path).read_text()))


def git_blob_hash(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def checked_file(path, record):
    if not path.is_file() or path.stat().st_size != record['size']:
        return False
    data = path.read_bytes()
    if 'git_blob_sha1' in record:
        return git_blob_hash(data) == record['git_blob_sha1']
    return hashlib.sha256(data).hexdigest() == record['sha256']


def file_path(cache, key):
    relative = Path(key)
    if relative.is_absolute() or '..' in relative.parts:
        raise ValueError(f'Unsafe cache key: {key}')
    return cache / relative


def required_files(manifest, names):
    files = set()
    for name in names:
        if name not in manifest['instruments']:
            raise ValueError(f'Unknown instrument {name!r}')
        inst = manifest['instruments'][name]
        if inst.get('status') == 'unsupported':
            raise ValueError(f'{name}: {inst["reason"]}')
        for patch_id in inst.get('patches', {}).values():
            patches = patch_id if isinstance(patch_id, list) else [patch_id]
            for patch in patches:
                data = manifest['patches'][patch]
                files.add(data['mapping_file'])
                files.update(r['file'] for r in data['regions'])
    for source_id in {manifest['files'][key]['source'] for key in files}:
        files.update(manifest['sources'][source_id]['documentation_files'])
    return sorted(files)


def git_fallback(cache, key, record, source, temporary):
    """Fetch one pinned Git blob when a raw-file CDN/proxy request stalls."""
    source_id = record['source']
    with GIT_LOCK_GUARD:
        lock = GIT_LOCKS.setdefault(source_id, threading.Lock())
    with lock:
        directory = cache / 'git-fallback' / source_id
        directory.parent.mkdir(parents=True, exist_ok=True)
        if not directory.exists():
            command = ['git', 'clone', '--bare', '--filter=blob:none', '--depth', '1']
            if source.get('git_ref'):
                command += ['--branch', source['git_ref']]
            subprocess.run(command + [source['repository'] + '.git', str(directory)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=90)
        commit = source['commit']
        exists = subprocess.run(['git', '-C', str(directory), 'cat-file', '-e', commit + '^{commit}'],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if exists.returncode:
            subprocess.run(['git', '-C', str(directory), 'fetch', '--filter=blob:none', '--depth', '1',
                            'origin', commit], check=True, stdout=subprocess.DEVNULL,
                           stderr=subprocess.PIPE, timeout=90)
        with open(temporary, 'wb') as output:
            subprocess.run(['git', '-C', str(directory), 'cat-file', 'blob', record['git_blob_sha1']],
                           stdout=output, stderr=subprocess.PIPE, check=True, timeout=90)
    if not checked_file(Path(temporary), record):
        raise RuntimeError(f'Pinned Git blob integrity failure: {key}')


def fetch_one(cache, key, record, verify_only=False, source=None):
    path = file_path(cache, key)
    if not checked_file(path, record):
        if verify_only:
            raise RuntimeError(f'Missing or corrupt: {path}')
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix=path.name + '.', suffix='.part', dir=path.parent)
        os.close(fd)
        try:
            for attempt in range(2):
                # Some corporate/CDN proxies retain a failed raw request. Query
                # variation does not change the pinned content/hash authority.
                url = record['url'] + (f'?download={attempt}' if attempt else '')
                completed = subprocess.run(['curl', '-fsSL', '--connect-timeout', '10', '--max-time', '25',
                                            '--max-filesize', str(record['size'] + 1), '-o', temporary, url],
                                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                if completed.returncode == 0 and checked_file(Path(temporary), record):
                    break
            else:
                if source and source.get('repository') and record.get('git_blob_sha1'):
                    git_fallback(cache, key, record, source, temporary)
                else:
                    raise RuntimeError(f'Download failed after 2 pinned/hash-checked attempts: {key}')
            candidate = Path(temporary)
            if not checked_file(candidate, record):
                raise RuntimeError(f'Upstream size/hash mismatch: {key}')
            candidate.replace(path)
        finally:
            Path(temporary).unlink(missing_ok=True)
    return key, {'size': record['size'], 'git_blob_sha1': record.get('git_blob_sha1'),
                 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'url': record['url']}


def prepare_archives(manifest, cache, keys, verify_only):
    """One bounded archive download for sources without per-file URLs."""
    sources = {manifest['files'][key]['source'] for key in keys
               if manifest['files'][key].get('archive_member')}
    for source_id in sorted(sources):
        selected = [key for key in keys if manifest['files'][key]['source'] == source_id]
        if all(checked_file(file_path(cache, key), manifest['files'][key]) for key in selected):
            continue
        if verify_only:
            raise RuntimeError(f'{source_id}: archive files missing or corrupt')
        source = manifest['sources'][source_id]
        archives = cache / 'archives'
        archives.mkdir(parents=True, exist_ok=True)
        archive = archives / (source_id + '.7z')
        record = {'size': source['archive_size'], 'sha256': source['archive_sha256'], 'url': source['archive_url']}
        if not checked_file(archive, record):
            temporary = archive.with_suffix('.part')
            subprocess.run(['curl', '-fsSL', '--retry', '2', '--connect-timeout', '12', '--max-time', '120',
                            '--max-filesize', str(record['size'] + 1), '-o', str(temporary), record['url']], check=True)
            if not checked_file(temporary, record):
                temporary.unlink(missing_ok=True)
                raise RuntimeError(f'{source_id}: archive hash mismatch')
            temporary.replace(archive)
        extractor = (shutil.which('7z') or shutil.which('7zz') or
                     str(Path.home() / '.local/opt/my-game-audio/usr/lib/7zip/7z'))
        if not Path(extractor).is_file():
            raise RuntimeError('FreePats archive requires 7zip. Install/extract the official Ubuntu 7zip package locally.')
        with tempfile.TemporaryDirectory(prefix='extract-', dir=cache) as directory:
            subprocess.run([extractor, 'x', '-y', '-o' + directory, str(archive)],
                           check=True, stdout=subprocess.DEVNULL)
            for key in selected:
                record = manifest['files'][key]
                extracted = file_path(Path(directory), record['archive_member'])
                if not checked_file(extracted, record):
                    raise RuntimeError(f'Extracted file hash mismatch: {key}')
                destination = file_path(cache, key)
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(extracted, destination)


def fetch(manifest, cache, names, jobs=8, max_bytes=2_000_000_000, verify_only=False, file_keys=None):
    keys = sorted(set(file_keys)) if file_keys is not None else required_files(manifest, names)
    total = sum(manifest['files'][key]['size'] for key in keys)
    if total > max_bytes:
        raise ValueError(f'Selected library is {total:,} bytes; budget is {max_bytes:,}')
    print(f'{len(keys)} pinned files; {total / 1e6:.1f} MB selected', flush=True)
    cache.mkdir(parents=True, exist_ok=True)
    prepare_archives(manifest, cache, keys, verify_only)
    receipt_path = cache / 'download-receipt.json'
    receipt = json.loads(receipt_path.read_text()) if receipt_path.exists() else {}
    errors = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        futures = {pool.submit(fetch_one, cache, key, manifest['files'][key], verify_only,
                               manifest['sources'][manifest['files'][key]['source']]): key for key in keys}
        for index, future in enumerate(concurrent.futures.as_completed(futures), 1):
            try:
                key, result = future.result()
                receipt[key] = result
            except Exception as error:
                errors.append({'file': futures[future], 'error': str(error)})
            if index % 40 == 0 or index == len(keys):
                print(f'{index}/{len(keys)} checked; errors={len(errors)}', flush=True)
    # Each writer owns a unique temporary file; don't expose a partial receipt.
    with (cache / '.receipt.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        current = json.loads(receipt_path.read_text()) if receipt_path.exists() else {}
        current.update(receipt)
        fd, temporary = tempfile.mkstemp(prefix='receipt-', dir=cache)
        with os.fdopen(fd, 'w') as output:
            json.dump(current, output, ensure_ascii=False, indent=2)
            output.write('\n')
        Path(temporary).replace(receipt_path)
    if errors:
        (cache / 'download-errors.json').write_text(json.dumps(errors, indent=2) + '\n')
        raise RuntimeError(f'{len(errors)} downloads failed; rerun to repair; see {cache / "download-errors.json"}')
    return {'file_count': len(keys), 'total_bytes': total, 'instruments': names,
            'receipt': str(receipt_path)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument('--cache', type=Path, default=DEFAULT_CACHE)
    parser.add_argument('--instruments', nargs='+')
    parser.add_argument('--jobs', type=int, default=8)
    parser.add_argument('--max-bytes', type=int, default=2_000_000_000)
    parser.add_argument('--verify-only', action='store_true')
    parser.add_argument('--list', action='store_true')
    args = parser.parse_args()
    manifest = load_manifest(args.manifest)
    if args.list:
        for name, instrument in manifest['instruments'].items():
            print(f'{name:20s} {instrument["status"]:12s} {instrument.get("actual_name", instrument.get("reason", ""))}')
        return 0
    if args.jobs < 1 or args.jobs > 24 or args.max_bytes <= 0:
        parser.error('Use 1..24 jobs and a positive byte budget')
    names = args.instruments or [name for name, data in manifest['instruments'].items()
                                 if data['status'] != 'unsupported']
    try:
        print(json.dumps(fetch(manifest, args.cache, names, args.jobs, args.max_bytes,
                               args.verify_only), indent=2))
    except (ValueError, RuntimeError) as error:
        parser.exit(1, str(error) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
