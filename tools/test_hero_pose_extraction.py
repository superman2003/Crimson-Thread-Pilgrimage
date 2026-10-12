"""A pose crossing a grid row must not become the next pose's boot fragment."""
import unittest
import numpy as np
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

    def test_isolated_two_by_two_keeps_detached_hook_pixels(self):
        sheet=Image.new('RGBA',(800,800))
        draw=ImageDraw.Draw(sheet)
        for row in range(2):
            for col in range(2):
                draw.rectangle((col*400+80,row*400+80,col*400+180,row*400+280),fill=(120,80,50,255))
                draw.rectangle((col*400+300,row*400+140,col*400+312,row*400+152),fill=(200,40,40,255))
        cells,bounds,ambiguous=extract_poses(sheet,columns=2,rows=2,max_fragment_distance=None)
        self.assertEqual(len(cells),4)
        self.assertFalse(ambiguous)
        self.assertEqual(sum(np.count_nonzero(np.asarray(cell)[:,:,3]) for cell in cells),np.count_nonzero(np.asarray(sheet)[:,:,3]))
        self.assertEqual(bounds[0][2],313)

if __name__=='__main__':
    unittest.main()
