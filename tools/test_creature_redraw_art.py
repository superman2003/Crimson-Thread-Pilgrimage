"""Reject missing deliveries and corrupted registration metadata before packing."""
from contextlib import redirect_stderr
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import creature_redraw_art as art


class DeliveryContracts(unittest.TestCase):
    def test_all_does_not_succeed_for_an_unhydrated_request_directory(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(art, 'REQUEST', Path(folder)):
            error = io.StringIO()
            with redirect_stderr(error), self.assertRaises(SystemExit) as result:
                art.main(['--all', '--check'])
            self.assertEqual(result.exception.code, 2)
            self.assertIn('No registered deliveries', error.getvalue())

    def corrupted(self, mutate):
        spec = art.read(art.REQUEST/'jobs/rust_crown_guardian.json')
        mutate(spec)
        with tempfile.TemporaryDirectory() as folder:
            request = Path(folder); (request/'jobs').mkdir()
            art.write(request/'jobs/rust_crown_guardian.json', spec)
            with patch.object(art, 'REQUEST', request):
                art.build('rust_crown_guardian', check=True)

    def test_duplicate_clip_cannot_silently_discard_a_registered_delivery(self):
        def duplicate(spec): spec['jobs'] = [spec['jobs'][0], spec['jobs'][0]]
        with self.assertRaisesRegex(ValueError, 'Duplicate registered clip'):
            self.corrupted(duplicate)

    def test_changed_frame_count_is_rejected_before_writing_an_atlas(self):
        def change(spec): spec['jobs'][0]['count'] += 1
        with self.assertRaisesRegex(ValueError, 'frozen frame count'):
            self.corrupted(change)


if __name__ == '__main__':
    unittest.main()
