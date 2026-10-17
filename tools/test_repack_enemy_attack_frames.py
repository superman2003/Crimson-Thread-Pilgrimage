#!/usr/bin/env python3
"""Offline, source-byte and registration regression tests for the four-pose repair."""
from io import BytesIO
from pathlib import Path
import os
import shutil
import sys
import tempfile
import subprocess
import unittest
from unittest.mock import patch
import numpy as np
from PIL import Image
import repack_enemy_attack_frames as repair

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    'gear_sentinel': [(52766,9403,4024,0),(48551,9192,3032,3748)],
    'page_duelist': [(52440,13926,5346,0),(41703,10926,3076,4748)],
}

class EnemyAttackIntegrityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.builds={k:repair.build(ROOT,k) for k in repair.CONFIG}

    def test_original_source_bytes_verified_without_git_history(self):
        for kind,cfg in repair.CONFIG.items():
            path=repair.ASSETS/kind/'atlas.png'
            raw=(ROOT/path).read_bytes()
            self.assertEqual(repair.digest(raw),cfg['sha256'])
            # A fixed digest verifies every source byte in shallow/no-history CI.
            snapshot=(ROOT/repair.ASSETS/kind/'attack_source_manifest.json').read_bytes()
            self.assertEqual(repair.digest(snapshot),cfg['manifest_sha256'])

    def test_reproduction_matches_every_deliverable_byte(self):
        for kind,build in self.builds.items():
            for filename,expected in build[4].items():
                self.assertEqual((ROOT/repair.ASSETS/kind/filename).read_bytes(),expected,filename)

    def test_png_outputs_are_real_rgba_not_lfs_pointers(self):
        for kind,build in self.builds.items():
            for filename,data in build[4].items():
                if filename.endswith('.png'):
                    self.assertTrue(data.startswith(b'\x89PNG\r\n\x1a\n'))
                    image=Image.open(BytesIO(data))
                    self.assertEqual(image.mode,'RGBA')
                    self.assertEqual(list(image.size),build[2]['canvas'])

    def test_inherited_png_git_attributes_preserved(self):
        paths=[str(repair.ASSETS/k/f'attack_{i}_isolated.png') for k in repair.CONFIG for i in range(2)]
        result=subprocess.check_output(['git','check-attr','filter','diff','merge','--',*paths],cwd=ROOT,text=True)
        self.assertEqual(result.count(': unset'),12)

    def test_masks_disjoint_and_reversible_rle(self):
        for kind,(source,old,new,masks,outputs,record) in self.builds.items():
            self.assertFalse(np.any(masks[0]&masks[1]))
            for mask,frame in zip(masks,record['frames']):
                restored=repair.unroll(frame['source_mask_rle_y_x0_x1'])
                self.assertTrue(np.array_equal(restored,mask))
                self.assertEqual(repair.digest(restored.tobytes()),frame['source_mask_sha256'])
                self.assertTrue(np.all(source[:,:,3][mask]>0))

    def test_every_output_pixel_copies_exact_source_rgba(self):
        for kind,(source,old,new,masks,outputs,record) in self.builds.items():
            for mask,frame in zip(masks,record['frames']):
                out=np.array(Image.open(BytesIO(outputs[frame['output']])))
                ys,xs=np.nonzero(mask);dx,dy=frame['source_to_output_translation_xy']
                self.assertTrue(np.array_equal(out[ys+dy,xs+dx],source[ys,xs]))
                self.assertEqual(np.count_nonzero(out[:,:,3]),len(xs))
                self.assertEqual(repair.digest(out.tobytes()),frame['output_rgba_sha256'])
                self.assertEqual(repair.digest(outputs[frame['output']]),frame['output_sha256'])
                # Everything not assigned from the original is transparent black.
                self.assertTrue(np.all(out[out[:,:,3]==0]==0))

    def test_low_alpha_edges_not_thresholded(self):
        for kind,build in self.builds.items():
            for i,frame in enumerate(build[5]['frames']):
                expected=EXPECTED[kind][i]
                self.assertEqual(frame['selected_pixels'],expected[0])
                self.assertEqual(frame['selected_alpha_1_2'],expected[1])
                self.assertGreater(frame['selected_alpha_1_128'],10000)
                self.assertGreater(frame['selected_alpha_histogram'][1],5000)
                self.assertGreater(frame['selected_alpha_histogram'][2],2000)

    def test_weapon_recovery_and_other_pose_exclusion(self):
        for kind,(source,old,new,masks,outputs,record) in self.builds.items():
            for i,frame in enumerate(record['frames']):
                expected=EXPECTED[kind][i]
                self.assertEqual(frame['recovered_pixels_outside_old_region'],expected[2])
                self.assertEqual(frame['other_pose_pixels_excluded_from_old_region'],expected[3])
                self.assertGreater(frame['weapon_pixels_recovered_outside_old_region'],500)
                self.assertGreater(frame['other_pose_pixels_excluded_from_expanded_bbox'],0)
                # The old crop boundary cuts the owned weapon: recover original pixels
                # on BOTH sides, with no scaling, fill, inferred contour or interpolation.
                x,y,w,h=frame['old_frame']['region'];wx0,wy0,wx1,wy1=frame['weapon_source_inspection_box_xyxy']
                self.assertGreater(np.count_nonzero(masks[i][wy0:wy1,x+w-2:x+w]),0)
                self.assertGreater(np.count_nonzero(masks[i][wy0:wy1,x+w:x+w+2]),0)

    def test_source_and_output_edges_are_not_cut(self):
        for kind,build in self.builds.items():
            for frame in build[5]['frames']:
                out=np.array(Image.open(BytesIO(build[4][frame['output']])))
                self.assertFalse(np.any(out[0,:,3]))
                self.assertFalse(np.any(out[-1,:,3]))
                self.assertFalse(np.any(out[:,0,3]))
                self.assertFalse(np.any(out[:,-1,3]))
                x0,y0,x1,y1=frame['source_bbox_xyxy']
                self.assertGreater(x0,0);self.assertGreater(y0,0)
                self.assertLess(x1,1536);self.assertLess(y1,1024)

    def test_page_bridge_exclusion_is_geometric_not_alpha_filter(self):
        source,old,new,masks,outputs,record=self.builds['page_duelist']
        broad=np.zeros(source.shape[:2],bool);broad[700:990,:560]=True
        connected=repair.seed_component(source[:,:,3],broad,(250,800))
        removed=connected&~masks[0]
        self.assertEqual(int(removed.sum()),1522)
        self.assertTrue(np.all(source[:,:,3][removed]==1))
        self.assertGreater(np.count_nonzero(masks[0]&(source[:,:,3]==1)),8000)

    def test_attack_all_pixel_centers_preserved_both_facings(self):
        for kind,(source,old,new,masks,outputs,record) in self.builds.items():
            for mask,frame in zip(masks,record['frames']):
                ys,xs=np.nonzero(mask)
                r=frame['old_frame']['region'];m=frame['old_frame']['margin']
                dx,dy=frame['source_to_output_translation_xy']
                before=np.column_stack((xs-r[0]+m[0]-old['canvas'][0]/2,ys-r[1]+m[1]-old['canvas'][1]/2))
                after=np.column_stack((xs+dx-new['canvas'][0]/2,ys+dy-new['canvas'][1]/2))
                self.assertTrue(np.array_equal(before,after))
                for facing in (1,-1):
                    transform=np.array([facing*old['visual_scale'],old['visual_scale']])
                    # Base sprite.position has unchanged visual_offset; same local
                    # coordinates also remain equal under arbitrary runtime tweens.
                    self.assertTrue(np.array_equal(before*transform+old['visual_offset'],after*transform+new['visual_offset']))

    def test_ten_nonattack_frames_keep_actual_rgba_and_display_coordinates(self):
        for kind,(source,old,new,masks,outputs,record) in self.builds.items():
            count=0
            for old_anim,new_anim in zip(old['animations'],new['animations']):
                if old_anim['name']=='attack':continue
                for a,b in zip(old_anim['frames'],new_anim['frames']):
                    count+=1
                    self.assertEqual(a['atlas'],b['atlas']);self.assertEqual(a['region'],b['region'])
                    self.assertEqual(b['margin'],[a['margin'][0]+repair.PAD[0],a['margin'][1]+repair.PAD[1],a['margin'][2]+2*repair.PAD[0],a['margin'][3]+2*repair.PAD[1]])
                    r=a['region'];yy,xx=np.indices((r[3],r[2]))
                    for axis,values in enumerate((xx,yy)):
                        before=values+a['margin'][axis]-old['canvas'][axis]/2
                        after=values+b['margin'][axis]-new['canvas'][axis]/2
                        self.assertTrue(np.array_equal(before,after))
                    old_render=repair.display_frame(ROOT,kind,a,old['canvas'])
                    new_render=repair.display_frame(ROOT,kind,b,new['canvas'],padded=False)
                    self.assertTrue(np.array_equal(old_render,new_render))
            self.assertEqual(count,10)

    def test_animation_and_scale_contract_unchanged(self):
        for kind,(source,old,new,masks,outputs,record) in self.builds.items():
            for field in ('source','kind','display_height','visual_scale','visual_offset','motion','atlas_size'):
                self.assertEqual(old[field],new[field])
            self.assertEqual(len(old['animations']),len(new['animations']))
            for a,b in zip(old['animations'],new['animations']):
                for field in ('name','fps','loop'):self.assertEqual(a[field],b[field])
                self.assertEqual(len(a['frames']),len(b['frames']))
                for frame in b['frames']:
                    self.assertEqual([frame['region'][2]+frame['margin'][2],frame['region'][3]+frame['margin'][3]],new['canvas'])

    def test_source_drift_requires_new_review(self):
        # Check the public gate without mutating any real source.
        with patch.object(Path,'read_bytes',return_value=b'changed source'):
            with self.assertRaisesRegex(ValueError,'source atlas hash changed'):
                repair.build(ROOT,'gear_sentinel')

    def test_manifest_snapshot_drift_requires_review(self):
        with patch.object(Path,'read_bytes',return_value=b'changed source manifest'):
            with self.assertRaisesRegex(ValueError,'source manifest hash changed'):
                repair.baseline(ROOT,'gear_sentinel')

    def test_full_check_without_git_history_or_git_executable(self):
        # Real subprocess against a standalone asset copy: no .git, no BASE
        # object and no Git executable in PATH. This must verify ALL core bytes.
        with tempfile.TemporaryDirectory(prefix='enemy-atlas-no-history-') as temp:
            standalone=Path(temp)
            for kind,build in self.builds.items():
                target=standalone/repair.ASSETS/kind
                target.mkdir(parents=True)
                names=['atlas.png','attack_source_manifest.json',*build[4]]
                for name in names:
                    shutil.copyfile(ROOT/repair.ASSETS/kind/name,target/name)
            self.assertFalse((standalone/'.git').exists())
            result=subprocess.run([sys.executable,str(ROOT/'tools/repack_enemy_attack_frames.py'),
                                   '--root',str(standalone),'--check'],cwd=standalone,
                                  env={**os.environ,'PATH':''},capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertEqual(result.stdout.count('VERIFIED'),2)

    def test_invalid_seed_and_out_of_canvas_refused(self):
        with self.assertRaises(ValueError):
            repair.seed_component(np.zeros((2,2),np.uint8),np.ones((2,2),bool),(0,0))
        source=np.ones((2,2,4),np.uint8)
        with self.assertRaises(ValueError):
            repair.registered_copy(source,np.ones((2,2),bool),{'region':[1000,1000,2,2],'margin':[0,0,0,0]},[1,1])

if __name__=='__main__':
    unittest.main(verbosity=2)
