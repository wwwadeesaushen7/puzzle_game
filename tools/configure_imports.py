"""Select GPU texture compression for generated 3D art; retain authored normal-map settings.
Run after the first Godot import, then run Godot --headless --import again.
"""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
count=0
for directory in ['models','textures']:
    for p in (root/'assets'/directory).glob('*.png.import'):
        text=p.read_text()
        updated=text.replace('compress/mode=0','compress/mode=2')
        if updated!=text:
            p.write_text(updated)
            count+=1
print('Configured GPU compression for',count,'textures (S3TC on desktop, ETC2/ASTC on Android).')
