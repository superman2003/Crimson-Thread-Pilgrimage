"""Validate packaged alpha bounds and declare source-art limitations separately."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'godot/assets/sprites/player/generated_hero_v3'

def main():
    manifest = json.loads((PACK / 'manifest.json').read_text())
    audit = json.loads((PACK / 'crop_audit.json').read_text())
    paths = {path for animation in manifest['animations'] for path in animation['frames']}
    assert len(paths) == len(audit) == 80
    assert not any(entry['output_clipped'] for entry in audit)
    for path in sorted(paths):
        image = Image.open(ROOT / 'godot' / path.removeprefix('res://')).convert('RGBA')
        assert list(image.size) == manifest['frame_size'], path
        bounds = image.getbbox()
        assert bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < image.width and bounds[3] < image.height, path
    print(json.dumps({'frames': len(paths), 'output_clipped': 0,
        'source_edge_review': sum(entry['source_edge_contact'] for entry in audit),
        'ambiguous_source_poses': sum(entry['ambiguous_connected_pose'] for entry in audit)}))

if __name__ == '__main__':
    main()
