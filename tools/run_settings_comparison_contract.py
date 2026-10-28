#!/usr/bin/env python3
"""Run saved profile comparison native contracts and real World integration."""
import argparse, os, re, shutil, subprocess, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
DEPS = ['scripts/settings_profile_comparison.gd', 'scripts/settings_comparison_validation.gd']
MARKER = '^SETTINGS_COMPARISON checks=[1-9][0-9]* failures=0$'

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
        marker = '^SETTINGS_COMPARISON_WORLD checks=[1-9][0-9]* failures=0$'
        if 'settings_comparison_world' in SUCCESS_MARKERS and SUCCESS_MARKERS['settings_comparison_world'] != marker:
            raise ValueError('conflicting settings-comparison World completion contract')
        SUCCESS_MARKERS['settings_comparison_world'] = marker
        engine = shutil.which(args.engine)
        if not engine:
            parser.error('Godot executable missing')
        with tempfile.TemporaryDirectory(prefix='settings-comparison-world-') as temporary:
            failures = run_suites(engine, ['settings_comparison_world'], None, args.log_dir, Path(temporary), False, {})
        return 1 if failures else 0
    with tempfile.TemporaryDirectory(prefix='crimson-reliability-') as temporary:
        base = Path(temporary)
        project = base / 'project'; project.mkdir()
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Thread action budget"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        queue=list(DEPS); seen=set()
        while queue:
            name=queue.pop()
            if name in seen:continue
            seen.add(name)
            source=ROOT/'godot'/name
            target=project/name;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,target)
            text=source.read_text(encoding='utf-8')
            queue.extend(re.findall(r"(?:preload|load)\(\s*['\"]res://([^'\"]+)['\"]\s*\)",text))
            queue.extend(re.findall(r"^\s*extends\s+['\"]res://([^'\"]+)['\"]",text,re.M))
        env = dict(os.environ, XDG_DATA_HOME=str(base/'userdata'), APPDATA=str(base/'userdata'), GODOT_SILENCE_ROOT_WARNING='1')
        command = [args.engine, '--headless', '--audio-driver', 'Dummy', '--path', str(project), '--script', 'res://scripts/settings_comparison_validation.gd']
        return 0 if invoke(command, env, args.log_dir/'native.log', MARKER) else 1
if __name__=='__main__':raise SystemExit(main())
