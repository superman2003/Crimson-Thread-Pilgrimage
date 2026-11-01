#!/usr/bin/env python3
"""Run production GDScript in a small isolated native Godot project."""
import argparse, os, re, shutil, subprocess, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
DEPS = ['scripts/'+name for name in ['settings_persistence.gd','preference_file_transaction.gd','journal_mark_store.gd','journal_mark_transaction.gd','journal_mark_validation.gd']]
MARKER = '^JOURNAL_MARKS checks=[1-9][0-9]* failures=0$'

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
        marker = '^JOURNAL_MARKS_WORLD checks=[1-9][0-9]* failures=0$'
        if 'journal_mark_world' in SUCCESS_MARKERS and SUCCESS_MARKERS['journal_mark_world'] != marker:
            raise ValueError('conflicting journal-mark World completion contract')
        SUCCESS_MARKERS['journal_mark_world'] = marker
        engine = shutil.which(args.engine)
        if not engine:
            parser.error('Godot executable missing')
        with tempfile.TemporaryDirectory(prefix='journal-mark-world-') as temporary:
            failures = run_suites(engine, ['journal_mark_world'], None, args.log_dir, Path(temporary), False, {})
        return 1 if failures else 0
    with tempfile.TemporaryDirectory(prefix='crimson-reliability-') as temporary:
        base = Path(temporary)
        project = base / 'project'; project.mkdir()
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Journal reading marks"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for name in DEPS:
            target = project/name;target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT/'godot'/name, target)
        env = dict(os.environ, XDG_DATA_HOME=str(base/'userdata'), APPDATA=str(base/'userdata'), GODOT_SILENCE_ROOT_WARNING='1')
        command = [args.engine, '--headless', '--audio-driver', 'Dummy', '--path', str(project), '--script', 'res://scripts/journal_mark_validation.gd']
        phases = [('native', [], MARKER),
                  ('seed', ['--', '--seed'], '^JOURNAL_MARKS_SEED checks=[1-9][0-9]* failures=0$'),
                  ('reload', ['--', '--reload'], '^JOURNAL_MARKS_RELOAD checks=[1-9][0-9]* failures=0$')]
        for name, extra, marker in phases:
            if not invoke(command+extra, env, args.log_dir/(name+'.log'), marker):return 1
        return 0
if __name__=='__main__':raise SystemExit(main())
