"""Exercise immutable rig/core and corrupt/incomplete production deliveries."""
from copy import deepcopy
from hashlib import sha256
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
import enemy_transition_art as art

KIND='moss_larva'
SOURCE_ROOT=art.ROOT

class TransitionBuild(unittest.TestCase):
    def setUp(self):
        self.scratch=tempfile.TemporaryDirectory(prefix='transition-art-test-')
        self.addCleanup(self.scratch.cleanup)
        self.root=Path(self.scratch.name)
        request=self.root/'art_requests/enemy_transitions_v1'
        self.spec=json.loads((art.REQUEST/'jobs'/f'{KIND}.json').read_text(encoding='utf-8'))
        targets=[self.spec['baseline']]+[row['drawing'] for row in self.spec['accepted'].values()]
        for relative in targets:
            target=self.root/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(SOURCE_ROOT/relative,target)
        for obj,key,value in [(art,'ROOT',self.root),(art,'REQUEST',request),
                              (art.onion,'CREATURES',self.root/'godot/assets/sprites/original_creatures')]:
            manager=patch.object(obj,key,value)
            manager.start();self.addCleanup(manager.stop)
        self.save_spec()

    def save_spec(self):art.write(art.spec_path(KIND),self.spec)

    def test_composite_preserves_every_core_clip_and_rig(self):
        baseline=deepcopy(art.baseline(KIND)[1])
        built=art.build(KIND)
        self.assertEqual(built['animations'][:-2],baseline['animations'])
        for name in ['canvas','visual_scale','visual_offset','display_height']:
            if name in baseline:self.assertEqual(built[name],baseline[name])
        for action,duration in art.DURATIONS.items():
            clip=art.onion.clips_of(built)[action]
            self.assertEqual(len(clip['frames']),7)
            self.assertFalse(clip['loop'])
            self.assertAlmostEqual(7/clip['fps'],duration)
            for frame in clip['frames'][1:]:
                self.assertIn('motion_transition_',frame['atlas'])
                self.assertEqual(frame['margin'][2]+frame['region'][2],baseline['canvas'][0])
                self.assertEqual(frame['margin'][3]+frame['region'][3],baseline['canvas'][1])
        art.build(KIND,check=True)

    def test_incomplete_delivery_cannot_publish_a_partial_gesture(self):
        del self.spec['accepted']['turn#5'];self.save_spec()
        with self.assertRaisesRegex(ValueError,'Missing turn drawing 5'):art.build(KIND)

    def test_modified_accepted_drawing_is_rejected(self):
        path=self.root/self.spec['accepted']['turn#0']['drawing']
        path.write_bytes(path.read_bytes()+b'changed')
        with self.assertRaisesRegex(ValueError,'Accepted drawing changed'):art.build(KIND)

    def test_new_core_art_requires_explicit_reference_review(self):
        path=self.root/self.spec['baseline']
        path.write_bytes(path.read_bytes()+b'\n')
        with self.assertRaisesRegex(ValueError,'Baseline changed'):art.build(KIND)

    def test_reproducibility_check_detects_packed_atlas_changes(self):
        art.build(KIND)
        path=art.onion.CREATURES/KIND/'motion_transition_00.png'
        with Image.open(path) as source:image=source.convert('RGBA')
        image.putpixel((0,0),(255,0,0,255));image.save(path)
        with self.assertRaisesRegex(ValueError,'Stale atlas'):art.build(KIND,check=True)

class TransitionSourceAudit(unittest.TestCase):
    def test_changed_registered_pixel_still_fails_exact_source_audit(self):
        register=art.onion.register
        def damaged(*args,**kwargs):
            rows,fit=register(*args,**kwargs)
            image=rows[0]['image'].copy()
            pixel=image.getpixel((0,0))
            image.putpixel((0,0),((pixel[0]+1)%256,*pixel[1:]))
            rows[0]['image']=image
            return rows,fit
        with patch.object(art.onion,'register',side_effect=damaged):
            with self.assertRaisesRegex(ValueError,'Registered drawing was modified'):
                art.audit_sources(KIND)

if __name__=='__main__':unittest.main()
