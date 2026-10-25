#!/usr/bin/env python3
"""将本地构建产物打包成带 Applications 快捷方式的只读 DMG。"""
from pathlib import Path
import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess
import tempfile

base = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--output-dir',type=Path,default=base/'dist')
args=parser.parse_args()
source=base/'build/Mac新建文件.buildbundle'
if not source.is_dir():
    raise SystemExit('请先运行 python3 build.py。')
version=plistlib.loads((source/'Contents/Info.plist').read_bytes())['CFBundleShortVersionString']
args.output_dir.mkdir(parents=True,exist_ok=True)
image=args.output_dir/f'MacNewFile-{version}-universal.dmg'
subprocess.run(['/usr/bin/codesign','--verify','--deep','--strict',str(source)],check=True)
with tempfile.TemporaryDirectory(prefix='mac-new-file-dmg-') as temp:
    stage=Path(temp)
    shutil.copytree(source,stage/'Mac新建文件.app')
    (stage/'Applications').symlink_to('/Applications')
    (stage/'使用说明.txt').write_text(
        'Mac新建文件\n\n将 Mac新建文件.app 拖到 Applications，然后打开应用配置文件后缀。\n'
        '在系统设置的“登录项与扩展”中启用本应用的 Finder 扩展。\n'
        '使用：Finder 文件夹空白处右键 → 新建文件。\n'
        '当前提供本地 ad-hoc 签名版本，尚未进行 Apple 公证。\n',encoding='utf-8')
    subprocess.run(['/usr/bin/hdiutil','create','-volname','Mac新建文件','-srcfolder',str(stage),
                    '-fs','HFS+','-format','UDZO','-ov',str(image)],check=True)
subprocess.run(['/usr/bin/hdiutil','verify',str(image)],check=True)
digest=hashlib.sha256(image.read_bytes()).hexdigest()
checksum=image.with_suffix('.dmg.sha256')
checksum.write_text(digest+'  '+image.name+'\n',encoding='ascii')
print(json.dumps({'dmg':str(image),'sha256':digest,'bytes':image.stat().st_size},ensure_ascii=False))
