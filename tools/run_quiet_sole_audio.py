#!/usr/bin/env python3
"""Bounded quiet-sole fixture audio diagnostics with reversible source controls."""
from pathlib import Path
import argparse, gzip, hashlib, json, os, re, subprocess, time

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'artifacts/t03_quiet_sole_audio'
FIXTURE = ROOT / 'godot/scripts/quiet_sole_traps_validation.gd'
MAIN = ROOT / 'godot/scripts/main_level.gd'
SOURCES = ['godot/scripts/quiet_sole_traps_validation.gd', 'godot/scripts/main_level.gd',
           'godot/scripts/player_controller.gd', 'godot/scripts/build_system.gd',
           'godot/data/build_catalog.json', 'godot/scripts/audio_retirement.gd',
           'godot/scripts/audio_director.gd', 'godot/tests/fixtures/quiet_sole_earned_return.json',
           'tools/run_quiet_sole_audio.py']

def hashes():
    return {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in SOURCES}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--legacy-hazard', action='store_true')
    parser.add_argument('--skip-capture', action='store_true')
    args = parser.parse_args()
    output = (ROOT / args.output).resolve(); output.mkdir(parents=True, exist_ok=False)
    saved_fixture, saved_main = FIXTURE.read_bytes(), MAIN.read_bytes()
    try:
        if args.baseline:
            FIXTURE.write_bytes(gzip.decompress((BASE / 'original_quiet_sole_traps_validation.gd.gz').read_bytes()))
        if args.legacy_hazard:
            needle = b'return clampf(float(profile.get("hazard_trigger_mult", 1.0)), 0.5, 1.0)'
            assert MAIN.read_bytes().count(needle) == 1
            MAIN.write_bytes(MAIN.read_bytes().replace(needle, b'return 1.0'))
        before = hashes()
        (output / 'before.json').write_text(json.dumps(before,indent=2)+'\n',encoding='utf8')
        for source in [FIXTURE, MAIN]:
            (output / (source.name+'.gz')).write_bytes(gzip.compress(source.read_bytes(),mtime=0))
        private = output / 'private_appdata'; private.mkdir()
        environment = dict(os.environ, APPDATA=str(private), XDG_DATA_HOME=str(private))
        command = [args.engine, '--path', str(ROOT/'godot'), '--audio-driver', 'Dummy', '--fixed-fps', '60', '--verbose']
        command += ['--position','-32000,-32000','--rendering-method','gl_compatibility'] if args.native else ['--headless']
        command += ['--script','res://scripts/quiet_sole_traps_validation.gd']
        if args.skip_capture: command += ['--','--skip-fixture-audio-retirement']
        start = time.monotonic(); timed_out = False
        try:
            process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180, env=environment)
            raw, code = process.stdout, process.returncode
        except subprocess.TimeoutExpired as ex:
            raw, code, timed_out = ex.stdout or b'', None, True
        (output/'runtime.log.gz').write_bytes(gzip.compress(raw,mtime=0))
        after = hashes(); (output/'after.json').write_text(json.dumps(after,indent=2)+'\n',encoding='utf8')
        assert before == after, 'active source changed during the subprocess'
        text = raw.decode('utf8',errors='replace').replace('\r\n','\n')
        marker = re.search(r'^QUIET_SOLE_TRAPS checks=(\d+) failures=(\d+)$',text,re.MULTILINE)
        result = dict(command=command,exit=code,timeout=timed_out,seconds=round(time.monotonic()-start,3),
                      checks=int(marker[1]) if marker else None,failures=int(marker[2]) if marker else None,
                      errors=text.count('ERROR:'),warnings=text.count('WARNING:'),source_unchanged=True,
                      baseline=args.baseline,legacy_hazard=args.legacy_hazard,skip_capture=args.skip_capture)
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
        print(json.dumps(result),flush=True)
        assert not timed_out and marker and result['errors']==0
        if args.legacy_hazard or args.skip_capture:
            assert code==1 and result['failures']>0
        else:
            assert code==0 and result['failures']==0
        if not args.baseline and not args.skip_capture: assert result['warnings']==0
    finally:
        FIXTURE.write_bytes(saved_fixture); MAIN.write_bytes(saved_main)
        assert FIXTURE.read_bytes()==saved_fixture and MAIN.read_bytes()==saved_main

if __name__ == '__main__': main()
