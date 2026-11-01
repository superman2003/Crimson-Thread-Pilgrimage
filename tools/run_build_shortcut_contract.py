#!/usr/bin/env python3
"""Fast native shortcut/protocol contracts; full World remains in integration."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = (
    'build_shortcut_contract_validation.gd', 'build_shortcut_validation.gd', 'build_shortcut_input.gd',
    'settings_profile_codec.gd', 'settings_profiles.gd', 'settings_profile_transfer.gd',
    'controller_preferences.gd', 'journey_desk_store.gd', 'input_binding_policy.gd',
    'input_prompt_bindings.gd', 'settings_persistence.gd', 'preference_file_transaction.gd',
)
MARKER = r'^BUILD_SHORTCUT_CONTRACT checks=[1-9][0-9]* failures=0$'
ERROR = re.compile(r'^\s*(?:ERROR|SCRIPT ERROR|USER ERROR|Parse Error):', re.M)
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')


def invoke(command, env, log, marker=None, timeout=120):
    def decoded(value):
        return value.decode('utf-8', errors='replace') if isinstance(value, bytes) else value or ''
    try:
        result = subprocess.run(command, env=env, capture_output=True, text=True,
                                encoding='utf-8', errors='replace', timeout=timeout)
        output = result.stdout + result.stderr
        passed = result.returncode == 0
    except subprocess.TimeoutExpired as error:
        output = decoded(error.stdout) + decoded(error.stderr)
        output += f'\nERROR: shortcut contract exceeded {timeout:g} seconds\n'
        passed = False
    log.write_text(output, encoding='utf-8')
    plain = ANSI.sub('', output)
    passed = passed and ERROR.search(plain) is None
    if marker is not None:passed = passed and re.search(marker, plain, re.M) is not None
    print(output, end='')
    return bool(passed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--log-dir', required=True, type=Path)
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if engine is None:parser.error('Godot executable is missing')
    args.log_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='crimson-build-shortcut-') as temporary:
        root = Path(temporary)
        project = root / 'project'
        scripts = project / 'scripts'
        scripts.mkdir(parents=True)
        for name in SCRIPTS:
            shutil.copy2(ROOT / 'godot/scripts' / name, scripts / name)
        (project / 'project.godot').write_text(
            'config_version=5\n[application]\nconfig/name="Build shortcut contract"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
        env = dict(os.environ, XDG_DATA_HOME=str(root / 'user'), APPDATA=str(root / 'user'),
                   XDG_CONFIG_HOME=str(root / 'config'), LOCALAPPDATA=str(root / 'local'))
        base = [engine, '--headless', '--audio-driver', 'Dummy', '--path', str(project)]
        if not invoke(base + ['--editor', '--recovery-mode', '--import', '--quit'], env,
                      args.log_dir / 'import.log'):return 1
        passed = invoke(base + ['--script', 'res://scripts/build_shortcut_contract_validation.gd'], env,
                        args.log_dir / 'contract.log', MARKER)
        return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
