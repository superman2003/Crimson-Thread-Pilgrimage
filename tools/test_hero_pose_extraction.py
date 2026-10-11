"""A pose crossing a grid row must not become the next pose's boot fragment."""
import unittest
from PIL import Image, ImageDraw
from package_hero_v3 import extract_poses

class ExtractionTest(unittest.TestCase):
    def test_pose_crosses_grid_without_contaminating_next_row(self):
        sheet = Image.new('RGBA',(640,640))
        draw = ImageDraw.Draw(sheet)
        for row in range(4):
            for col in range(4):
                y = row*160+30
                bottom = y+110
                if row==0:
                    bottom=175
                draw.rectangle((col*160+45,y,col*160+95,bottom),fill=(120,80,50,255))
        cells,bounds,ambiguous=extract_poses(sheet)
        self.assertEqual(len(cells),16)
        self.assertFalse(ambiguous)
        self.assertEqual(bounds[0][3],176)
        self.assertEqual(bounds[4][1],190)
        self.assertEqual(cells[4].getbbox(),(0,0,51,111))

if __name__=='__main__':
    unittest.main()
