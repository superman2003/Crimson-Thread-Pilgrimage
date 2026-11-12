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


if __name__ == '__main__':
    unittest.main()
