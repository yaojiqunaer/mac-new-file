#!/usr/bin/env python3
"""运行后缀配置、真实文件创建和宿主偏好域回归测试。"""
from pathlib import Path
import plistlib
import subprocess
import tempfile

base=Path(__file__).resolve().parent
build=base/'.tests'
build.mkdir(exist_ok=True)
clang=subprocess.check_output(['/usr/bin/xcrun','--find','clang'],text=True).strip()
sdk=subprocess.check_output(['/usr/bin/xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
flags=[clang,'-fobjc-arc','-isysroot',sdk,'-I',str(base),'-DMF_PREFERENCES_DOMAIN=@"local.codex.LocalNewFile.Tests"','-framework','Cocoa']
for name in ['ConfigTests','HostTests']:
    executable=build/name
    subprocess.run(flags+[str(base/'tests'/f'{name}.m'),str(base/'NewFileConfig.m'),'-o',str(executable)],check=True)
    subprocess.run([str(executable)],check=True)
with tempfile.TemporaryDirectory(prefix='owner-',dir=build) as temp:
    contents=Path(temp)/'OwnerProbe.app/Contents'
    (contents/'MacOS').mkdir(parents=True)
    (contents/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.codex.LocalNewFile.Tests','CFBundleExecutable':'OwnerProbe','CFBundlePackageType':'APPL'}))
    executable=contents/'MacOS/OwnerProbe'
    subprocess.run(flags+[str(base/'tests/OwnerPreferencesProbe.m'),str(base/'NewFileConfig.m'),'-o',str(executable)],check=True)
    subprocess.run([str(executable)],check=True)
print('All focused tests passed.')
