"""Install only SDK components needed by Godot's non-Gradle APK exporter.
Official Google metadata and archive digests are verified; TLS stays enabled.
Requires Python 3, curl, unzip, a JDK and network access to dl.google.com.
Usage: python3 tools/install_android_tools.py /workspace/toolchain
"""
from pathlib import Path
import hashlib, json, os, stat, subprocess, sys, zipfile
import xml.etree.ElementTree as ET
root=Path(sys.argv[1] if len(sys.argv)>1 else '/workspace/toolchain')
cache=root/'downloads';cache.mkdir(parents=True,exist_ok=True)
sdk=root/'android-sdk';sdk.mkdir(parents=True,exist_ok=True)
metadata=cache/'android-repository.xml'
if not metadata.exists():
    subprocess.run(['curl','-fL','--silent','--show-error','https://dl.google.com/android/repository/repository2-1.xml','-o',str(metadata)],check=True)
packages={}
for package in ET.parse(metadata).getroot().iter('remotePackage'):
    name=package.attrib.get('path')
    if name not in ('platform-tools','build-tools;36.0.0','platforms;android-36'):continue
    for archive in package.findall('./archives/archive'):
        if archive.findtext('host-os') not in (None,'linux'):continue
        complete=archive.find('complete');url=complete.findtext('url')
        if 'ext' in url:continue
        packages[name]=(url,complete.findtext('checksum'),complete.find('checksum').attrib.get('type','sha1'))
assert len(packages)==3,'Required SDK packages missing from official metadata'
manifest=[]
for name,(url,digest,algorithm) in packages.items():
    archive=cache/url
    if not archive.exists():
        subprocess.run(['curl','-fL','--silent','--show-error','https://dl.google.com/android/repository/'+url,'-o',str(archive)],check=True)
    assert hashlib.new(algorithm,archive.read_bytes()).hexdigest()==digest,'SDK checksum mismatch: '+url
    destination=sdk/name.replace(';','/')
    destination.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        for member in z.infolist():
            parts=Path(member.filename).parts[1:]
            if not parts:continue
            assert '..' not in parts
            path=destination.joinpath(*parts)
            if member.is_dir():path.mkdir(parents=True,exist_ok=True);continue
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(z.read(member))
            mode=member.external_attr>>16
            path.chmod(0o755 if mode & 0o111 else 0o644)
    manifest.append({'package':name,'archive':url,'digest_algorithm':algorithm,'digest':digest})
    print('Verified and installed',name,flush=True)
(root/'android-toolchain-manifest.json').write_text(json.dumps(manifest,indent=2))
print('Android SDK:',sdk)
