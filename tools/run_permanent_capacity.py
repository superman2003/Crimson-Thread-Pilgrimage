#!/usr/bin/env python3
"""Bounded, source-frozen capacity regression; private saves only."""
from pathlib import Path
import argparse, gzip, hashlib, json, os, re, subprocess, time
from run_godot_regressions import SUCCESS_MARKERS

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [p for p in (ROOT / 'godot').rglob('*')
           if p.is_file() and '.godot' not in p.relative_to(ROOT / 'godot').parts
           and p.suffix in {'.gd', '.json', '.tscn', '.tres', '.gdshader'}]
SOURCES += [Path(__file__).resolve(), ROOT / 'tools/run_godot_regressions.py',
            ROOT / 'tools/godot_suite_success_markers.json', ROOT / 'tools/test_regression_runner.py',
            ROOT / 'artifacts/t04_obsidian_route/earned_camp_seed.json']

def hashes():
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCES}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--suite', action='append')
    parser.add_argument('--component-only', action='store_true')
    args = parser.parse_args()
    output = (ROOT / args.output).resolve(); output.mkdir(parents=True, exist_ok=False)
    frozen = hashes(); (output / 'source_before.json').write_text(json.dumps(frozen, indent=2)+'\n', encoding='utf8')
    suites = args.suite or ['permanent_capacity']
    if not args.suite and not args.component_only:
        suites += ['permanent_capacity_world_pickup', 'permanent_capacity_world_restart']
    results = []
    for suite in suites:
        if suite.endswith('_restart') and not (output / 'earned_capacity_save.json').is_file():
            raise RuntimeError('cannot restart without a successful actual pickup save')
        command = [args.engine, '--path', str(ROOT / 'godot'), '--audio-driver', 'Dummy', '--fixed-fps', '60']
        command += ['--position', '-32000,-32000', '--rendering-method', 'gl_compatibility'] if args.native else ['--headless']
        script = 'permanent_capacity_world' if suite.startswith('permanent_capacity_world_') else suite
        command += ['--script', 'res://scripts/'+script+'_validation.gd', '--', '--output='+str(output)]
        if script == 'permanent_capacity_world': command += ['--capacity-phase='+suite.rsplit('_',1)[1]]
        start = time.monotonic(); timed_out = False
        private_appdata = output / 'private_appdata' / suite
        private_appdata.mkdir(parents=True)
        environment = dict(os.environ, APPDATA=str(private_appdata))
        try:
            process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180, env=environment)
            raw, code = process.stdout, process.returncode
        except subprocess.TimeoutExpired as ex:
            raw, code, timed_out = ex.stdout or b'', None, True
        (output / (suite+'.log')).write_bytes(raw)
        (output / (suite+'.log.gz')).write_bytes(gzip.compress(raw, mtime=0))
        log = raw.decode('utf8', errors='replace')
        clean = not any(token in log for token in ['ERROR:', 'SCRIPT ERROR:', 'WARNING:'])
        marker = (r'^PERMANENT_CAPACITY_WORLD phase='+suite.rsplit('_',1)[1]+r' checks=[1-9][0-9]* failures=0 pid=[1-9][0-9]*$'
                  if script == 'permanent_capacity_world' else SUCCESS_MARKERS[suite])
        completed = bool(re.search(marker, log.replace('\r\n','\n'), re.MULTILINE))
        results.append(dict(suite=suite, returncode=code, timeout=timed_out, clean=clean,
                            completed=completed, seconds=round(time.monotonic()-start,3)))
        print(json.dumps(results[-1]), flush=True)
        assert hashes() == frozen, 'frozen source changed while engine ran'
        if code != 0 or not clean or not completed or timed_out: break
    (output / 'source_after.json').write_text(json.dumps(hashes(),indent=2)+'\n',encoding='utf8')
    (output / 'result.json').write_text(json.dumps(dict(results=results,source_unchanged=hashes()==frozen),indent=2)+'\n',encoding='utf8')
    assert all(r['returncode']==0 and r['clean'] and r['completed'] and not r['timeout'] for r in results), results

if __name__ == '__main__': main()
