"""Verify shipped speech, audible phrase structure and deterministic provenance."""
import io
import json
from hashlib import sha256
import unittest
import wave
import numpy as np
import build_npc_insect_speech as build


class SpeechBank(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalogue = json.loads(build.CATALOGUE.read_text(encoding='utf-8'))
        cls.design = json.loads(build.DESIGN.read_text(encoding='utf-8'))
        cls.rows = []
        for actor, spec in cls.catalogue['actors'].items():
            for phrase, row in spec['clips'].items():
                path = build.ROOT / 'godot' / row['path'].removeprefix('res://')
                data = path.read_bytes()
                with wave.open(io.BytesIO(data), 'rb') as source:
                    params = source.getparams()
                    pcm = np.frombuffer(source.readframes(source.getnframes()), dtype='<i2').astype(np.int32)
                cls.rows.append((actor, phrase, row, data, params, pcm))

    def test_every_named_character_has_six_unique_phrases(self):
        actors = json.loads((build.ROOT / 'godot/data/original_world_art_designs.json').read_text(encoding='utf-8'))['npcs']
        self.assertEqual(set(self.catalogue['actors']), {a['id'] for a in actors})
        self.assertEqual(len(actors), 25)
        self.assertEqual(len(self.rows), 150)
        self.assertEqual(len({sha256(r[3]).hexdigest() for r in self.rows}), 150)
        for actor in self.catalogue['actors'].values():
            self.assertEqual(set(actor['clips']), set(self.design['phrases']))

    def test_original_pcm_and_catalogue_match(self):
        self.assertEqual(self.catalogue['design_sha256'], sha256(build.DESIGN.read_bytes()).hexdigest())
        for actor, phrase, row, data, params, pcm in self.rows:
            with self.subTest(actor=actor, phrase=phrase):
                self.assertEqual((params.nchannels, params.sampwidth, params.framerate, params.comptype), (1, 2, 22050, 'NONE'))
                self.assertEqual(sha256(data).hexdigest(), row['sha256'])
                self.assertEqual(params.nframes, row['samples'])
                self.assertAlmostEqual(len(pcm) / 22050, row['duration'], places=5)
                self.assertGreater(row['duration'], 0.5)
                self.assertLess(row['duration'], 2.5)

    def test_phrases_have_syllables_and_internal_pauses(self):
        for actor, phrase, row, _, _, pcm in self.rows:
            with self.subTest(actor=actor, phrase=phrase):
                self.assertGreaterEqual(len(row['cues']), 3)
                previous = 0.0
                for cue in row['cues']:
                    self.assertGreaterEqual(cue['start'], previous)
                    self.assertGreater(cue['end'], cue['start'])
                    previous = cue['end']
                self.assertGreaterEqual(row['voiced_until'] + 0.00001, previous)
                self.assertLess(row['voiced_until'], row['duration'])
                # Quiet word gaps remain identifiable through the echo voices;
                # reflected breath need not become mathematically zero.
                power = pcm.astype(float) ** 2
                window = round(0.012 * 22050)
                integral = np.concatenate(([0.0], np.cumsum(power)))
                envelope = np.sqrt((integral[window:] - integral[:-window]) / window)
                quiet = envelope < np.sqrt(power.mean()) * 0.30
                start = round(row['cues'][0]['start'] * 22050) + 1
                end = round(row['cues'][-1]['end'] * 22050) - 1
                padded = np.pad(quiet[start:end].astype(np.int8), (1, 1))
                edges = np.flatnonzero(np.diff(padded))
                runs = edges[1::2] - edges[::2]
                self.assertGreaterEqual(int((runs >= 0.025 * 22050).sum()), 1)

    def test_levels_are_audible_unclipped_and_have_no_cut_endings(self):
        for actor, phrase, _, _, _, pcm in self.rows:
            with self.subTest(actor=actor, phrase=phrase):
                peak = np.abs(pcm).max() / 32768
                rms = np.sqrt(np.mean(pcm.astype(float) ** 2)) / 32768
                self.assertLessEqual(peak, 0.721)
                self.assertGreater(rms, 0.06)
                self.assertLess(rms, 0.13)
                self.assertEqual(pcm[0], 0)
                self.assertTrue((pcm[-220:] == 0).all())
                self.assertLess(abs(float(pcm.mean()) / 32768), 0.01)

    def test_checked_in_bank_rebuilds(self):
        build.build(check=True)


if __name__ == '__main__':
    unittest.main()
