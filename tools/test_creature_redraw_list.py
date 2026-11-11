"""Protect report output ownership, input freshness and production clip routing."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import build_creature_redraw_list as report


def manifest(names, authored=()):
    return dict(animations=[dict(name=n, fps=10, loop=False, frames=[{}]*4) for n in names],
                authored_combat_sequences=list(authored))


class ReportSafety(unittest.TestCase):
    def test_cleanup_preserves_unrelated_jpegs_and_outside_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary); out=root/'sheets'; out.mkdir()
            precious=root/'precious.jpg'; precious.write_bytes(b'private photo')
            unrelated=out/'photo.jpg'; unrelated.write_bytes(b'unrelated image')
            old=out/'creature__walk.jpg'; old.write_bytes(b'old sheet')
            (out/'.creature-redraw-sheets.json').write_text(json.dumps([old.name, 'photo.jpg', '../precious.jpg']))
            report.finish_sheets(out, set(), {old.name})
            self.assertFalse(old.exists())
            self.assertEqual(unrelated.read_bytes(), b'unrelated image')
            self.assertEqual(precious.read_bytes(), b'private photo')

    def test_external_sheet_directory_has_a_general_relative_link(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            with patch.object(report, 'LIST', root/'repo/docs/research/list.md'):
                link=report.sheet_link_base(root/'external/sheets')
            self.assertEqual(link, '../../../external/sheets')

    def test_manifest_and_atlas_edits_invalidate_size_measurements(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary); path=root/'motion_v8_manifest.json'
            data=manifest(['idle']); path.write_text(json.dumps(data))
            table=dict(manifest=path.name, manifest_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                       atlas_sha256={'atlas.png':'original pixels'}, frames={})
            (root/report.fit.OUTPUT).write_text(json.dumps(table))
            with patch.object(report.fit, 'atlas_digests', return_value={'atlas.png':'original pixels'}):
                self.assertEqual(report.checked_fit(root,path,data), {})
            with patch.object(report.fit, 'atlas_digests', return_value={'atlas.png':'new pixels'}):
                with self.assertRaisesRegex(ValueError, 'build_creature_frame_fit.py'):
                    report.checked_fit(root,path,data)
            path.write_text(json.dumps(data)+'\n')
            with patch.object(report.fit, 'atlas_digests', return_value=table['atlas_sha256']):
                with self.assertRaisesRegex(ValueError, 'stale'):
                    report.checked_fit(root,path,data)

    def test_rich_combat_excludes_hurt_and_unreachable_charge_travel(self):
        names=['idle','walk','hurt','heavy','heavy_windup','heavy_recover','heavy_charge','heavy_travel']
        data=manifest(names, ['heavy','heavy_windup','heavy_recover'])
        profile=dict(attacks=[dict(id='heavy', windup=1, active=1, recover=1)])
        actual=report.routed_clips(data,[profile])
        self.assertEqual(actual, {'idle','walk','heavy','heavy_windup','heavy_recover'})

    def test_legacy_loops_obey_phase_duration_and_small_charge_hold(self):
        data=manifest(['idle','walk','attack','windup','recover','charge','travel'])
        profile=dict(attacks=[dict(id='absent',windup=1,active=1,recover=1)])
        selected=report.routed_clips(data,[profile])
        self.assertTrue({'charge','travel'}.issubset(selected))
        next(c for c in data['animations'] if c['name']=='charge')['frames']=[{}]*2
        profile['attacks'][0]['active']=.2
        selected=report.routed_clips(data,[profile])
        self.assertNotIn('charge',selected)
        self.assertNotIn('travel',selected)

    def test_directional_clips_do_not_report_unused_shared_copy(self):
        data=manifest(['idle','walk','attack','attack_left','attack_right','windup','recover'])
        selected=report.routed_clips(data,[dict(attacks=[dict(id='absent')])])
        self.assertNotIn('attack',selected)
        self.assertTrue({'attack_left','attack_right'}.issubset(selected))

    def test_report_total_comes_from_the_processed_roster(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            with patch.object(report,'LIST',root/'list.md'), patch.object(report,'RECORD',root/'list.json'), \
                    patch.object(report.fit,'kinds',return_value=['one','two']), \
                    patch.object(report,'measure',return_value=[]), patch.object(report,'exposure',return_value={}), \
                    patch('sys.argv',['report','--jobs','1']):
                self.assertEqual(report.main(),0)
            record=json.loads((root/'list.json').read_text(encoding='utf-8'))
            self.assertEqual(record['creatures'],2)
            self.assertEqual(record['measurement_space'],'raw_art_before_frame_fit')
            self.assertIn('2 种怪物',(root/'list.md').read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()
