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

    def test_partial_delivery_must_cover_every_flagged_frame(self):
        job=dict(clip='attack',count=2,original_frame_count=6,target_frames=[1,3])
        with patch.object(art,'required_frames',return_value={2,3}):
            with self.assertRaisesRegex(ValueError,'misses listed frames:.*2'):
                art.target_indices('creature',job,dict(frames=[{}]*6))
            job['target_frames']=[2,3]
            self.assertEqual(art.target_indices('creature',job,dict(frames=[{}]*6)),[2,3])

    def test_partial_delivery_rejects_duplicate_and_out_of_range_frame_indices(self):
        for targets in ([2,2],[2,6]):
            job=dict(clip='attack',count=2,original_frame_count=6,target_frames=targets)
            with self.assertRaisesRegex(ValueError,'target frame indices'):
                art.target_indices('creature',job,dict(frames=[{}]*6))

    def test_boiling_clip_cannot_be_declared_done_by_repainting_a_few_cels(self):
        with self.assertRaisesRegex(ValueError,'complete clip redraw'):
            art.required_frames('rust_crown_guardian','walk')

    def test_partial_replacement_preserves_other_frames_clips_and_clocks(self):
        base=dict(canvas=[100,80],animations=[
            dict(name='attack',fps=12,loop=False,frames=[dict(id=i) for i in range(6)]),
            dict(name='idle',fps=8,loop=True,frames=[dict(id='idle')])])
        replacement=dict(id='new')
        result=art.replace_frames(base,{('attack',2):replacement})
        self.assertEqual(result['animations'][0]['frames'],[dict(id=0),dict(id=1),replacement,dict(id=3),dict(id=4),dict(id=5)])
        self.assertEqual(result['animations'][1],base['animations'][1])
        self.assertEqual(base['animations'][0]['frames'][2],dict(id=2))
        self.assertEqual((result['animations'][0]['fps'],result['animations'][0]['loop']),(12,False))

    def test_jobs_sharing_a_sheet_use_the_same_uniform_scale(self):
        with tempfile.TemporaryDirectory() as folder:
            source=Path(folder)/'shared.png'
            sheet=Image.new('RGBA',(128,64));draw=ImageDraw.Draw(sheet)
            draw.rectangle((20,18,43,45),fill='white')
            draw.rectangle((84,14,107,45),fill='white');sheet.save(source)
            job=dict(source=str(source),sha256=sha256(source.read_bytes()).hexdigest(),
                     count=1,grid=[2,1],scale_cells=[0,1],reference_height=30,center_x=50,ground_y=80)
            job['cells']=[0];first,scale_a=art.extract(job,(100,100))
            job['cells']=[1];second,scale_b=art.extract(job,(100,100))
            self.assertEqual((scale_a,scale_b),(1,1))
            self.assertEqual((first[0][0].height,second[0][0].height),(28,32))

    def test_repair_acceptance_checks_the_original_flagged_size_frames(self):
        row=dict(size=[dict(frame=1),dict(frame=3)])
        fits=[[1.2,0,0],[1.09,0,0],[1.25,0,0],[.96,0,0]]
        self.assertEqual(art.unrepaired_sizes(row,fits),[(1,1.09)])
        fits[1][0]=1.04
        self.assertEqual(art.unrepaired_sizes(row,fits),[])

    def test_static_feet_are_rejected_after_stride_review(self):
        spec = art.read(art.REQUEST/'jobs/moss_larva.json')
        spec['jobs'] = [next(j for j in spec['jobs'] if j['clip']=='walk')]
        spec['jobs'][0]['stride_reviewed'] = True
        with tempfile.TemporaryDirectory() as folder:
            request = Path(folder); (request/'jobs').mkdir()
            art.write(request/'jobs/moss_larva.json', spec)
            with patch.object(art, 'REQUEST', request), patch.object(art,'leg_change',return_value=.04):
                with self.assertRaisesRegex(ValueError,'Walking feet need another drawing pass'):
                    art.build('moss_larva', check=True)

    def test_fixed_lower_body_region_sees_alternating_feet(self):
        first=Image.new('RGBA',(100,100)); second=Image.new('RGBA',(100,100))
        for image in (first,second):
            ImageDraw.Draw(image).rectangle((25,20,74,60),fill='white')
        ImageDraw.Draw(first).rectangle((25,61,35,85),fill='white')
        ImageDraw.Draw(second).rectangle((64,61,74,85),fill='white')
        self.assertEqual(art.leg_change([(first,(0,0)),(first,(0,0))],(100,100)),0)
        self.assertGreater(art.leg_change([(first,(0,0)),(second,(0,0))],(100,100)),.5)

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


if __name__ == '__main__':
    unittest.main()
