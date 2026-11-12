"""Reject missing deliveries and corrupted registration metadata before packing."""
from contextlib import redirect_stderr
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from hashlib import sha256
from PIL import Image, ImageDraw
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

    def test_hover_registration_preserves_authored_vertical_motion(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder)/'hover.png'
            sheet = Image.new('RGBA', (128,64))
            draw = ImageDraw.Draw(sheet)
            draw.rectangle((20,18,43,45), fill='white')
            draw.rectangle((84,22,107,49), fill='white')
            sheet.save(source)
            job = dict(source=str(source),sha256=sha256(source.read_bytes()).hexdigest(),
                       count=2,grid=[2,1],reference_height=28,center_x=50,
                       center_y=50,ground_y=80,registration='cell_center')
            drawings, scale = art.extract(job,(100,100))
            self.assertEqual(scale,1)
            self.assertEqual(drawings[1][1][1]-drawings[0][1][1],4)
            job.pop('registration')
            grounded, _ = art.extract(job,(100,100))
            self.assertEqual(grounded[1][1][1],grounded[0][1][1])

    def test_unknown_registration_cannot_silently_snap_a_flying_actor_to_ground(self):
        with self.assertRaisesRegex(ValueError,'Unknown drawing registration'):
            art.extract(dict(registration='typo'),(100,100))

    def test_faint_background_is_rejected_even_below_silhouette_threshold(self):
        with tempfile.TemporaryDirectory() as folder:
            source=Path(folder)/'fog.png'
            sheet=Image.new('RGBA',(64,64),(250,250,250,90))
            ImageDraw.Draw(sheet).rectangle((20,18,43,45),fill='white')
            sheet.save(source)
            job=dict(source=str(source),sha256=sha256(source.read_bytes()).hexdigest(),
                     count=1,grid=[1,1],reference_height=28,center_x=50,ground_y=80)
            with self.assertRaisesRegex(ValueError,'Nontransparent cell gutter'):
                art.extract(job,(100,100))


if __name__ == '__main__':
    unittest.main()
