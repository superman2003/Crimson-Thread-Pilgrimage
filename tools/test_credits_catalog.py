#!/usr/bin/env python3
"""Byte-exact release notice packaging and stale-payload rejection."""
from pathlib import Path
import json
import tempfile
import unittest
from build_credits_catalog import build, synchronize, OUTPUT, MAX_DOCUMENT


class CreditsCatalogTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'godot').mkdir()
        (self.root / 'LICENSE').write_text('MIT\nCopyright preserved\n')
        (self.root / 'THIRD_PARTY_NOTICES.md').write_text('# 来源\n中文说明与 [链接] 原文\n')

    def test_exact_sources_and_stable_index(self):
        self.assertTrue(synchronize(self.root, False))
        self.assertEqual(synchronize(self.root, True), [])
        first = build(self.root)
        index = json.loads(first[OUTPUT / 'index.json'])
        self.assertEqual(len(index['entries']), 2)
        for entry in index['entries']:
            path = OUTPUT / (entry['id'] + '.txt')
            self.assertEqual(first[path], (self.root / entry['source']).read_bytes())
            self.assertEqual(entry['bytes'], len(first[path]))
        self.assertEqual(build(self.root), first)

    def test_new_source_changes_payload_and_rejects_stale_text(self):
        synchronize(self.root, False)
        (self.root / 'LICENSE').write_text('MIT\nNew copyright\n')
        errors = synchronize(self.root, True)
        self.assertGreaterEqual(len(errors), 2)
        synchronize(self.root, False)
        self.assertEqual(synchronize(self.root, True), [])

    def test_runtime_notices_included_but_development_notices_excluded(self):
        for folder in ['assets/fonts', 'addons/Plugin', 'tools', '.godot']:
            path = self.root / 'godot' / folder
            path.mkdir(parents=True)
            (path / 'OFL.txt').write_text('Font terms\n')
        index = json.loads(build(self.root)[OUTPUT / 'index.json'])
        sources = [entry['source'] for entry in index['entries']]
        self.assertIn('godot/assets/fonts/OFL.txt', sources)
        self.assertIn('godot/addons/Plugin/OFL.txt', sources)
        self.assertNotIn('godot/tools/OFL.txt', sources)
        self.assertNotIn('godot/.godot/OFL.txt', sources)

    def test_unexpected_payload_is_reported_and_removed_only_when_building(self):
        synchronize(self.root, False)
        extra = self.root / OUTPUT / 'orphan.txt'
        extra.write_text('obsolete source')
        self.assertTrue(any('unexpected' in error for error in synchronize(self.root, True)))
        self.assertTrue(extra.exists())
        synchronize(self.root, False)
        self.assertFalse(extra.exists())

    def test_missing_empty_oversized_and_invalid_utf8_sources_fail(self):
        path = self.root / 'LICENSE'
        for raw in [b'', b'x' * (MAX_DOCUMENT + 1), b'\xff', b'MIT\x00bad']:
            with self.subTest(raw_size=len(raw)):
                path.write_bytes(raw)
                with self.assertRaises((ValueError, UnicodeError)):build(self.root)
        path.unlink()
        with self.assertRaises(ValueError):build(self.root)

    def test_utf8_bom_is_retained_in_packaged_source(self):
        raw = b'\xef\xbb\xbfMIT\nCopyright\n'
        (self.root / 'LICENSE').write_bytes(raw)
        output = build(self.root)
        self.assertIn(raw, output.values())

    def test_crlf_notice_is_not_rewritten_to_platform_newlines(self):
        raw = 'MIT\r\n版权所有与原文\r\n'.encode('utf-8')
        (self.root / 'LICENSE').write_bytes(raw)
        output = build(self.root)
        self.assertIn(raw, output.values())
        synchronize(self.root, False)
        self.assertEqual(synchronize(self.root, True), [])

    def test_check_reports_corruption_without_repairing_packaged_files(self):
        synchronize(self.root, False)
        output = self.root / OUTPUT
        document = next(output.glob('*.txt'))
        document.write_bytes(b'changed packaged content')
        before = {path.name: path.read_bytes() for path in output.iterdir()}
        self.assertTrue(synchronize(self.root, True))
        after = {path.name: path.read_bytes() for path in output.iterdir()}
        self.assertEqual(before, after)

    def test_symlink_sources_and_outputs_are_never_replaced(self):
        source = self.root / 'real-license'
        source.write_text('MIT\n')
        (self.root / 'LICENSE').unlink()
        (self.root / 'LICENSE').symlink_to(source)
        with self.assertRaises(ValueError):build(self.root)
        (self.root / 'LICENSE').unlink()
        (self.root / 'LICENSE').write_text('MIT\n')
        expected = build(self.root)
        target = next(path for path in expected if path.suffix == '.txt')
        (self.root / target).parent.mkdir(parents=True)
        (self.root / target).symlink_to(source)
        with self.assertRaises(ValueError):synchronize(self.root, False)
        self.assertEqual(source.read_text(), 'MIT\n')


if __name__ == '__main__':unittest.main()
