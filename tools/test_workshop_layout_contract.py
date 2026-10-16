import json
import unittest
from pathlib import Path
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
if __name__=='__main__':unittest.main()
