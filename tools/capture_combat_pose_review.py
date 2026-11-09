#!/usr/bin/env python3
"""Capture before/after native animation on an invisible Windows desktop.

Never switches desktops or opens a window on the user's active desktop. Saves
remain isolated. Official reference-game footage is not used in the output.
"""
from __future__ import annotations
import argparse
from contextlib import contextmanager
import ctypes
import os
from pathlib import Path
import re
import subprocess
import tempfile
import uuid

ROOT=Path(__file__).resolve().parents[1]

@contextmanager
def hidden_desktop():
    if os.name!='nt':raise RuntimeError('This capture helper requires Windows; use the software-GL runner on Linux')
    from ctypes import wintypes
    api=ctypes.WinDLL('user32',use_last_error=True)
    api.CreateDesktopW.argtypes=[wintypes.LPCWSTR,wintypes.LPCWSTR,ctypes.c_void_p,wintypes.DWORD,wintypes.DWORD,ctypes.c_void_p]
    api.CreateDesktopW.restype=wintypes.HANDLE;api.CloseDesktop.argtypes=[wintypes.HANDLE]
    name='CodexCombatReview_'+uuid.uuid4().hex[:10]
    handle=api.CreateDesktopW(name,None,None,0,0x000F01FF,None)
    if not handle:raise ctypes.WinError(ctypes.get_last_error())
    try:yield 'winsta0\\'+name
    finally:api.CloseDesktop(handle)

def run_hidden(command,desktop,env,log,timeout=240):
    startup=subprocess.STARTUPINFO();startup.lpDesktop=desktop
    startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    with log.open('w',encoding='utf-8') as output:
        process=subprocess.Popen(command,cwd=ROOT,env=env,stdout=output,stderr=subprocess.STDOUT,
                                 startupinfo=startup,creationflags=subprocess.CREATE_NO_WINDOW)
        try:code=process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=10)
            process.wait(timeout=10);raise
    text=log.read_text(encoding='utf-8',errors='replace')
    if code or re.search(r'^\s*(?:ERROR:|SCRIPT ERROR:|WARNING: ObjectDB)',text,re.M):raise RuntimeError(text[-5000:])
    return text

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine',type=Path,default=ROOT/'output/tools/godot-4.6.1/Godot_v4.6.1-stable_win64.exe')
    parser.add_argument('--all-bosses',action='store_true')
    parser.add_argument('--warnings',action='store_true')
    parser.add_argument('--output',type=Path,default=ROOT/'output/combat_animation_v7/native-review')
    args=parser.parse_args();engine=args.engine.resolve();output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    if engine.name.endswith('_console.exe'):
        native=engine.with_name(engine.name.replace('_console.exe','.exe'))
        if native.is_file():engine=native
    if args.warnings:
        fixture=ROOT/'godot/scripts/combat_warning_legacy_fixture.gd'
        if fixture.exists():raise FileExistsError('Refusing to overwrite an existing fixture')
        fixture.write_bytes(subprocess.check_output(['git','show','2758580d:godot/scripts/enemy_attack_effect.gd'],cwd=ROOT))
        try:
            with tempfile.TemporaryDirectory(prefix='warning-review-') as profile,hidden_desktop() as desktop:
                command=[str(engine),'--display-driver','windows','--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',str(ROOT/'godot'),'--script','res://scripts/painted_warning_review_capture.gd','--','--output='+str(output/'painted-warning-comparison.png')]
                text=run_hidden(command,desktop,dict(os.environ,APPDATA=profile,XDG_DATA_HOME=profile),output/'warnings.log')
                if 'PAINTED_WARNING_REVIEW_PASS samples=6' not in text:raise RuntimeError('Warning capture did not complete')
        finally:fixture.unlink(missing_ok=True)
        print('PAINTED_WARNING_REVIEW_PASS '+str(output/'painted-warning-comparison.png'))
        return
    count=2160 if args.all_bosses else 1440
    with tempfile.TemporaryDirectory(prefix='combat-motion-review-') as profile,hidden_desktop() as desktop:
        for name in ['before','after']:
            frames=output/name;frames.mkdir(exist_ok=True)
            command=[str(engine),'--display-driver','windows','--audio-driver','Dummy','--rendering-method','gl_compatibility','--fixed-fps','60',
                     '--path',str(ROOT/'godot'),'--script','res://scripts/enemy_combat_showcase_capture.gd','--','--capture-dir='+str(frames)]
            if name=='before':command.append('--legacy-art')
            if args.all_bosses:command.append('--all-bosses')
            text=run_hidden(command,desktop,dict(os.environ,APPDATA=profile,XDG_DATA_HOME=profile),output/(name+'.log'))
            if f'COMBAT_SHOWCASE_CAPTURE_PASS frames={count}' not in text:raise RuntimeError('Capture did not complete')
            subprocess.run(['ffmpeg','-v','error','-y','-framerate','60','-i',str(frames/'frame_%05d.png'),'-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(output/(name+'.mp4'))],check=True)
            print('COMBAT_POSE_CAPTURE',name,'frames='+str(count),flush=True)
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(output/'before.mp4'),'-i',str(output/'after.mp4'),'-filter_complex','[0:v][1:v]hstack=inputs=2',
                    '-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(output/'combat-poses-comparison.mp4')],check=True)
    print('COMBAT_POSE_REVIEW_PASS '+str(output/'combat-poses-comparison.mp4'))

if __name__=='__main__':main()
