"""Prevent simultaneous preview games without launching any real window."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from concurrent.futures import ThreadPoolExecutor
import music_library_server as server


class PreviewOwnershipTests(unittest.TestCase):
    def test_concurrent_clicks_start_one_owned_gui_process(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            engine=root/'Godot_console.exe'
            native=root/'Godot.exe'
            engine.touch();native.touch()
            class Game:
                pid=12345
                def poll(self):return None
            with patch.multiple(server,OUTPUT=root,ENGINE=str(engine),GAME=None,
                                GAME_KEY='',GAME_REGION='',ROWS={'probe':{'region':'test'}},
                                status=lambda:{'ready':True}), patch.object(server.subprocess,'Popen',return_value=Game()) as launch:
                with ThreadPoolExecutor(max_workers=20) as pool:
                    results=list(pool.map(lambda _:server.start_game('probe'),range(20)))
                self.assertEqual(sum(code==200 for code,_ in results),1)
                self.assertEqual(sum(code==409 for code,_ in results),19)
                self.assertEqual(launch.call_count,1)
                command=launch.call_args.args[0]
                self.assertEqual(command[0],str(native if os.name=='nt' else engine))
                self.assertIn('--music-lock=false',command)
                self.assertNotEqual(launch.call_args.kwargs['env']['APPDATA'],os.environ.get('APPDATA'))

    def test_catalog_has_six_regions_and_thirty_distinct_sfx(self):
        import json
        data=server.catalog()
        with patch.object(server,'DATA',data):
            self.assertEqual(len(server.regions()),6)
        manifest=json.loads((server.ROOT/'godot/assets/audio/sfx/ai_combat/manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(len(manifest['entries']),30)
        self.assertEqual(len({row['sha256'] for row in manifest['entries']}),30)


if __name__=='__main__':unittest.main()
