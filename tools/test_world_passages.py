import unittest
import json
from copy import deepcopy
from validate_world_passages import ROOT, validate

class Contracts(unittest.TestCase):
    def setUp(self):
        self.data,self.routes,self.layout=(json.loads((ROOT/'godot/data'/p).read_text()) for p in ('world_passages.json','world_routes.json','world_layout.json'))
    def errors(self):return validate(self.data,self.routes,self.layout)
    def test_real_network(self):self.assertEqual(self.errors(),[])
    def test_duplicate_id(self):
        self.data['passages'][1]['id']=self.data['passages'][0]['id']
        self.assertTrue(any('duplicate passage' in e for e in self.errors()))
    def test_duplicate_mouth(self):
        self.data['passages'][1]['a']=deepcopy(self.data['passages'][0]['a'])
        self.assertTrue(any('duplicate physical' in e for e in self.errors()))
    def test_missing_peer(self):
        self.data['passages'][1]['b']['portal']='absent'
        self.assertTrue(any('differs' in e or 'missing endpoint' in e for e in self.errors()))
    def test_nonfinite_position(self):
        self.routes['chapters'][self.data['passages'][0]['a']['region']]['portals'][0]['position']=[float('nan'),2]
        self.assertTrue(any('invalid endpoint' in e for e in self.errors()))
    def test_steep_connector(self):
        self.layout['regions'][self.data['passages'][0]['b']['region']]['origin'][1]=50000
        self.assertTrue(any('slope' in e for e in self.errors()))
    def test_disconnected_region(self):
        self.data['passages']=self.data['passages'][:4]
        self.assertIn('physical network does not connect all six regions',self.errors())

if __name__=='__main__':unittest.main()
