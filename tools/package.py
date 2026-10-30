"""Package tested local outputs and editable source without caches or signing material."""
from pathlib import Path
import hashlib, shutil, zipfile
root=Path(__file__).resolve().parents[1]
builds=root/'builds'
windows=builds/'windows'
exe=windows/'AstralForge.exe'
apk=builds/'android'/'AstralForge-debug.apk'
assert exe.is_file() and apk.is_file(),'Run tools/export.sh first'

readme='''ASTRAL FORGE — WINDOWS

Run AstralForge.exe. The game is self-contained and works offline.
Default graphics use OpenGL Compatibility for broad laptop support.
Low Graphics.cmd starts Low quality. Advanced Graphics.cmd requests
Forward+ on a suitable Vulkan-capable GPU; Godot may fall back on older hardware.

Click an uncovered relic. Three identical relics clear the collection.
Clear the board to win; filling seven slots without a match ends the expedition.
Mouse wheel: zoom. Right drag: orbit. Esc: pause. F11: fullscreen.
U: Undo; R: Reweave; H: Hint; E: extra slot; Space: rotate; F: shift.
Abilities use earned coins; restarting is free and every level is solvable
without abilities. Saves are local to your user account.

This executable was exported and its embedded game pack was smoke-tested
in the Linux development environment. Native Windows hardware QA remains
necessary. See VALIDATION.md for the exact tested scope and remaining work.
Third-party engine/font notices are included in LICENSES and in Settings.
'''
(windows/'README.txt').write_text(readme,encoding='utf-8')
(windows/'Low Graphics.cmd').write_bytes(b'@echo off\r\ncd /d "%~dp0"\r\nstart "" "AstralForge.exe" --rendering-method gl_compatibility -- --low\r\n')
(windows/'Advanced Graphics.cmd').write_bytes(b'@echo off\r\ncd /d "%~dp0"\r\nstart "" "AstralForge.exe" --rendering-method forward_plus\r\n')
licenses=windows/'LICENSES';licenses.mkdir(exist_ok=True)
for path in list((root/'assets'/'licenses').glob('*.txt'))+list((root/'assets'/'fonts').glob('LICENSE*.txt')):
    shutil.copy2(path,licenses/path.name)
shutil.copy2(root/'docs'/'VALIDATION.md',windows/'VALIDATION.md')

preview=root/'docs'/'screenshots';preview.mkdir(parents=True,exist_ok=True)
for source,target in [('01-main-menu','main-menu'),('02-observatory','gameplay'),('07-portrait','portrait')]:
    path=root/'artifacts'/(source+'.png')
    if path.exists():shutil.copy2(path,preview/(target+'.png'))

def archive(path,files,prefix=''):
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for source,relative in files:z.write(source,prefix+str(relative).replace('\\','/'))
    with zipfile.ZipFile(path) as z:assert z.testzip() is None
    print(path.name,round(path.stat().st_size/1024/1024,1),'MiB; ZIP integrity verified')

archive(builds/'AstralForge-Windows.zip',[(p,p.relative_to(windows)) for p in windows.rglob('*') if p.is_file()])
excluded={'.git','.godot','builds','artifacts','__pycache__'}
source_files=[]
for p in root.rglob('*'):
    rel=p.relative_to(root)
    if any(part in excluded for part in rel.parts) or not p.is_file():continue
    assert p.suffix not in ('.keystore','.jks','.pem','.key'), 'Signing material must remain outside source'
    if p.suffix in ('.tmp','.pyc'):continue
    source_files.append((p,rel))
archive(builds/'AstralForge-source.zip',source_files,'AstralForge/')
lines=[]
for path in [builds/'AstralForge-Windows.zip',apk,builds/'AstralForge-source.zip']:
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(4*1024*1024),b''):h.update(chunk)
    lines.append(h.hexdigest()+'  '+str(path.relative_to(builds)))
(builds/'SHA256SUMS.txt').write_text('\n'.join(lines)+'\n')
print('Wrote SHA256SUMS.txt for all three deliverables.')
