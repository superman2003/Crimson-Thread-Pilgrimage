#!/usr/bin/env python3
"""Negative fixtures ensure the map gate detects errors in both map formats."""
import copy
import unittest
from audit_platform_geometry import audit as geometry
from audit_map_uniqueness import audit as uniqueness

class AuditTests(unittest.TestCase):
    def setUp(self):
        self.data = {
            'id': 'fixture', 'player_start': [80, 100], 'boss_checkpoint': [80, 100],
            'platforms': [{'id': 'floor', 'rect': [0, 140, 400, 40], 'safe_landing': True, 'gameplay_clearance': 180}],
            # The X ranges deliberately overlap: actual rooms use 2D outlines.
            'map_rooms': [{'id': 'low', 'name': 'Low', 'range': [0, 400], 'layout_rect': [0, 0, 400, 200]}],
            'connections': [], 'save_points': []}
    def test_supported_recovery_is_clear(self):
        self.assertEqual(geometry(self.data)[1], [])
        self.assertEqual(uniqueness(self.data)[1], [])
    def test_ceiling_collides_with_real_player_body(self):
        self.data['platforms'].append({'id': 'ceiling', 'rect': [60, 25, 40, 12], 'collision_role': 'ceiling'})
        self.assertTrue(any('overlaps' in e for e in geometry(self.data)[1]))
    def test_missing_support_fails(self):
        self.data['player_start'] = [600, 0]
        self.assertTrue(any('no landing' in e for e in geometry(self.data)[1]))
    def test_invalid_rect_and_duplicate_platform_fail(self):
        self.data['platforms'].append({'id': 'floor', 'rect': [0, 140, -1, 10]})
        errors = geometry(self.data)[1]
        self.assertTrue(any('duplicate' in e for e in errors))
        self.assertTrue(any('invalid collision' in e for e in errors))
    def test_stacked_rooms_allow_overlapping_x_ranges(self):
        self.data['platforms'].append({'id': 'upper', 'rect': [0, 340, 400, 40]})
        self.data['map_rooms'].append({'id': 'high', 'name': 'High', 'range': [0, 400], 'layout_rect': [0, 200, 400, 200]})
        self.assertEqual(uniqueness(self.data)[1], [])
    def test_duplicate_room_and_dangling_navigation_fail(self):
        self.data['map_rooms'].append(copy.deepcopy(self.data['map_rooms'][0]))
        self.data['connections'] = [{'from': 'low', 'to': 'missing'}]
        errors = uniqueness(self.data)[1]
        self.assertTrue(any('duplicate room IDs' in e for e in errors))
        self.assertTrue(any('missing room' in e for e in errors))

if __name__ == '__main__':
    unittest.main()
