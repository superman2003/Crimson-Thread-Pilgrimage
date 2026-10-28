#!/usr/bin/env python3
"""Run release receipt native contracts and real World integration."""
import argparse, os, re, shutil, subprocess, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
DEPS = ['scripts/build_receipt_inspector.gd', 'scripts/build_receipt_validation.gd']
MARKER = '^BUILD_RECEIPT checks=[1-9][0-9]* failures=0$'

def invoke(command, env, log, marker):
    try:
        result = subprocess.run(command, env=env, capture_output=True, text=True,
                                encoding='utf-8', errors='replace', timeout=120)
        output = result.stdout + result.stderr
        good = result.returncode == 0
    except subprocess.TimeoutExpired as error:
        output = ''
        for chunk in (error.stdout, error.stderr):
            if chunk: output += chunk.decode(errors='replace') if isinstance(chunk, bytes) else chunk
        output += '\nERROR: native fixture timeout\n'
        good = False
    log.write_text(output, encoding='utf-8')
    plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', output)
    print(output, end='')
    fatal = r'(?:^\s*(?:SCRIPT ERROR|ERROR|USER ERROR):|ObjectDB instances leaked|Resources still in use|Unicode parsing error)'
    return bool(good and re.search(marker, plain, re.M) and not re.search(fatal, plain, re.M))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--world', action='store_true', help='Run actual World ownership and save isolation through the strict shared runner')
    parser.add_argument('--log-dir', type=Path, required=True)
    args = parser.parse_args()
    args.log_dir.mkdir(parents=True, exist_ok=True)
    if args.world:
        from run_godot_regressions import run_suites, SUCCESS_MARKERS
        marker = '^BUILD_RECEIPT_WORLD checks=[1-9][0-9]* failures=0$'
        if 'build_receipt_world' in SUCCESS_MARKERS and SUCCESS_MARKERS['build_receipt_world'] != marker:
            raise ValueError('conflicting build-receipt World completion contract')
        SUCCESS_MARKERS['build_receipt_world'] = marker
        engine = shutil.which(args.engine)
        if not engine:
            parser.error('Godot executable missing')
        with tempfile.TemporaryDirectory(prefix='build-receipt-world-') as temporary:
            failures = run_suites(engine, ['build_receipt_world'], None, args.log_dir, Path(temporary), False, {})
        return 1 if failures else 0
    with tempfile.TemporaryDirectory(prefix='crimson-reliability-') as temporary:
        base = Path(temporary)
        project = base / 'project'; project.mkdir()
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Release receipt"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for name in DEPS:
            target = project/name;target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT/'godot'/name, target)
        from build_release import package_directory
        payload=base/'payload';payload.mkdir()
        (payload/'game.bin').write_bytes(b'release-fixture-'*65536)
        (payload/'LICENSE.txt').write_text('source notice\n',encoding='utf-8')
        (payload/'empty.txt').write_bytes(b'')
        package_directory(payload,base/'candidate.zip',{'schema_version':1,'source_commit':'a'*40,'source_dirty':False,'target':'linux','engine':'4.6.1.stable.native-contract','qualification':'candidate; not a gameplay acceptance','validation':['source-inputs','archive-integrity']})
        env = dict(os.environ, CRIMSON_RECEIPT_FIXTURE=str(payload), XDG_DATA_HOME=str(base/'userdata'), APPDATA=str(base/'userdata'), GODOT_SILENCE_ROOT_WARNING='1')
        command = [args.engine, '--headless', '--audio-driver', 'Dummy', '--path', str(project), '--script', 'res://scripts/build_receipt_validation.gd']
        return 0 if invoke(command, env, args.log_dir/'native.log', MARKER) else 1
if __name__=='__main__':raise SystemExit(main())
