"""Prepare standalone preview downloads for ordinary GitHub file hosting.

The Android package keeps every application file byte-for-byte. Stored Android
assets are ZIP-compressed (supported by Godot's AAsset streaming loader), then
the APK is aligned and signed again with the existing development key.
No engine, signing key, SDK or local save files are shipped as source dependencies.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import os
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--sdk', default='/workspace/toolchain/android-sdk')
parser.add_argument('--keystore', default='/workspace/toolchain/keys/debug.keystore')
args = parser.parse_args()
tools = Path(args.sdk) / 'build-tools' / '36.0.0'
signer = str(tools / 'apksigner')
aligner = str(tools / 'zipalign')
original = root / 'builds' / 'android' / 'AstralForge-debug.apk'
windows = root / 'builds' / 'AstralForge-Windows.zip'
output = root / 'downloads'
scratch = root / 'builds' / 'standalone'
output.mkdir(exist_ok=True)
scratch.mkdir(exist_ok=True)
assert original.is_file() and windows.is_file(), 'Export and package the game first.'
subprocess.run([signer, 'verify', str(original)], check=True)

unsigned = scratch / 'AstralForge-unsigned.apk'
aligned = scratch / 'AstralForge-aligned.apk'
expected = {}
with zipfile.ZipFile(original) as source, zipfile.ZipFile(unsigned, 'w', allowZip64=False) as target:
    assert source.testzip() is None
    for entry in source.infolist():
        # apksigner replaces old JAR signatures. These are signing metadata,
        # not application payload; preserve all other META-INF resources.
        if entry.filename == 'META-INF/MANIFEST.MF' or (
            entry.filename.startswith('META-INF/')
            and entry.filename.upper().endswith(('.RSA', '.DSA', '.EC', '.SF'))
        ):
            continue
        data = source.read(entry)
        expected[entry.filename] = hashlib.sha256(data).digest()
        info = copy.copy(entry)
        if entry.filename.startswith('assets/') and not entry.is_dir():
            info.compress_type = zipfile.ZIP_DEFLATED
        target.writestr(info, data, compresslevel=9)

subprocess.run([aligner, '-P', '16', '-f', '4', str(unsigned), str(aligned)], check=True)
android = output / 'AstralForge-Android.apk'
signing_environment = os.environ.copy()
# These are standard local Android debug credentials, never production keys.
signing_environment.setdefault('ASTRAL_APK_STOREPASS', 'android')
subprocess.run([
    signer, 'sign', '--ks', args.keystore, '--ks-key-alias', 'androiddebugkey',
    '--ks-pass', 'env:ASTRAL_APK_STOREPASS', '--v1-signing-enabled', 'false',
    '--v4-signing-enabled', 'false', '--out', str(android), str(aligned)
], check=True, env=signing_environment)
subprocess.run([signer, 'verify', '--verbose', str(android)], check=True)
subprocess.run([aligner, '-P', '16', '-c', '4', str(android)], check=True)
with zipfile.ZipFile(android) as result:
    assert result.testzip() is None
    assert set(result.namelist()) == set(expected), 'APK entry set changed.'
    for entry in result.infolist():
        assert hashlib.sha256(result.read(entry)).digest() == expected[entry.filename], entry.filename
print('Every Android application file matches the verified exported APK.')

windows_output = output / 'AstralForge-Windows.zip'
shutil.copy2(windows, windows_output)
with zipfile.ZipFile(windows_output) as package:
    assert package.testzip() is None
    assert 'AstralForge.exe' in package.namelist()

lines = []
for path in [windows_output, android]:
    assert path.stat().st_size < 100 * 1024 * 1024, 'File exceeds the GitHub regular-file limit.'
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    lines.append(digest + '  ' + path.name)
    print(path.name, round(path.stat().st_size / 1024 / 1024, 1), 'MiB')
(output / 'SHA256SUMS.txt').write_text('\n'.join(lines) + '\n')
