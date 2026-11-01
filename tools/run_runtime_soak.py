#!/usr/bin/env python3
"""Run a wall-clock real-GL lifecycle soak against frozen project sources."""
from __future__ import annotations
import argparse
from contextlib import nullcontext
import ctypes
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
from runtime_soak_metrics import evaluate
from software_gl import software_gl

ROOT = Path(__file__).resolve().parents[1]


def freeze():
    names = subprocess.check_output(['git', 'ls-files', '-z', '--', 'godot', 'tools/run_runtime_soak.py', 'tools/runtime_soak_metrics.py'], cwd=ROOT).decode().split('\0')
    names += ['godot/scripts/runtime_soak_validation.gd', 'tools/run_runtime_soak.py', 'tools/runtime_soak_metrics.py']
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sorted(set(names)) if name and (ROOT / name).is_file()}


def resident_bytes(pid):
    if os.name == 'nt':
        class Counters(ctypes.Structure):
            _fields_ = [('cb', ctypes.c_ulong), ('PageFaultCount', ctypes.c_ulong)] + [(name, ctypes.c_size_t) for name in ['PeakWorkingSetSize', 'WorkingSetSize', 'QuotaPeakPagedPoolUsage', 'QuotaPagedPoolUsage', 'QuotaPeakNonPagedPoolUsage', 'QuotaNonPagedPoolUsage', 'PagefileUsage', 'PeakPagefileUsage']]
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.OpenProcess.restype = ctypes.c_void_p
        kernel.CloseHandle.argtypes = [ctypes.c_void_p]
        handle = kernel.OpenProcess(0x1000 | 0x10, False, pid)
        if not handle:
            return None
        try:
            counters = Counters()
            counters.cb = ctypes.sizeof(counters)
            psapi = ctypes.WinDLL('psapi', use_last_error=True)
            psapi.GetProcessMemoryInfo.argtypes = [ctypes.c_void_p, ctypes.POINTER(Counters), ctypes.c_ulong]
            return counters.WorkingSetSize if psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb) else None
        finally:
            kernel.CloseHandle(handle)
    try:
        return int(Path(f'/proc/{pid}/statm').read_text().split()[1]) * os.sysconf('SC_PAGE_SIZE')
    except (OSError, ValueError, IndexError):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--seconds', type=float, default=1800)
    parser.add_argument('--log-dir', required=True, type=Path)
    parser.add_argument('--native-gl', action='store_true', help='Use the installed native GL renderer in an offscreen window.')
    args = parser.parse_args()
    if not math.isfinite(args.seconds) or args.seconds < 1:
        parser.error('--seconds must be finite and at least 1')
    engine = shutil.which(args.engine)
    if not engine:
        parser.error('Godot executable not found')
    logs = args.log_dir.resolve()
    if logs.exists() and any(logs.iterdir()):
        parser.error('--log-dir must be new or empty; previous evidence is never overwritten')
    logs.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([engine, '--version'], text=True).strip()
    if not version.startswith('4.6.1.'):
        parser.error('this acceptance runner requires Godot 4.6.1')
    before = freeze()
    (logs/'sources_before.json').write_text(json.dumps(before, indent=2), encoding='utf-8')
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    started = time.monotonic()
    readings = []
    timed_out = False
    result_file = logs/'engine_metrics.json'
    # A fresh run must never reuse a previous run's successful engine output.
    if result_file.exists():
        raise RuntimeError('use a new log directory; engine_metrics.json already exists')
    display = nullcontext({}) if args.native_gl else software_gl(logs/'display')
    with tempfile.TemporaryDirectory(prefix='ctp-soak-save-') as scratch, display as renderer_env:
        command = [engine, '--verbose', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--max-fps', '60', '--path', str(ROOT/'godot'), '--script', 'res://scripts/runtime_soak_validation.gd']
        if args.native_gl:
            command += ['--position', '-32000,-32000']
        else:
            command += ['--display-driver', 'x11']
        command += ['--', f'--soak-seconds={args.seconds}', f'--soak-output={result_file.as_posix()}', f'--soak-save={Path(scratch).as_posix()}/world.json']
        with (logs/'runtime.log').open('w', encoding='utf-8') as log:
            proc = subprocess.Popen(command, cwd=ROOT, env=dict(os.environ, **renderer_env), stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            print(f'RUNTIME_SOAK_STARTED pid={proc.pid} revision={revision} requested_seconds={args.seconds}', flush=True)
            try:
                while proc.poll() is None:
                    readings.append({'elapsed_seconds': time.monotonic()-started, 'resident_bytes': resident_bytes(proc.pid)})
                    if time.monotonic()-started > args.seconds+600:
                        timed_out = True
                        proc.kill()
                        break
                    time.sleep(5)
                exit_code = proc.wait(timeout=15)
            finally:
                if proc.poll() is None:
                    proc.kill()
                    proc.wait(timeout=15)
    plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', (logs/'runtime.log').read_text(encoding='utf-8', errors='replace'))
    engine_errors = re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$', plain, re.MULTILINE)
    warnings = re.findall(r'^\s*WARNING:.*$', plain, re.MULTILINE)
    after = freeze()
    changed = sorted(name for name in set(before)|set(after) if before.get(name) != after.get(name))
    result = json.loads(result_file.read_text(encoding='utf-8')) if result_file.exists() else {}
    assessment = evaluate(result, args.seconds)
    errors = assessment['errors']
    if exit_code or timed_out or engine_errors or not re.search(r'^RUNTIME_SOAK_PASS ', plain, re.MULTILINE):
        errors.append(f'engine failed: exit={exit_code} timeout={timed_out} errors={len(engine_errors)}')
    if any('ObjectDB instances leaked' in item or 'resources still in use' in item for item in warnings):
        errors.append('engine reports leaked objects or resources at teardown')
    if changed:
        errors.append('project source content changed during measurement')
    assessment['passed'] = not errors
    assessment['long_session'] = args.seconds >= 1800 and not errors
    report = {'revision': revision, 'engine_version': version, 'renderer': 'native GL' if args.native_gl else 'software GL', 'command': command, 'wall_seconds': time.monotonic()-started, 'exit_code': exit_code,
              'source_changes': changed, 'engine_errors': engine_errors, 'warnings': warnings, 'process_memory_samples': readings, 'assessment': assessment}
    (logs/'verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(assessment, ensure_ascii=False), flush=True)
    return 0 if assessment['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
