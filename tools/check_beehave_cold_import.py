"""Exercise Beehave in fresh projects, including the first SVG import pass."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
ERROR=re.compile(r'^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:).*$',re.M)
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--engine',required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
    results=[]
    with tempfile.TemporaryDirectory(prefix='beehave-cold-',dir=out) as temporary:
        for mode in ['recovery','enabled']:
            project=Path(temporary)/mode
            shutil.copytree(ROOT/'godot/addons/beehave',project/'addons/beehave',ignore=shutil.ignore_patterns('*.import','.godot','UPSTREAM.json'))
            (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Beehave cold import regression"\n[autoload]\nBeehaveGlobalMetrics="*res://addons/beehave/metrics/beehave_global_metrics.gd"\nBeehaveGlobalDebugger="*res://addons/beehave/debug/global_debugger.gd"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[editor_plugins]\nenabled=PackedStringArray("res://addons/beehave/plugin.cfg")\n',encoding='utf-8')
            env=dict(os.environ,APPDATA=str(Path(temporary)/'userdata'/mode),XDG_DATA_HOME=str(Path(temporary)/'userdata'/mode))
            for iteration in [1,2]:
                command=[a.engine,'--headless','--path',str(project),'--editor','--import','--quit']
                if mode=='recovery':command+=['--recovery-mode']
                r=subprocess.run(command,capture_output=True,text=True,encoding='utf-8',errors='replace',env=env,timeout=120,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
                text=r.stdout+'\n'+r.stderr
                (out/f'{mode}-{iteration}.log').write_text(text,encoding='utf-8')
                plain=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',text)
                errors=ERROR.findall(plain)
                imported=any((project/'.godot/imported').glob('tree.svg-*.ctex'))
                ok=r.returncode==0 and not errors and imported
                results.append(dict(mode=mode,pass_number=iteration,passed=ok,errors=errors,tree_icon_imported=imported))
                (out/'verification.json').write_text(json.dumps({'results':results},indent=2)+'\n',encoding='utf-8')
                print(mode,iteration,'PASS' if ok else 'FAIL',flush=True)
                if not ok:
                    print('\n'.join(errors));return 1
    print('BEEHAVE_COLD_IMPORT checks=4 failures=0')
    return 0
if __name__=='__main__':raise SystemExit(main())
