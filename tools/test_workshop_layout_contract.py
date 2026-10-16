import json
import io
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch
import build_world_upgrade
from workshop_layout_contract import contracts
ROOT=Path(__file__).resolve().parents[1]
class LayoutContracts(unittest.TestCase):
    def setUp(self):self.data=json.loads((ROOT/'godot/data/world_routes.json').read_text())
    def invalid(self,text):return any(not ok and text in label for ok,label in contracts(self.data))
    def selected(self):return next(l for l in self.data['workshop_layouts'] if l.get('layout_group')=='movement_group_one')
    def test_authored_routes(self):
        for group in ['movement_group_one','movement_group_two']:
            self.assertFalse(any(not ok for ok,_ in contracts(self.data,group)))
    def test_group_two_missing_room(self):
        self.data['workshop_layouts']=[l for l in self.data['workshop_layouts'] if l['room_id']!='upgrade_crown_resonance_3']
        self.assertTrue(any(not ok for ok,_ in contracts(self.data,'movement_group_two')))
    def test_group_two_floating_reward(self):
        t=next(t for t in self.data['ability_backtracks'] if t['room_id']=='upgrade_thorn_downstrike_1')
        reward=next(r for r in self.data['chapters'][t['region_id']]['collectibles'] if r['id']==t['reward_ids'][0]);reward['position'][1]-=10
        self.assertTrue(any(not ok and 'standing clearance' in label for ok,label in contracts(self.data,'movement_group_two')))
    def test_duplicate_recipe(self):
        self.data['workshop_layouts'].append(self.selected().copy())
        self.assertTrue(self.invalid('recipes are unique'))
    def test_missing_steps(self):
        l=self.selected();room=next(r for r in self.data['chapters'][l['region_id']]['map_rooms'] if r['id']==l['room_id']);room['route_steps']=[]
        self.assertTrue(self.invalid('intermediate movement'))
    def test_floating_landing(self):
        l=self.selected();room=next(r for r in self.data['chapters'][l['region_id']]['map_rooms'] if r['id']==l['room_id']);room['route_steps'][0]['position'][1]-=20
        self.assertTrue(self.invalid('real landing surface'))
    def test_bad_action(self):
        l=self.selected();room=next(r for r in self.data['chapters'][l['region_id']]['map_rooms'] if r['id']==l['room_id']);room['route_steps'][0]['action']='teleport'
        self.assertTrue(self.invalid('supported control action'))
    def test_duplicate_archetype(self):
        ls=[l for l in self.data['workshop_layouts'] if l.get('layout_group')=='movement_group_one'];ls[0]['variant']=ls[1]['variant']
        self.assertTrue(self.invalid('archetypes differ'))
    def test_wrong_reward_platform(self):
        l=self.selected();chapter=self.data['chapters'][l['region_id']];reward=next(p for p in chapter['collectibles'] if p['id']==l['room_id']+'_evidence');reward['platform_id']='absent'
        self.assertTrue(self.invalid('original rewards'))
    def test_stale_recipe_platform(self):
        self.selected()['platforms'][0]['offset'][1] += 1
        self.assertTrue(self.invalid('platform matches its authored recipe'))
    def test_stale_recipe_collision_role(self):
        self.selected()['platforms'][0]['collision_role'] = 'one_way'
        self.assertTrue(self.invalid('platform matches its authored recipe'))
    def test_stale_recipe_route(self):
        self.selected()['route_steps'][0]['offset'][0] += 1
        self.assertTrue(self.invalid('route steps match the authored recipe'))
    def test_missing_production_room_is_reported(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        chapter['map_rooms'] = [r for r in chapter['map_rooms'] if r['id'] != layout['room_id']]
        self.assertTrue(self.invalid('production room retains authored route identity'))
    def test_missing_shell_is_reported(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        chapter['platforms'] = [p for p in chapter['platforms'] if p['id'] != layout['room_id']+'_foundation']
        self.assertTrue(self.invalid('shell geometry exist'))
    def test_missing_reward_platform_is_reported(self):
        self.selected()['reward_platform'] = 'absent'
        self.assertTrue(self.invalid('reward platform exists in production'))
    def test_missing_production_grapple_anchor(self):
        layout = next(l for l in self.data['workshop_layouts'] if l['room_id']=='upgrade_echo_hook_1')
        chapter = self.data['chapters'][layout['region_id']]
        anchor_id = layout['room_id']+'_'+layout['extra_anchors'][0]['id_suffix']
        chapter['grapple_anchors'] = [a for a in chapter['grapple_anchors'] if a['id'] != anchor_id]
        self.assertTrue(self.invalid('production grapple anchor'))
    def test_stale_production_grapple_anchor(self):
        layout = next(l for l in self.data['workshop_layouts'] if l['room_id']=='upgrade_echo_hook_1')
        layout['extra_anchors'][0]['offset'][1] += 1
        self.assertTrue(self.invalid('production grapple anchor'))
    def test_obstructed_route_landing(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        room = next(r for r in chapter['map_rooms'] if r['id']==layout['room_id'])
        x, y = room['route_steps'][0]['position']
        chapter['platforms'].append(dict(id=layout['room_id']+'_obstruction',
                                         rect=[x-17,y-84,34,84],collision_role='wall'))
        self.assertTrue(self.invalid('route goal has unobstructed standing clearance'))
    def test_obstructed_reward_landing(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        reward = next(r for r in chapter['collectibles'] if r['id']==layout['room_id']+'_evidence')
        x, y = reward['position']
        chapter['platforms'].append(dict(id=layout['room_id']+'_obstruction',
                                         rect=[x-17,y-44,34,84],collision_role='wall'))
        self.assertTrue(self.invalid('reward pickup has unobstructed standing clearance'))
    def test_stale_backtrack_reward_landing(self):
        layout = self.selected()
        target = next(t for t in self.data['ability_backtracks'] if t['room_id']==layout['room_id'])
        target['reward_landing'][1] += 1
        self.assertTrue(self.invalid('room and backtrack retain the authored reward landing'))
    def test_nonfinite_platform_is_reported(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        next(p for p in chapter['platforms'] if p['id']==layout['reward_platform'])['rect'][0] = float('nan')
        self.assertTrue(self.invalid('platform geometry is finite and positive'))
    def test_terrain_owned_gallery_has_no_platform_support(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        gallery = next(p for p in chapter['platforms'] if p['id']==layout['reward_platform'])
        for value in ['some_terrain','',None]:
            with self.subTest(terrain_id=value):
                gallery['terrain_id'] = value
                self.assertTrue(self.invalid('authored platform retains standalone runtime collision'))
                self.assertTrue(self.invalid('route goal has a real landing surface'))
                self.assertTrue(self.invalid('item positions have standing clearance and full support'))
    def test_terrain_owned_shell_is_rejected(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        next(p for p in chapter['platforms'] if p['id']==layout['room_id']+'_foundation')['terrain_id'] = 'some_terrain'
        self.assertTrue(self.invalid('authored shell retains standalone runtime collision'))
    def test_noncolliding_gallery_has_no_platform_support(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        gallery = next(p for p in chapter['platforms'] if p['id']==layout['reward_platform'])
        for role in ['decorative','no_collision','NO_COLLISION']:
            with self.subTest(collision_role=role):
                gallery['collision_role'] = role
                self.assertTrue(self.invalid('route goal has a real landing surface'))
                self.assertTrue(self.invalid('item positions have standing clearance and full support'))
    def test_foreign_platform_id_blocks_route_by_room_or_space(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        room = next(r for r in chapter['map_rooms'] if r['id']==layout['room_id'])
        x, y = room['route_steps'][0]['position']
        blocker = dict(id='unexpected_blocker',room_id=layout['room_id'],
                       rect=[x-17,y-84,34,84],collision_role='wall')
        chapter['platforms'].append(blocker)
        self.assertTrue(self.invalid('route goal has unobstructed standing clearance'))
        del blocker['room_id']
        self.assertTrue(self.invalid('route goal has unobstructed standing clearance'))
        blocker['room_id'] = 'incorrect_other_room'
        self.assertTrue(self.invalid('route goal has unobstructed standing clearance'))
    def test_foreign_platform_id_blocks_reward(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        reward = next(r for r in chapter['collectibles'] if r['id']==layout['room_id']+'_evidence')
        x, y = reward['position']
        chapter['platforms'].append(dict(id='unexpected_blocker',rect=[x-17,y-44,34,84],collision_role='wall'))
        self.assertTrue(self.invalid('reward pickup has unobstructed standing clearance'))
    def test_noncolliding_decorations_do_not_block_standing(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        room = next(r for r in chapter['map_rooms'] if r['id']==layout['room_id'])
        x, y = room['route_steps'][0]['position']
        decoration = dict(id=layout['room_id']+'_visual_only',rect=[x-17,y-84,34,84])
        chapter['platforms'].append(decoration)
        for role in ['decorative','no_collision','NO_COLLISION']:
            with self.subTest(collision_role=role):
                decoration['collision_role'] = role
                self.assertFalse(any(not ok for ok,_ in contracts(self.data)))
    def test_terrain_owned_visual_record_is_not_a_platform_blocker(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        room = next(r for r in chapter['map_rooms'] if r['id']==layout['room_id'])
        x, y = room['route_steps'][0]['position']
        chapter['platforms'].append(dict(id=layout['room_id']+'_terrain_visual',
                                         rect=[x-17,y-84,34,84],collision_role='wall',terrain_id='some_terrain'))
        self.assertFalse(any(not ok for ok,_ in contracts(self.data)))
    def test_legacy_one_way_names_do_not_block_upper_body(self):
        layout = self.selected()
        chapter = self.data['chapters'][layout['region_id']]
        room = next(r for r in chapter['map_rooms'] if r['id']==layout['room_id'])
        x, y = room['route_steps'][0]['position']
        ledge = dict(rect=[x-17,y-50,34,18],collision_role='floor')
        chapter['platforms'].append(ledge)
        for name in ['bridge_extra','step_extra','shaft_bridge_extra','BRIDGE_EXTRA']:
            with self.subTest(id=name):
                ledge['id'] = name
                self.assertFalse(any(not ok for ok,_ in contracts(self.data)))
    def test_regeneration_preserves_complete_modern_overlay_twice(self):
        # Run against isolated copies: a contract test never edits production
        # data, and equality includes unrelated portals/overrides and CH05's
        # separate layout as well as the six retained combat-practice stations.
        original = (ROOT/'godot/data/world_routes.json').read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            data = Path(directory)
            route_path = data/'world_routes.json'
            route_path.write_bytes(original)
            for region in build_world_upgrade.REGIONS:
                (data/f'{region}.json').write_bytes((ROOT/f'godot/data/{region}.json').read_bytes())
            with patch.object(build_world_upgrade,'DATA',data), patch.object(build_world_upgrade,'PATH',route_path), redirect_stdout(io.StringIO()):
                for _ in range(2):
                    build_world_upgrade.build()
                    self.assertEqual(route_path.read_bytes(),original)
if __name__=='__main__':unittest.main()
