#!/usr/bin/env python3
"""Replay actual earned dash acquisition stages with frozen inputs."""
import argparse
import sys
import shutil
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SUITES = ('earned_dash_return',)
EXTRA_INPUTS = []


def freeze():
    names = subprocess.check_output(['git', 'ls-files', '-z', '--', 'godot', 'tools'], cwd=ROOT).decode().split('\0')
    names += EXTRA_INPUTS
    names += ['tools/run_earned_dash_return.py','tools/verify_earned_dash_proofs.py','godot/scripts/world_earned_dash_return_playback.gd','artifacts/t04_bishop_route/earned_bishop_seed.json']
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
            for name in sorted(set(names)) if name and (ROOT / name).is_file()}


def campaign(args):
    args.log_dir.mkdir(parents=True,exist_ok=True)
    original=ROOT/'artifacts/t04_bishop_route/earned_bishop_seed.json'
    incoming=None
    rows=[]
    for stage in range(1,6):
        folder=args.log_dir/f'stage_{stage}'
        command=[sys.executable,str(Path(__file__).resolve()),'--engine',args.engine,'--log-dir',str(folder),'--stage',str(stage)]
        if incoming:command += ['--input-save',str(incoming)]
        if stage==5:command += ['--proof-file',str(args.log_dir/'stage_4/stage-proof.json')]
        if args.native_gl:command += ['--native-gl']
        if args.verbose:command += ['--verbose']
        code=subprocess.run(command,cwd=ROOT).returncode
        verification=json.loads((folder/'verification.json').read_text(encoding='utf8'))
        rows.append(dict(stage=stage,passed=code==0 and verification['passed'],input_sha256=hashlib.sha256((incoming or original).read_bytes()).hexdigest(),output_sha256=hashlib.sha256((folder/'earned_save.json').read_bytes()).hexdigest() if (folder/'earned_save.json').exists() else None))
        if code!=0:break
        incoming=folder/'earned_save.json'
    passed=len(rows)==5 and all(row['passed'] for row in rows)
    if passed:
        seed=json.loads(original.read_text(encoding='utf8'))
        final=json.loads(incoming.read_text(encoding='utf8'))
        expected=dict(seed['inventory_counts'])
        for key,amount in {'heart_knot':1,'moss_chitin':3,'pollen_wax':1,'quiet_sole':1,'thread_dash':1}.items():expected[key]=expected.get(key,0)+amount
        passed=final['currency']==seed['currency']+32 and final['inventory_counts']==expected and final['build_state']==seed['build_state']
        shutil.copyfile(incoming,args.log_dir/'earned_dash_return_seed.json')
    (args.log_dir/'campaign.json').write_text(json.dumps(dict(passed=passed,stages=rows),indent=2)+'\n',encoding='utf8')
    return 0 if passed else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--log-dir', required=True, type=Path)
    parser.add_argument('--campaign', action='store_true')
    parser.add_argument('--proof-file', type=Path)
    parser.add_argument('--stage', type=int, default=1)
    parser.add_argument('--input-save', type=Path)
    parser.add_argument('--native-gl', action='store_true')
    parser.add_argument('--verbose', action='store_true')
    args = parser.parse_args()
    if args.campaign:
        return campaign(args)
    EXTRA_INPUTS.extend(str(p.resolve()) for p in [args.input_save,args.proof_file] if p)
    if args.stage > 1 and (not args.input_save or not args.input_save.is_file()):
        parser.error('later stages require the previous actual exported save')
    if hashlib.sha256((ROOT / 'artifacts/t04_bishop_route/earned_bishop_seed.json').read_bytes()).hexdigest() != 'f754c5ed76f8b0fa36caa2cd8166a74b20409f0421bf0ef469c9b18cc019d7f2':
        parser.error('normal bishop seed changed')
    args.log_dir.mkdir(parents=True, exist_ok=True)
    (args.log_dir / 'runner.py.txt').write_bytes(Path(__file__).read_bytes())
    (args.log_dir / 'source.diff').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD', '--', 'godot/scripts', 'godot/data', 'tools'], cwd=ROOT))
    for suite in set(SUITES):
        (args.log_dir / f'{suite}.gd.txt').write_bytes((ROOT / 'godot/scripts/world_earned_dash_return_playback.gd').read_bytes())
    if args.input_save:shutil.copyfile(args.input_save,args.log_dir/'input-save.json')
    if args.proof_file:shutil.copyfile(args.proof_file,args.log_dir/'input-proof.json')
    before = freeze()
    (args.log_dir / 'source-before.json').write_text(json.dumps(before, indent=2), encoding='utf-8')
    results = []
    with tempfile.TemporaryDirectory(prefix='ctp-exit-lifetime-') as scratch:
        env = dict(os.environ, APPDATA=scratch, XDG_DATA_HOME=scratch)
        for suite in SUITES:
            render = ['--position', '-32000,-32000', '--rendering-method', 'gl_compatibility'] if args.native_gl else ['--headless']
            command = [args.engine, *render, '--audio-driver', 'Dummy', '--fixed-fps', '60', *(['--verbose'] if args.verbose else []), '--path', str(ROOT / 'godot'), '--script', 'res://scripts/world_earned_dash_return_playback.gd']
            command += ['--', '--dash-stage='+str(args.stage), '--dash-export='+str((args.log_dir / 'earned_save.json').resolve())]
            if args.native_gl:command += ['--dash-captures='+str(args.log_dir.resolve())]
            if args.proof_file:command += ['--dash-proof='+str(args.proof_file.resolve())]
            if args.input_save:command += ['--dash-input='+str(args.input_save.resolve())]
            started = time.monotonic()
            timeout = False
            with (args.log_dir / f'{suite}.log').open('w', encoding='utf-8') as output:
                try:
                    code = subprocess.run(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=180).returncode
                except subprocess.TimeoutExpired:
                    code, timeout = None, True
            log = (args.log_dir / f'{suite}.log').read_text(encoding='utf-8', errors='replace')
            errors = len(re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:)', log, re.M))
            warnings = len(re.findall(r'^\s*WARNING:', log, re.M))
            marker = r'^WORLD_EARNED_DASH_RETURN stage=\d+ steps=\d+ failures=0 deaths=0.*$'
            completed = re.search(marker, log, re.M) is not None
            proofs=re.findall(r'^DASH_RETURN_STAGE_PROOF (.+)$',log,re.M)
            if proofs:(args.log_dir/'stage-proof.json').write_text(json.dumps(json.loads(proofs[-1]),indent=2)+'\n',encoding='utf-8')
            result = dict(suite=suite, command=command, exit=code, timeout=timeout, errors=errors, warnings=warnings, completed=completed, seconds=round(time.monotonic()-started, 3))
            results.append(result)
            print(json.dumps(result), flush=True)
    after = freeze()
    (args.log_dir / 'source-after.json').write_text(json.dumps(after, indent=2), encoding='utf-8')
    passed = before == after and all(r['exit'] == 0 and not r['timeout'] and not r['errors'] and not r['warnings'] and r['completed'] for r in results)
    (args.log_dir / 'verification.json').write_text(json.dumps(dict(passed=passed, source_equal=before == after, files=len(before), results=results), indent=2), encoding='utf-8')
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
