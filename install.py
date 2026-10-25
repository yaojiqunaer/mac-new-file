#!/usr/bin/env python3
"""安装本机构建的 Mac新建文件；不会下载任何依赖。"""
from pathlib import Path
import datetime
import plistlib
import shutil
import subprocess

base=Path(__file__).resolve().parent
source=base/'build/Mac新建文件.buildbundle'
target=Path('/Applications/Mac新建文件.app')
identifier='local.codex.LocalNewFile'
if not source.is_dir():
    raise SystemExit('请先运行 python3 build.py。')
subprocess.run(['/usr/bin/codesign','--verify','--deep','--strict',str(source)],check=True)
processes=subprocess.check_output(['ps','-axo','comm='],text=True)
if str(target/'Contents/MacOS/LocalNewFile') in processes.splitlines():
    raise SystemExit('请先退出 Mac新建文件设置窗口，再运行安装。')
if target.exists():
    installed=plistlib.loads((target/'Contents/Info.plist').read_bytes())
    if installed.get('CFBundleIdentifier')!=identifier:
        raise SystemExit('同名位置存在其他应用，停止安装。')
    backup=Path.home()/'Library/Caches/MacNewFile/Backups'
    backup.mkdir(parents=True,exist_ok=True)
    stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    shutil.move(str(target),str(backup/f'Mac新建文件-{stamp}.buildbundle'))
shutil.copytree(source,target)
register='/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister'
for command in [
    [register,'-f',str(target)],
    ['/usr/bin/pluginkit','-a',str(target/'Contents/PlugIns/LocalNewFileFinder.appex')],
    ['/usr/bin/pluginkit','-e','use','-i',identifier+'.FinderExtension'],
    ['/usr/bin/open',str(target)],
]:
    subprocess.run(command,check=True)
print('Installed: '+str(target))
