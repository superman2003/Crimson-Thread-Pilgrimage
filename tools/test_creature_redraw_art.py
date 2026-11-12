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

art._real_extract = art.extract


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

    def test_sheet_scale_matches_the_replaced_body_area_not_its_height(self):
        # Same height as the reference but twice as wide: height registration
        # would keep it at twice the body mass of every untouched clip.
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder)/'wide.png'
            sheet = Image.new('RGBA', (160,80))
            ImageDraw.Draw(sheet).rectangle((20,20,99,59), fill='white')
            sheet.save(source)
            job = dict(source=str(source),sha256=sha256(source.read_bytes()).hexdigest(),
                       count=1,grid=[1,1],reference_height=40,center_x=100,ground_y=150)
            by_height, scale = art.extract(job,(200,200))
            self.assertEqual(scale,1)
            drawings, scale = art.extract(job,(200,200),target_area=1600)
            self.assertAlmostEqual(scale,.5**.5,places=2)
            width, height = drawings[0][0].size
            self.assertAlmostEqual(width*height,1600,delta=120)
            self.assertEqual(drawings[0][1][1]+height,150)

    def test_delivery_is_rejected_when_its_body_size_leaves_the_replaced_clip(self):
        with patch.object(art,'body_area',lambda clip,canvas: 1.0), \
             patch.object(art,'extract',lambda job,canvas,target=None: art.__dict__['_real_extract'](job,canvas)):
            with self.assertRaisesRegex(ValueError,'body size differs'):
                art.build('rust_crown_guardian',check=True)

    def test_every_registered_clip_keeps_the_replaced_body_area(self):
        for path in sorted((art.REQUEST/'jobs').glob('*.json')):
            record = art.read(art.fit.CREATURES/path.stem/art.LAYER)['redraw_record']['clips']
            for clip, measured in record.items():
                self.assertLessEqual(abs(measured['body_area_ratio']-1),art.BODY_AREA_TOLERANCE,(path.stem,clip))


    def test_leg_change_separates_a_sliding_still_from_a_stride(self):
        import numpy as np
        def frame(feet):
            mask = np.zeros((100,100), bool)
            mask[20:70,30:70] = True
            for x in feet: mask[70:100,x:x+8] = True
            return mask
        still = [frame((34,58)) for _ in range(8)]
        stride = [frame((34+s,58-s)) for s in (0,6,12,6,0,-6,-12,-6)]
        self.assertEqual(art.leg_change(still,True),0)
        self.assertGreater(art.leg_change(stride,True),art.LEG_CHANGE_FLOOR)

    def test_walk_delivery_with_still_legs_is_rejected_unless_it_awaits_a_redraw(self):
        self.assertIn(('moss_larva','walk'),art.stride_pending())
        with patch.object(art,'stride_pending',lambda: set()):
            with self.assertRaisesRegex(ValueError,'legs barely move'):
                art.build('moss_larva',check=True)

    def test_pending_stride_list_only_holds_walks_that_are_still_below_the_floor(self):
        import contextlib
        pending = art.read(art.REQUEST/'stride_pending.json')
        self.assertEqual(pending['floor'],art.LEG_CHANGE_FLOOR)
        for row in pending['clips']:
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                art.build(row['kind'],check=True)
            measured = json.loads(out.getvalue())['leg_change'][row['clip']]
            self.assertLess(measured,art.LEG_CHANGE_FLOOR,f"{row['kind']} now strides; remove it from stride_pending.json")


if __name__ == '__main__':
    unittest.main()
