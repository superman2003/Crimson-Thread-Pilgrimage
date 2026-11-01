#!/usr/bin/env python3
"""Boot the actual MetSys EditorPlugin in isolated cold and warm editor projects.

No recovery mode and no runtime --script substitute: the real editor loads the
plugin and must emit its ready marker without engine errors before it exits.
"""
from __future__ import annotations
import argparse
from contextlib import nullcontext
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from software_gl import software_gl

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'godot/addons/MetroidvaniaSystem'
PROJECT = '''config_version=5
[application]
config/name="MetSysColdProbe"
[addons]
metroidvania_system/settings_file="res://MetSysSettings.tres"
[autoload]
MetSys="*res://addons/MetroidvaniaSystem/Nodes/Singleton.tscn"
[editor_plugins]
enabled=PackedStringArray("res://addons/MetroidvaniaSystem/plugin.cfg", "res://addons/MetroidvaniaSystem/EditorExtension/plugin.cfg")
[rendering]
renderer/rendering_method="gl_compatibility"
'''


def evaluate_output(phase: str, output: str, code: int | str) -> dict:
    clean = re.sub(r'\x1b\[[0-9;]*m', '', output)
    errors = re.findall(r'^\s*(?:SCRIPT )?ERROR:.*$', clean, re.M)
    leaks = re.findall(r'^WARNING:.*(?:ObjectDB|RID|resources still in use).*$', clean, re.M)
    ready = len(re.findall(r'^METSYS_EDITOR_READY$', clean, re.M))
    ready_ok = ready <= 1 if phase == 'early_exit' else ready == 1
    return {'phase': phase, 'returncode': code, 'engine_errors': errors,
            'lifetime_warnings': leaks, 'ready_count': ready,
            'passed': code == 0 and not errors and not leaks and ready_ok}


def run(engine: str, logs: Path, plugin_override: Path | None = None, verbose: bool = False, real_gl: bool = False) -> dict:
    logs.mkdir(parents=True, exist_ok=True)
    results = []
    with tempfile.TemporaryDirectory(prefix='metsys-cold-probe-') as temporary:
        project = Path(temporary) / 'project'
        shutil.copytree(ADDON, project / 'addons/MetroidvaniaSystem')
        for name in ['MetSysSettings.tres', 'MapData.txt']:
            shutil.copyfile(ROOT / 'godot' / name, project / name)
        (project / 'scenes').mkdir()
        (project / 'project.godot').write_text(PROJECT, encoding='utf-8')
        if plugin_override:
            shutil.copyfile(plugin_override, project / 'addons/MetroidvaniaSystem/MetSysPlugin.gd')
        assert not (project / '.godot').exists(), 'cold probe accidentally seeded with an import cache'
        env = dict(os.environ, APPDATA=str(Path(temporary) / 'user'),
                   XDG_DATA_HOME=str(Path(temporary) / 'user'),
                   XDG_CONFIG_HOME=str(Path(temporary) / 'config'),
                   XDG_CACHE_HOME=str(Path(temporary) / 'cache'))
        plugin = project / 'addons/MetroidvaniaSystem/MetSysPlugin.gd'
        plugin_sha = hashlib.sha256(plugin.read_bytes()).hexdigest()
        source_hashes = {p.relative_to(project).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in sorted(project.rglob('*')) if p.is_file()}
        display = software_gl(logs / 'display') if real_gl else nullcontext({})
        with display as renderer_env:
            env.update(renderer_env)
            for phase in ['cold', 'warm', 'early_exit']:
                renderer = ['--display-driver','x11','--audio-driver','Dummy','--rendering-method','gl_compatibility'] if real_gl else ['--headless']
                command = [engine, *renderer, '--editor', '--path', str(project), '--quit-after', '1' if phase == 'early_exit' else '240']
                if verbose:
                    command.append('--verbose')
                try:
                    result = subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                            timeout=90, encoding='utf-8', errors='replace')
                    output, code = result.stdout, result.returncode
                except subprocess.TimeoutExpired as error:
                    output = error.stdout or b''
                    if isinstance(output, bytes):
                        output = output.decode('utf-8', errors='replace')
                    code = 'timeout'
                (logs / (phase + '.log')).write_text(output, encoding='utf-8')
                results.append(evaluate_output(phase, output, code))
                if not results[-1]['passed']:
                    break
    report = {'plugin_sha256': plugin_sha, 'cache_seeded': False, 'recovery_mode': False,
              'runtime_script': False, 'real_gl': real_gl, 'sources_sha256': source_hashes,
              'cases': results, 'passed': len(results) == 3 and all(row['passed'] for row in results)}
    (logs / 'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--log-dir', type=Path, required=True)
    parser.add_argument('--plugin-override', type=Path, help='optional exact old plugin for a negative control')
    parser.add_argument('--verbose', action='store_true', help='retain Godot resource/lifetime diagnostics')
    parser.add_argument('--software-gl', action='store_true', help='boot the real GL editor using Xvfb/llvmpipe')
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if not engine:
        parser.error('Godot executable not found')
    report = run(engine, args.log_dir, args.plugin_override, args.verbose, args.software_gl)
    print('METSYS_COLD_IMPORT_' + ('PASS' if report['passed'] else 'FAIL') + ' ' +
          json.dumps(report['cases'], ensure_ascii=False))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
