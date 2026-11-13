"""Regression cases for hidden anchor jumps and hydrated LFS preview pointers."""
import io
import unittest
from PIL import Image
from audit_creature_redraw_handoffs import measure
from check_redraw_preview_blobs import validate_image


class HandoffContracts(unittest.TestCase):
    def manifest(self, margins):
        return dict(canvas=[100, 80], animations=[
            dict(name=name, frames=[dict(margin=[x, y, 0, 0]) for x, y in positions])
            for name, positions in margins.items()])

    def test_fixed_canvas_detects_anchor_jump_without_recentering(self):
        data = self.manifest(dict(windup=[(5, 5)], attack=[(50, 5)]))
        edges = [dict(source='windup', source_frame=-1, target='attack', target_frame=0)]
        rows = measure(data, edges, lambda _: Image.new('L', (20, 20), 255))
        self.assertEqual(rows[0]['change'], 1)

    def test_every_walking_cel_can_enter_the_tell(self):
        data = self.manifest(dict(walk=[(5, 5)] * 31 + [(50, 5)], tell=[(5, 5)]))
        edges = [dict(source='walk', source_frame='all', target='tell', target_frame=0)]
        rows = measure(data, edges, lambda _: Image.new('L', (20, 20), 255))
        self.assertEqual(len(rows), 32)
        self.assertEqual([r['source_frame'] for r in rows if r['change'] > .5], [31])

    def test_missing_clip_fails_instead_of_skipping_a_handoff(self):
        with self.assertRaisesRegex(ValueError, 'Missing production'):
            measure(self.manifest(dict(walk=[(5, 5)])),
                    [dict(source='walk', source_frame=0, target='tell', target_frame=0)], None)

    def test_out_of_canvas_frame_cannot_hide_jump_by_clipping(self):
        with self.assertRaisesRegex(ValueError, 'leaves the fixed canvas'):
            measure(self.manifest(dict(a=[(95, 5)], b=[(5, 5)])),
                    [dict(source='a', source_frame=0, target='b', target_frame=0)],
                    lambda _: Image.new('L', (20, 20), 255))

    def test_pointer_is_rejected_even_if_worktree_was_hydrated(self):
        with self.assertRaisesRegex(ValueError, 'still a pointer in Git'):
            validate_image(b'version https://git-lfs.github.com/spec/v1\noid sha256:abc\nsize 123\n', 'preview.jpg')

    def test_real_thumbnail_blob_is_accepted(self):
        blob = io.BytesIO()
        Image.new('RGB', (20, 20)).save(blob, 'JPEG')
        validate_image(blob.getvalue(), 'preview.jpg')


if __name__ == '__main__':
    unittest.main()
