#!/usr/bin/env python3
"""Run isolated chapter probes; never edits the source project or save files."""
import argparse, json, pathlib, shutil, subprocess, tempfile

p = argparse.ArgumentParser()
p.add_argument('--godot', required=True)
p.add_argument('--project', required=True, type=pathlib.Path)
p.add_argument('--output', required=True, type=pathlib.Path)
p.add_argument('--prepared-project', type=pathlib.Path, help='Disposable, fully imported copy; skips copying/import')
p.add_argument('--modes', nargs='+', default=['entry', 'boss', 'boss_phase2'])
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)
probe = pathlib.Path(__file__).with_name('six_region_probe.gd')
with tempfile.TemporaryDirectory(prefix='six-region-review-') as temporary:
    project = a.prepared_project or pathlib.Path(temporary) / 'project'
    if not a.prepared_project:
        shutil.copytree(a.project, project, ignore=shutil.ignore_patterns('.godot'))
        subprocess.run([a.godot, '--headless', '--path', str(project), '--editor', '--import', '--quit'], check=True, stdout=subprocess.DEVNULL)
    shutil.copyfile(probe, project / probe.name)
    configs = sorted(project.glob('data/demo_ch0[1-6]*.json'), reverse=True)
    diagnostics = []
    for config in configs:
        if 'boss_trial' in config.name:
            continue
        for mode in a.modes:
            command = [a.godot, '--headless', '--path', str(project), '--fixed-fps', '60', '--script', 'res://six_region_probe.gd', '--', '--demo-config=res://data/' + config.name, '--probe-mode=' + mode]
            result = subprocess.run(command, capture_output=True, text=True, timeout=180)
            rows = [json.loads(s.removeprefix('REVIEW_JSON ')) for s in result.stdout.splitlines() if s.startswith('REVIEW_JSON ')]
            name = config.stem.split('_')[1] + '-' + mode
            (a.output / (name + '.jsonl')).write_text(''.join(json.dumps(r, ensure_ascii=False) + '\n' for r in rows))
            diagnostics.append({'run': name, 'exit': result.returncode, 'records': len(rows), 'ended': bool(rows and rows[-1]['event'] == 'end'), 'stderr': result.stderr})
            print(name, result.returncode, len(rows), flush=True)
    (a.output / ('diagnostics-' + '-'.join(a.modes) + '.json')).write_text(json.dumps(diagnostics, ensure_ascii=False, indent=2))
    if not all(d['exit'] == 0 and d['ended'] for d in diagnostics):
        raise SystemExit(1)
