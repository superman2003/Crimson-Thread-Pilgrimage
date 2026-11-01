"""Launch the actual project main scene, then close only its own Windows HWND."""
import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
DIRECT = ['godot/project.godot', 'godot/scripts/main_level.gd',
          'godot/scripts/application_close.gd', 'godot/scripts/application_close_validation.gd',
          'godot/scripts/audio_retirement.gd', 'godot/scripts/audio_director.gd',
          'tools/probe_project_close.py']

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--immediate-install', action='store_true', help='Run the published 44ffc125 immediate owner installation as a controlled negative.')
    args = parser.parse_args()
    if os.name != 'nt':
        parser.error('Windows WM_CLOSE is required')
    source = ROOT / 'godot/scripts/application_close.gd'
    original = source.read_bytes()
    try:
        if args.immediate_install:
            source.write_bytes(subprocess.check_output(['git', 'show', '44ffc12593cfaf10303451b0cee2ef77ce658a29:godot/scripts/application_close.gd'], cwd=ROOT))
        return run(args)
    finally:
        if args.immediate_install:
            source.write_bytes(original)

def run(args):
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    private = Path(tempfile.mkdtemp(prefix='ctp-project-close-'))
    names = subprocess.check_output(['git', 'ls-files', '-z', '--', 'godot', 'tools'], cwd=ROOT).decode().split('\0')
    names += DIRECT
    def freeze():
        return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sorted(set(names)) if name and (ROOT / name).is_file()}
    before = freeze()
    for name in DIRECT:
        dest = out / 'inputs' / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes((ROOT / name).read_bytes())
    (out / 'source-before.json').write_text(json.dumps(before, indent=2), encoding='utf-8')
    # Deliberately no --script: Godot itself loads project.godot's World main scene.
    command = [args.engine, '--path', str(ROOT / 'godot'), '--position', '-32000,-32000',
               '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--fixed-fps', '60', '--verbose']
    user32 = ctypes.WinDLL('user32', use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user32.EnumWindows.argtypes = [callback_type, wintypes.LPARAM]
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.IsWindowVisible.argtypes = [wintypes.HWND]
    user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    start = time.monotonic()
    marker_time = None
    proc = None
    hwnd = None
    posted = False
    error = None
    try:
        with (out / 'project.log').open('wb') as output:
            proc = subprocess.Popen(command, cwd=ROOT, env=dict(os.environ, APPDATA=str(private), XDG_DATA_HOME=str(private)), stdout=output, stderr=subprocess.STDOUT)
            while proc.poll() is None and time.monotonic() - start < 180:
                raw = (out / 'project.log').read_bytes()
                # Existing production exploration toast; no injected fixture readiness.
                if b' / Tab ' in raw and marker_time is None:
                    marker_time = time.monotonic()
                if marker_time is not None and time.monotonic() - marker_time >= .1 and not posted:
                    windows = []
                    @callback_type
                    def collect(window, _):
                        pid = wintypes.DWORD()
                        user32.GetWindowThreadProcessId(window, ctypes.byref(pid))
                        if pid.value == proc.pid and user32.IsWindowVisible(window):
                            windows.append(window)
                        return True
                    user32.EnumWindows(collect, 0)
                    if len(windows) != 1:
                        raise RuntimeError(f'Owned PID {proc.pid} has {len(windows)} visible windows')
                    hwnd = windows[0]
                    if not user32.PostMessageW(hwnd, 0x0010, 0, 0):
                        raise ctypes.WinError(ctypes.get_last_error())
                    posted = True
                time.sleep(.025)
            if proc.poll() is None:
                raise TimeoutError('Owned actual-project process exceeded 180 seconds')
    except Exception as exc:
        error = repr(exc)
    finally:
        if proc is not None and proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=10)
    raw = (out / 'project.log').read_bytes()
    log = raw.decode('utf-8', errors='replace')
    after = freeze()
    (out / 'source-after.json').write_text(json.dumps(after, indent=2), encoding='utf-8')
    retirements = [list(map(int, values)) for values in re.findall(r'AUDIO_RETIREMENT pending=0 elapsed_msec=(\d+) observed=(\d+) retired=(\d+)', log)]
    private_logs = [str(path.relative_to(private)) for path in private.rglob('godot.log')]
    result = dict(command=command, pid=None if proc is None else proc.pid, hwnd=hwnd, exit=None if proc is None else proc.returncode,
        immediate_install=args.immediate_install, posted=posted, exploration_toast=marker_time is not None,
        private_appdata=str(private), private_engine_logs=private_logs, source_equal=before == after, source_count=len(before),
        retirements=retirements, errors=len(re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:)', log, re.M)),
        warnings=len(re.findall(r'^\s*WARNING:', log, re.M)), close_completions=log.count('APPLICATION_CLOSE drained=true pending=0'),
        log_sha256=hashlib.sha256(raw).hexdigest(), seconds=round(time.monotonic()-start, 3), error=error)
    result['passed'] = error is None and posted and result['exit'] == 0 and before == after and bool(private_logs) and not result['errors'] and not result['warnings'] and result['close_completions'] == 1 and any(observed > 0 and retired > 0 for _, observed, retired in retirements)
    (out / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result), flush=True)
    return 0 if result['passed'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
