"""Post WM_CLOSE only to a newly owned Godot PID after real World readiness."""
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

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--close-at', choices=('ready', 'paused', 'startup'), default='ready')
    parser.add_argument('--repeat-close', action='store_true')
    parser.add_argument('--legacy-close', action='store_true', help='Run the same fixture with only the new Main installation removed, then restore exact bytes.')
    args = parser.parse_args()
    if os.name != 'nt':
        parser.error('This probe exercises the Windows WM_CLOSE boundary.')
    main_path = ROOT / 'godot/scripts/main_level.gd'
    original = main_path.read_bytes()
    try:
        if args.legacy_close:
            installation = b'    preload("res://scripts/application_close.gd").install(get_tree())\n'
            if original.count(installation) != 1:
                raise RuntimeError('Cannot isolate the exact production close installation')
            main_path.write_bytes(original.replace(installation, b'', 1))
        return run(args)
    finally:
        if args.legacy_close:
            main_path.write_bytes(original)

def run(args):
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    private = Path(tempfile.mkdtemp(prefix='ctp-wm-close-'))
    names = subprocess.check_output(['git', 'ls-files', '-z', '--', 'godot', 'tools'], cwd=ROOT).decode().split('\0')
    direct = ['godot/scripts/main_level.gd', 'godot/scripts/application_close.gd',
              'godot/scripts/application_close_validation.gd', 'godot/scripts/window_close_probe.gd',
              'tools/probe_window_close.py', 'tools/run_godot_regressions.py',
              'tools/test_regression_runner.py', 'tools/godot_suite_success_markers.json']
    names += direct
    def freeze():
        return {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sorted(set(names)) if p and (ROOT / p).is_file()}
    before = freeze()
    (out / 'inputs').mkdir()
    for name in direct:
        if (ROOT / name).is_file():
            dest = out / 'inputs' / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes((ROOT / name).read_bytes())
    (out / 'source-before.json').write_text(json.dumps(before, indent=2), encoding='utf-8')
    command = [args.engine, '--position', '-32000,-32000', '--rendering-method', 'gl_compatibility',
               '--audio-driver', 'Dummy', '--fixed-fps', '60', '--verbose', '--path', str(ROOT / 'godot'),
               '--script', 'res://scripts/window_close_probe.gd', '--', f'--close-at={args.close_at}']
    user32 = ctypes.WinDLL('user32', use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user32.EnumWindows.argtypes = [callback_type, wintypes.LPARAM]
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.IsWindowVisible.argtypes = [wintypes.HWND]
    user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    started = time.monotonic()
    ready = None
    hwnd = None
    error = None
    posted = False
    proc = None
    try:
        with (out / 'native.log').open('wb') as log:
            proc = subprocess.Popen(command, cwd=ROOT, env=dict(os.environ, APPDATA=str(private), XDG_DATA_HOME=str(private)), stdout=log, stderr=subprocess.STDOUT)
            while time.monotonic() - started < 180 and proc.poll() is None:
                raw = (out / 'native.log').read_bytes().decode('utf-8', errors='replace')
                match = re.search(r'^WINDOW_CLOSE_READY (.+)$', raw, re.M)
                if match and not posted:
                    ready = json.loads(match.group(1))
                    if ready['pid'] != proc.pid:
                        raise RuntimeError('Readiness PID does not belong to this process')
                    if args.close_at == 'startup':
                        snap = ready['startup']
                        if ready['world_ready'] or not snap['startup_pending'] or not (snap['reader_busy'] or snap['player_art_pending']):
                            raise RuntimeError('Actual pending World worker was not observed before close')
                    elif not ready['world_ready'] or not any(v['playback'] and v['stream'] == 'AudioStreamOggVorbis' for v in ready['playing']):
                        raise RuntimeError('Actual ready World with an owned live Ogg playback was not observed')
                    if args.close_at == 'paused' and not ready['paused']:
                        raise RuntimeError('Paused boundary was not observed')
                    if not Path(ready['private_user_dir']).is_relative_to(private):
                        raise RuntimeError('Engine did not use the private APPDATA')
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
                        raise RuntimeError(f'Expected one visible window owned by PID {proc.pid}, found {len(windows)}')
                    hwnd = windows[0]
                    if not user32.PostMessageW(hwnd, 0x0010, 0, 0):
                        raise ctypes.WinError(ctypes.get_last_error())
                    posted = True
                    if args.repeat_close and not user32.PostMessageW(hwnd, 0x0010, 0, 0):
                        raise ctypes.WinError(ctypes.get_last_error())
                time.sleep(.025)
            if proc.poll() is None:
                raise TimeoutError('Owned Godot process exceeded 180 seconds')
    except Exception as exc:
        error = repr(exc)
    finally:
        if proc is not None and proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=10)
    raw = (out / 'native.log').read_bytes()
    log_text = raw.decode('utf-8', errors='replace')
    after = freeze()
    (out / 'source-after.json').write_text(json.dumps(after, indent=2), encoding='utf-8')
    result = dict(command=command, pid=None if proc is None else proc.pid, hwnd=hwnd, ready=ready, wm_close_posted=posted,
        repeat_close=args.repeat_close, close_at=args.close_at, legacy_close=args.legacy_close,
        observed='WINDOW_CLOSE_OBSERVED' in log_text, exit=None if proc is None else proc.returncode, error=error,
        seconds=round(time.monotonic()-started, 3), errors=len(re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:)',log_text,re.M)),
        warnings=len(re.findall(r'^\s*WARNING:',log_text,re.M)), source_equal=before == after,
        source_count=len(before), log_sha256=hashlib.sha256(raw).hexdigest(), private_appdata=str(private))
    result['passed'] = error is None and posted and result['observed'] and result['exit'] == 0 and result['errors'] == 0 and result['warnings'] == 0 and result['source_equal']
    (out / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=True), flush=True)
    return 0 if result['passed'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
