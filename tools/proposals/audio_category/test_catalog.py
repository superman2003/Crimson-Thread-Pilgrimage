#!/usr/bin/env python3
"""Negative contracts for the category catalog, using real small audio fixtures."""
import copy
import tempfile
import unittest
import wave
from pathlib import Path
from unittest.mock import patch
import build_catalog as catalog


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.pack = self.root / 'assets/proposals/test'
        self.pack.mkdir(parents=True)
        self.path = self.pack / 'cue.wav'
        with wave.open(str(self.path), 'wb') as w:
            w.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
            w.writeframes(b'\0\0' * 4800)
        self.item = {'id': 'cue', 'title': 'Cue', 'region_id': 'global', 'role': 'test', 'file': 'cue.wav', 'loop': False, 'duration_seconds': 0.1, 'sample_rate': 48000, 'channels': 1}

    def tearDown(self):
        self.temp.cleanup()

    def normalize(self, **changes):
        return catalog.normalize_item(self.root, 'test', 'sfx', dict(self.item, **changes))

    def test_real_probe_and_hash(self):
        result = self.normalize()
        self.assertEqual(result['sample_rate'], 48000)
        self.assertEqual(result['channels'], 1)
        self.assertEqual(len(result['sha256']), 64)

    def test_missing_file(self):
        with self.assertRaises(ValueError): self.normalize(file='missing.wav')

    def test_parent_path_rejected(self):
        with self.assertRaises(ValueError): self.normalize(file='../test/cue.wav')

    def test_absolute_path_rejected(self):
        with self.assertRaises(ValueError): catalog.local_file(self.root, str(self.path))

    def test_symlink_rejected(self):
        (self.pack / 'link.wav').symlink_to(self.path)
        with self.assertRaises(ValueError): self.normalize(file='link.wav')

    def test_pointer_rejected(self):
        self.path.write_text('version https://git-lfs.github.com/spec/v1\noid sha256:abc\n')
        with self.assertRaises(ValueError): self.normalize()

    def test_declared_duration_rejected(self):
        with self.assertRaises(ValueError): self.normalize(duration_seconds=1.0)

    def test_declared_channels_rejected(self):
        with self.assertRaises(ValueError): self.normalize(channels=2)

    def test_nonfinite_gain_rejected(self):
        with self.assertRaises(ValueError): self.normalize(recommended_playback_gain_db=float('nan'))

    def test_invalid_loop_range_rejected(self):
        with self.assertRaises(ValueError): self.normalize(loop=True, loop_start_sample=10, loop_end_sample_exclusive=50000)

    def test_loop_boolean_required(self):
        with self.assertRaises(ValueError): self.normalize(loop='true')

    def test_profile_requires_six_regions(self):
        with self.assertRaises(ValueError): catalog.validate_profiles({'profiles': []}, [])


if __name__ == '__main__':
    unittest.main()
