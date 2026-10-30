"""Install the exact Godot templates, verified against the official SHA-512 manifest."""
from pathlib import Path
import hashlib, subprocess, zipfile, argparse
p=argparse.ArgumentParser()
p.add_argument('--cache',default='/workspace/toolchain/downloads')
p.add_argument('--data',default='/workspace/.godot-user')
a=p.parse_args()
cache=Path(a.cache);cache.mkdir(parents=True,exist_ok=True)
version='4.6.3'
archive=f'Godot_v{version}-stable_export_templates.tpz'
base=f'https://github.com/godotengine/godot-builds/releases/download/{version}-stable/'
for name in [archive,'SHA512-SUMS.txt']:
    if not (cache/name).exists():
        subprocess.run(['curl','-fL','--silent','--show-error',base+name,'-o',str(cache/name)],check=True)
expected=next(l.split()[0] for l in (cache/'SHA512-SUMS.txt').read_text().splitlines() if l.endswith(archive))
h=hashlib.sha512()
with (cache/archive).open('rb') as f:
    for block in iter(lambda:f.read(4*1024*1024),b''):h.update(block)
assert h.hexdigest()==expected,'Official template checksum mismatch'
out=Path(a.data)/'godot'/'export_templates'/f'{version}.stable'
out.mkdir(parents=True,exist_ok=True)
wanted={'windows_debug_x86_64.exe','windows_release_x86_64.exe','android_debug.apk','android_release.apk'}
with zipfile.ZipFile(cache/archive) as z:
    for name in z.namelist():
        if Path(name).name in wanted:(out/Path(name).name).write_bytes(z.read(name))
assert all((out/name).is_file() for name in wanted)
print('Verified and installed Godot',version,'Windows x64 and Android export templates.')
