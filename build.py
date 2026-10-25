#!/usr/bin/env python3
"""使用本机现有的 Xcode 工具构建新建文件菜单，不下载任何依赖。"""
from pathlib import Path
import json
import shutil
import subprocess

base = Path(__file__).resolve().parent
app = base / 'build/Mac新建文件.buildbundle'
extension = app / 'Contents/PlugIns/LocalNewFileFinder.appex'

def execute(command):
    result = subprocess.run(command, capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout or str(command))
    return result

clang = execute(['/usr/bin/xcrun', '--find', 'clang']).stdout.strip()
sdk = execute(['/usr/bin/xcrun', '--sdk', 'macosx', '--show-sdk-path']).stdout.strip()
for directory in [app/'Contents/MacOS', extension/'Contents/MacOS']:
    directory.mkdir(parents=True, exist_ok=True)
shutil.copyfile(base/'Host-Info.plist', app/'Contents/Info.plist')
shutil.copyfile(base/'Extension-Info.plist', extension/'Contents/Info.plist')

common = [clang, '-fobjc-arc', '-fmodules', '-isysroot', sdk, '-mmacosx-version-min=13.0', '-arch', 'arm64', '-arch', 'x86_64', '-framework', 'Cocoa', '-framework', 'Foundation']
execute(common + [str(base/'Host.m'), str(base/'NewFileConfig.m'), '-o', str(app/'Contents/MacOS/LocalNewFile')])
execute(common + ['-fapplication-extension', '-framework', 'FinderSync', '-Wl,-e,_NSExtensionMain', str(base/'FinderExtension.m'), str(base/'NewFileConfig.m'), '-o', str(extension/'Contents/MacOS/LocalNewFileFinder')])
execute(['/usr/bin/codesign', '--force', '--sign', '-', '--timestamp=none', '--entitlements', str(base/'extension.entitlements'), str(extension)])
execute(['/usr/bin/codesign', '--force', '--sign', '-', '--timestamp=none', str(app)])
execute(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)])
print(json.dumps({'app': str(app), 'host_and_extension_compiled': True, 'signature_verified': True}, ensure_ascii=False))
