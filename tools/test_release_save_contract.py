"""The packaged-player save gate must reject passive boots and data loss."""
from __future__ import annotations

from contextlib import redirect_stdout
from io import StringIO
import json
import os
from pathlib import Path
import tempfile
import unittest

import release_save_contract as contract


def fresh():
    return {'version': 3, 'current_region': 'demo_ch01_salt_wind',
            'regions': {'demo_ch01_salt_wind': {'visited_rooms': {'arrival': True}}},
            'currency': 0, 'inventory_counts': {'thread_spool': 2},
            'build_state': {'selected_slot': 0}, 'story_flags': {}, 'death_cache': {}}


class DeliveredPlayer:
    """OS-boundary fixture; never supplied to the actual packaged executable."""
    def __init__(self, mutate=None):
        self.calls = []
        self.mutate = mutate
        self.user_data = None
        self.last_snapshot = None

    def __call__(self, command, log, *, timeout, cwd, env):
        self.calls.append((command, log.stem, timeout, cwd, dict(env)))
        self.user_data = Path(env['XDG_DATA_HOME'])
        self.user_data.mkdir(parents=True, exist_ok=True)
        slot = next((int(arg.split('=')[1]) for arg in command if arg.startswith('--save-slot=')), 1)
        save = self.user_data / 'app_userdata' / 'game' / contract.SAVE_NAMES[slot]
        save.parent.mkdir(parents=True, exist_ok=True)
        if self.mutate and self.mutate(log.stem, save, command):
            return ''
        backup = save.with_name(save.name + '.bak')
        if '--new-game' in command:
            previous = save.with_name(save.name + '.previous')
            if previous.exists():
                previous.with_name(previous.name + '.earlier_fixture').write_bytes(previous.read_bytes())
            previous.write_bytes(save.read_bytes())
            save.unlink()
        if not save.exists():
            save.write_text(json.dumps(fresh()), encoding='utf-8')
        else:
            try:
                data = json.loads(save.read_text(encoding='utf-8'))
                valid = isinstance(data, dict) and data.get('currency', -1) >= 0
            except (ValueError, UnicodeError):
                valid = False
            if valid:
                backup.write_bytes(save.read_bytes())
                save.write_text(json.dumps(data), encoding='utf-8')
        self.last_snapshot = contract.family_snapshot(self.user_data)
        return ''


class ReleaseSaveContractTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.binary = self.root / 'delivered-player'
        self.logs = self.root / 'logs'

    def smoke(self, player=None):
        player = player or DeliveredPlayer()
        with redirect_stdout(StringIO()):
            return contract.smoke_save_contract(self.binary, self.logs, 23, player)

    def test_all_slots_damage_and_explicit_new_game_use_the_delivered_binary(self):
        player = DeliveredPlayer()
        evidence = self.smoke(player)
        expected = ['slot-1-first-start', 'slot-1-resume', 'slot-2-first-start', 'slot-2-resume',
                    'slot-3-first-start', 'slot-3-resume', 'damaged-primary-valid-backup',
                    'invalid-schema-damaged-backup', 'healthy-slot-after-damage',
                    'explicit-new-game-preserves-journeys']
        self.assertEqual(expected, evidence['launches'])
        self.assertEqual(expected, [call[1] for call in player.calls])
        profiles = set()
        for command, label, timeout, cwd, env in player.calls:
            self.assertEqual(str(self.binary), command[0])
            self.assertEqual(['--headless', '--verbose', '--max-fps', '60', '--quit-after', '1200'], command[1:7])
            self.assertNotIn('--path', command)
            self.assertNotIn('--script', command)
            self.assertEqual(23, timeout)
            self.assertEqual(env['XDG_DATA_HOME'], env['APPDATA'])
            self.assertTrue(Path(env['LOCALAPPDATA']).is_relative_to(cwd))
            self.assertTrue(Path(env['XDG_CONFIG_HOME']).is_relative_to(cwd))
            self.assertTrue(Path(env['XDG_CACHE_HOME']).is_relative_to(cwd))
            profiles.add(env['XDG_DATA_HOME'])
            if 'slot-2' in label or label == 'invalid-schema-damaged-backup':
                self.assertEqual(['--', '--save-slot=2'], command[7:])
        self.assertEqual(1, len(profiles))
        self.assertFalse(player.user_data.exists(), 'temporary save profile removed after success')
        self.assertEqual(evidence, json.loads((self.logs / 'save-contract.json').read_text()))
        self.assertEqual(4, evidence['resume_writebacks'])
        self.assertEqual(2, evidence['damaged_cases_preserved'])
        self.assertEqual(2, evidence['new_game_archives_preserved'])

    def rejects(self, mutate, message):
        player = DeliveredPlayer(mutate)
        with self.assertRaisesRegex((ValueError, OSError), message):
            self.smoke(player)
        self.assertFalse((self.logs / 'save-contract.json').exists(), 'failed gate cannot emit success evidence')
        if player.user_data is not None:
            self.assertFalse(player.user_data.exists(), 'temporary save profile removed after failure')
        return player

    def test_passive_fresh_boot_cannot_pass(self):
        self.rejects(lambda *_: True, 'exactly one')

    def test_operating_system_profile_environment_is_unchanged(self):
        original = dict(os.environ)
        self.smoke()
        self.assertEqual(original, dict(os.environ))
        with self.assertRaises(ValueError):
            self.smoke(DeliveredPlayer(lambda *_: True))
        self.assertEqual(original, dict(os.environ))

    def test_passive_resume_cannot_pass_without_a_new_backup(self):
        self.rejects(lambda label, *_: label == 'slot-1-resume', 'slot save')

    def test_reset_instead_of_resume_is_rejected(self):
        def reset(label, save, _):
            if label == 'slot-2-resume':
                save.write_text(json.dumps(fresh()))
                return True
            return False
        self.rejects(reset, 'exact resume progress')

    def test_each_progress_domain_must_survive_resume(self):
        changes = {'currency': 5, 'inventory_counts': {}, 'build_state': {}, 'story_flags': {},
                   'death_cache': {'region_id': 'other'}, 'current_region': 'another_region'}
        for key, value in changes.items():
            with self.subTest(field=key):
                def change(label, save, _, key=key, value=value):
                    if label != 'slot-1-resume':return False
                    data = json.loads(save.read_text())
                    data[key] = value
                    save.with_name(save.name + '.bak').write_text(json.dumps(data))
                    save.write_text(json.dumps(data))
                    return True
                self.rejects(change, 'exact resume progress')

    def test_unrelated_backup_cannot_prove_resume_writeback(self):
        def wrong(label, save, _):
            if label != 'slot-3-resume':return False
            save.with_name(save.name + '.bak').write_text(json.dumps(fresh()))
            return True
        self.rejects(wrong, 'verified resume backup')

    def test_starting_another_slot_cannot_overwrite_a_sibling(self):
        def overwrite(label, save, _):
            if label == 'slot-2-first-start':
                save.with_name(contract.SAVE_NAMES[1]).write_text(json.dumps(fresh()))
            return False
        self.rejects(overwrite, 'Slot 2 first start: save evidence changed')

    def test_resuming_a_slot_cannot_modify_a_sibling_backup(self):
        def overwrite(label, save, _):
            if label == 'slot-2-resume':
                save.with_name(contract.SAVE_NAMES[1] + '.bak').write_bytes(b'other slot lost')
            return False
        self.rejects(overwrite, 'Slot 2 resume: save evidence changed')

    def test_another_slot_cannot_inherit_earlier_probe(self):
        def inherit(label, save, _):
            if label != 'slot-2-first-start':return False
            data = fresh()
            data['story_flags'][contract.PROBE_FLAG + '_1'] = True
            save.write_text(json.dumps(data))
            return True
        self.rejects(inherit, 'inherited another slot probe')

    def test_damaged_primary_is_not_silently_replaced_from_backup(self):
        def recover(label, save, _):
            if label == 'damaged-primary-valid-backup':
                save.write_bytes(save.with_name(save.name + '.bak').read_bytes())
                return True
            return False
        self.rejects(recover, 'Damaged primary with valid backup: save evidence changed')

    def test_damaged_primary_and_backup_both_keep_original_evidence(self):
        for suffix in ('', '.bak'):
            with self.subTest(suffix=suffix):
                def erase(label, save, _, suffix=suffix):
                    if label != 'invalid-schema-damaged-backup':return False
                    save.with_name(save.name + suffix).unlink()
                    return True
                self.rejects(erase, 'Invalid primary and backup: save evidence changed')

    def test_new_staging_or_quarantine_files_cannot_disguise_damage_mutation(self):
        for suffix in ('.tmp', '.restore', '.before_restore_fixture'):
            with self.subTest(suffix=suffix):
                def add(label, save, _, suffix=suffix):
                    if label == 'damaged-primary-valid-backup':
                        save.with_name(save.name + suffix).write_bytes(b'unexpected write')
                        return True
                    return False
                self.rejects(add, 'save evidence changed')

    def test_healthy_slot_must_still_resume_after_other_slots_are_blocked(self):
        self.rejects(lambda label, *_: label == 'healthy-slot-after-damage', 'slot save')

    def test_new_game_must_be_fresh_and_preserve_both_abandoned_journeys(self):
        for defect, message in [('passive', 'fresh selected-slot progress'),
                                ('missing_previous', 'archive the selected journey'),
                                ('missing_earlier', 'earlier abandoned journey')]:
            with self.subTest(defect=defect):
                def broken(label, save, command, defect=defect):
                    if label != 'explicit-new-game-preserves-journeys':return False
                    previous = save.with_name(save.name + '.previous')
                    if defect == 'passive':return True
                    if defect != 'missing_earlier':
                        previous.with_name(previous.name + '.earlier_fixture').write_bytes(previous.read_bytes())
                    if defect != 'missing_previous':previous.write_bytes(save.read_bytes())
                    save.write_text(json.dumps(fresh()))
                    return True
                self.rejects(broken, message)

    def test_engine_errors_timeouts_and_nonzero_results_are_not_retried(self):
        for error in (RuntimeError('engine error'), RuntimeError('timeout'), OSError('cannot execute')):
            calls = []
            def fail(*args, **kwargs):
                calls.append(args)
                raise error
            with self.subTest(error=error), self.assertRaises(type(error)):
                self.smoke(fail)
            self.assertEqual(1, len(calls))
            self.assertFalse((self.logs / 'save-contract.json').exists())

    def test_snapshot_includes_nested_evidence_and_respects_slot_boundary(self):
        one = self.root / 'nested' / contract.SAVE_NAMES[1]
        one.parent.mkdir()
        one.write_bytes(b'primary')
        one.with_name(one.name + '.bak').write_bytes(b'backup')
        two = one.with_name(contract.SAVE_NAMES[2])
        two.write_bytes(b'sibling')
        (one.parent / 'unrelated.log').write_bytes(b'engine log')
        self.assertEqual(3, len(contract.family_snapshot(self.root)))
        self.assertEqual({'nested/' + two.name: b'sibling'}, contract.sibling_snapshot(self.root, one))

    def test_ambiguous_user_profile_save_is_rejected(self):
        for directory in ('a', 'b'):
            path = self.root / directory / contract.SAVE_NAMES[1]
            path.parent.mkdir()
            path.write_text(json.dumps(fresh()))
        with self.assertRaisesRegex(ValueError, 'exactly one'):
            contract.locate_save(self.root, 1)

    def test_missing_malformed_and_incomplete_player_outputs_are_rejected(self):
        save = self.root / contract.SAVE_NAMES[1]
        with self.assertRaisesRegex(ValueError, 'slot save'):
            contract.read_save(save)
        for value in ('{bad', '[]', '{}'):
            save.write_text(value)
            with self.subTest(value=value), self.assertRaises(ValueError):
                contract.read_save(save)
        invalid = [('current_region', ''), ('regions', {}), ('story_flags', []),
                   ('currency', -1), ('currency', True), ('currency', 0.5),
                   ('inventory_counts', []), ('build_state', None), ('death_cache', False)]
        for key, value in invalid:
            data = fresh()
            data[key] = value
            save.write_text(json.dumps(data))
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                contract.read_save(save)
        save.write_text(json.dumps(fresh()))
        self.assertEqual(fresh(), contract.read_save(save))

    def test_workflow_and_export_entry_point_run_both_old_and_new_gates(self):
        root = Path(__file__).resolve().parents[1]
        workflow = (root / '.github/workflows/release-candidate.yml').read_text()
        self.assertGreaterEqual(workflow.count("'tools/release_save_contract.py'"), 2)
        self.assertGreaterEqual(workflow.count("'tools/test_release_save_contract.py'"), 2)
        self.assertIn('python tools/test_release_builder.py', workflow)
        self.assertIn('python tools/test_release_save_contract.py', workflow)
        source = (root / 'tools/build_release.py').read_text()
        self.assertIn('smoke_package(unpacked / executable, logs, args.timeout)', source)
        self.assertIn('smoke_save_contract(unpacked / executable, logs, args.timeout, run_checked)', source)


if __name__ == '__main__':
    unittest.main()
