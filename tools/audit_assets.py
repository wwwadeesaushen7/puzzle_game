"""Check exported GLB structure, actual triangle LODs, UVs and image sizes."""
import json, struct, io
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
report=[]
for path in sorted((root/'assets'/'models').glob('*.glb')):
    blob=path.read_bytes()
    assert blob[:4]==b'glTF'
    length,kind=struct.unpack_from('<II',blob,12)
    data=json.loads(blob[20:20+length])
    binary=blob[28+length:]
    triangles=0
    for mesh in data.get('meshes',[]):
        for p in mesh['primitives']:
            assert all(k in p['attributes'] for k in ('POSITION','NORMAL','TEXCOORD_0')),path
            triangles+=data['accessors'][p['indices']]['count']//3
    sizes=[]
    for im in data.get('images',[]):
        view=data['bufferViews'][im['bufferView']]
        image=Image.open(io.BytesIO(binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]))
        sizes.append(image.size)
    assert triangles>100,path
    if path.stem.endswith('_low'):
        assert all(max(s)<=256 for s in sizes), (path,sizes)
    report.append({'asset':path.stem,'triangles':triangles,'meshes':len(data['meshes']),'texture_sizes':sorted(set(sizes))})
for high in [r for r in report if not r['asset'].endswith('_low')]:
    low=next(r for r in report if r['asset']==high['asset']+'_low')
    assert low['triangles']<=high['triangles']
(root/'docs'/'asset-audit.json').write_text(json.dumps(report,indent=2))
print('Verified',len(report),'GLBs: geometry, normals, UVs, texture sizes and LODs.')
print('Total high/low triangles:',sum(r['triangles'] for r in report if not r['asset'].endswith('_low')),sum(r['triangles'] for r in report if r['asset'].endswith('_low')))
