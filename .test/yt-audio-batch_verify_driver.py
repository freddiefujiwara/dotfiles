#!/usr/bin/env python3
"""Driver for the yt-audio-batch tail-verification tests.

Not a standalone test: yt-audio-batch_test.bats runs this with a
scenario name and the path of the batch script. The batch module is
imported with yt-dlp and the range probe stubbed out, so the
verification logic and the cache/queue handling around it can be
checked without network access.

Scenarios:
  limited  tail probe answers 403 (the just-published-video case)
  good     tail probe answers 206
  nosize   first probe cannot report a total size (fail-open)
  tiny     small file whose last byte answers 206

Required environment: YT_AUDIO_HOME (scratch dir), and
YT_AUDIO_PUBLISH_PATH pointing inside it.
"""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
import subprocess
import sys
import types

VID = 'verify0000A'
URL = 'https://rr.invalid/videoplayback?dur=120.5'
TOTAL_BIG = 2000000
TOTAL_TINY = 300

PROBES = {
    'limited': {
        '0-0': (206, f'bytes 0-0/{TOTAL_BIG}'),
        f'{TOTAL_BIG - 1}-{TOTAL_BIG - 1}': (403, None),
    },
    'good': {
        '0-0': (206, f'bytes 0-0/{TOTAL_BIG}'),
        f'{TOTAL_BIG - 1}-{TOTAL_BIG - 1}': (
            206, f'bytes {TOTAL_BIG - 1}-{TOTAL_BIG - 1}/{TOTAL_BIG}'),
    },
    'nosize': {
        '0-0': (200, None),
    },
    'tiny': {
        '0-0': (206, f'bytes 0-0/{TOTAL_TINY}'),
        f'{TOTAL_TINY - 1}-{TOTAL_TINY - 1}': (
            206, f'bytes {TOTAL_TINY - 1}-{TOTAL_TINY - 1}/{TOTAL_TINY}'),
    },
}

EXPECTED_VERDICT = {'limited': False, 'good': True, 'nosize': None, 'tiny': True}


def load_module(batch_path):
    # The batch script has no .py suffix, so name the loader explicitly.
    loader = importlib.machinery.SourceFileLoader('yt_audio_batch', batch_path)
    spec = importlib.util.spec_from_loader('yt_audio_batch', loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def main():
    scenario = sys.argv[1]
    batch_path = sys.argv[2]
    home = os.environ['YT_AUDIO_HOME']
    os.makedirs(home, exist_ok=True)
    mod = load_module(batch_path)

    calls = []

    def fake_probe(url, range_spec):
        calls.append(range_spec)
        return PROBES[scenario][range_spec]

    mod._range_probe = fake_probe
    mod.find_ytdlp = lambda: 'fake-yt-dlp'

    def fake_run(*args, **kwargs):
        return types.SimpleNamespace(
            returncode=0, stdout=URL + '\n', stderr='')

    subprocess.run = fake_run

    # Unit level: the verdict and the exact probes issued.
    verdict = mod.verify_stream_url(URL)
    assert verdict is EXPECTED_VERDICT[scenario], (scenario, verdict)
    expected_calls = ['0-0'] if scenario == 'nosize' else [
        '0-0', f"{(TOTAL_TINY if scenario == 'tiny' else TOTAL_BIG) - 1}-"
               f"{(TOTAL_TINY if scenario == 'tiny' else TOTAL_BIG) - 1}"]
    assert calls == expected_calls, (scenario, calls)

    # Integration level: a full batch run over a one-item queue.
    queue = os.path.join(home, 'queue.tsv')
    cache_file = os.path.join(home, 'cache.json')
    publish_file = os.environ['YT_AUDIO_PUBLISH_PATH']
    with open(queue, 'w', encoding='utf-8') as f:
        f.write(f'1\t{VID}\n')
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        rc = mod.main()
    assert rc == 0
    cache = json.load(open(cache_file, encoding='utf-8'))
    published = json.load(open(publish_file, encoding='utf-8'))
    entry = cache.get(VID, {})

    if scenario == 'limited':
        assert 'verify_failed=1' in out.getvalue(), out.getvalue()
        assert 'url' not in entry, entry
        assert entry.get('error') == 'tail_range_unreachable', entry
        assert 'errorTs' not in entry, entry
        assert entry.get('verifyFails') == 1, entry
        assert VID not in published, published
        with open(queue, encoding='utf-8') as f:
            assert VID in f.read()
        # The next run re-extracts it (no ERR_TTL backoff) and the
        # consecutive-failure counter advances.
        with contextlib.redirect_stdout(io.StringIO()):
            rc = mod.main()
        assert rc == 0
        cache = json.load(open(cache_file, encoding='utf-8'))
        entry = cache.get(VID, {})
        assert 'url' not in entry, entry
        assert entry.get('verifyFails') == 2, entry
        assert 'errorTs' not in entry, entry
    else:
        assert entry.get('url') == URL, entry
        assert 'verifyFails' not in entry, entry
        assert published.get(VID, {}).get('url') == URL, published
        assert published[VID].get('dur') == 120.5, published

    print(f'{scenario}: OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
