"""Prevent map regeneration and retired art from resurrecting level traps."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
import blueprint_to_godot_runtime as blueprint
import expand_multilayer_maps as multilayer

ROOT=Path(__file__).resolve().parents[1]


class TrapFreeWorld(unittest.TestCase):
    def test_shipped_configs_and_blueprints_have_no_trap_placements(self):
        def check(value,path):
            if isinstance(value,dict):
                for key,item in value.items():
                    if key in {"hazards","traps"} and isinstance(item,list):
                        self.assertEqual(item,[],str(path)+":"+key)
                    else:check(item,path)
            elif isinstance(value,list):
                for item in value:check(item,path)
        for path in (ROOT/"godot/data").rglob("*.json"):
            check(json.loads(path.read_text(encoding="utf-8")),path)
        check(json.loads((ROOT/"docs/spec/20260615161637828_soulbox_level_graph.json").read_text(encoding="utf-8")),"current blueprint")

    def test_generated_room_shapes_do_not_create_spikes(self):
        rooms=[SimpleNamespace(index=i,kind=kind,x0=0,x1=1000,floor_y=400,id=f"room_{i}")
               for i in range(20) for kind in ["boss","normal","safe","gate"]]
        self.assertEqual(blueprint.make_hazards(rooms),[])

    def test_multilayer_rebuild_clears_legacy_traps(self):
        platforms=[{"id":f"floor_{i}","rect":[i*400,400,300,30]} for i in range(12)]
        for chapter in range(1,7):
            data={"hazards":[{"kind":"spikes","rect":[0,0,100,20]}]}
            multilayer.update_hazards(chapter,data,platforms)
            self.assertEqual(data["hazards"],[])

    def test_handcrafted_generators_write_no_traps_in_an_isolated_copy(self):
        self.assertIsNotNone(shutil.which("node"))
        with tempfile.TemporaryDirectory(prefix="ctp-map-generation-") as tmp:
            base=Path(tmp);(base/"tools").mkdir();(base/"godot/data").mkdir(parents=True)
            for number,slug in [(1,"moss_bell_court"),(2,"rain_foundry_canal")]:
                script=f"handcraft_ch{number:02d}_boxgarden.mjs"
                data=f"demo_ch{number:02d}_{slug}.json"
                shutil.copyfile(ROOT/"tools"/script,base/"tools"/script)
                shutil.copyfile(ROOT/"godot/data"/data,base/"godot/data"/data)
                result=subprocess.run(["node",str(base/"tools"/script),"--write"],cwd=base,
                                      capture_output=True,text=True,encoding="utf-8",timeout=60)
                self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                self.assertIn("SELF_AUDIT_OK",result.stdout)
                self.assertEqual(json.loads((base/"godot/data"/data).read_text(encoding="utf-8"))["hazards"],[])

    def test_retired_trap_art_is_not_shipped_in_the_runtime_tree(self):
        for folder in ["godot/assets/sprites/demo","godot/assets/sprites/gothicvania/demo"]:
            for path in (ROOT/folder).glob("*.png"):
                self.assertFalse(path.name.startswith(("trap_","hazard_")),str(path))
        for name in ["godot/assets/sprites/open_asset_manifest.json",
                     "godot/assets/sprites/gothicvania/asset_manifest.json"]:
            targets=json.loads((ROOT/name).read_text(encoding="utf-8"))["runtime_targets"]
            for target in targets:
                self.assertFalse(Path(target).name.startswith(("trap_","hazard_")),name+":"+target)

    def test_earned_relics_keep_useful_nonstacking_effects(self):
        data=json.loads((ROOT/"godot/data/build_catalog.json").read_text(encoding="utf-8"))
        for key in ["quiet_sole","damp_knot"]:
            relic=data["passives"][key]
            self.assertEqual(relic["unlock_item"],key)
            self.assertEqual(relic["modifiers"],{"move_mult":0.05})
            self.assertEqual(relic["group"],"light_travel")


if __name__ == "__main__":
    unittest.main()
