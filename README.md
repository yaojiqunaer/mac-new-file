# Mac新建文件

在 macOS Finder 的文件夹空白处右键，通过“新建文件”创建空白文本文件。默认支持 TXT、Markdown、CSV 和 SQL，可以在原生设置窗口自定义后缀及其显示顺序。

## 功能

- 独立 Finder 右键菜单，无需进入“服务”子菜单。
- 自定义文件后缀，支持保存和恢复默认；保存后下次打开菜单即时生效。
- 同名文件自动添加序号，不覆盖已有文件或符号链接。
- 创建后在 Finder 中选中新文件，方便重命名。
- 菜单命令保存自己的目录与后缀快照，避免配置变更导致类型错配。
- 提供包含 Apple 芯片和 Intel 架构的通用二进制及 DMG。

## 安装

1. 从 [Releases](https://github.com/yaojiqunaer/mac-new-file/releases) 获取 DMG。
2. 打开 DMG，将 **Mac新建文件.app** 拖到 **Applications**。
3. 从 `/Applications/Mac新建文件.app` 打开设置窗口。
4. 如右键菜单没有显示，在系统设置的“通用 → 登录项与扩展”中启用本应用的 Finder 扩展。
5. 在 Finder 的图标或列表视图中，右键文件夹内容区域的空白处，选择“新建文件”。

当前发布构建使用本地 ad-hoc 签名，未使用 Developer ID 签名或 Apple 公证。其他 Mac 的首次启动与系统信任状态仍需单独验证；本仓库同时提供本地构建方式。程序不会下载依赖或关闭系统安全设置。

## 自定义后缀

双击“Mac新建文件”，或使用右键菜单中的“设置文件类型…”。每行输入一个后缀，也可用逗号、中文逗号、分号或空格分隔，例如：

```text
txt
md
csv
sql
json
yaml
sh
```

点击“保存”后，下次打开 Finder 菜单即可看到新列表。也可以点击“恢复默认”。

- 可省略或包含前导点；保存时转为小写并保序去重。
- 每个后缀为 1–32 个字符，最多 64 种。
- 支持字母、数字、横线、下划线及 `tar.gz` 形式的复合后缀，不接受路径符号。
- 创建的是空白文本文件。只修改后缀不会生成 Word、Excel、PDF、压缩包或图像格式所需的文件内容。

## 支持范围与菜单位置

需要 macOS 13 或更高版本。已在 Apple 芯片 Mac 上完成原生界面与 Finder 实测；Intel 架构已编译，未在 Intel 实机执行验证。

当前文件创建范围为用户主目录内的本地文件夹，包括桌面、文稿、下载和用户目录内的项目。暂不支持主目录之外的外置磁盘、网络挂载及指向这些位置的符号链接。

Finder 管理扩展菜单的位置，应用不能指定插入到内建“新建文件夹”旁边。若菜单未显示，先确认扩展已启用，再切换到图标或列表视图后重新打开右键菜单。

## 本地构建与测试

需要本机已有的 Xcode/macOS SDK、Python 3，以及系统的 codesign 和 hdiutil。不需要下载第三方依赖。

```bash
python3 test.py
python3 build.py
python3 install.py
python3 package.py
```

- `build.py`：构建 arm64/x86_64 通用二进制并执行本地签名校验。
- `install.py`：安装到系统 `/Applications`，同标识旧版应用先备份到用户缓存目录。
- `package.py`：生成 `dist/MacNewFile-1.1-universal.dmg` 和 SHA-256 校验文件。
- `test.py`：运行配置解析与持久化、同名文件保护、文件权限和宿主偏好域回归测试。

源码构建产物使用 `.buildbundle` 后缀，避免开发目录和已安装应用出现同一 Bundle ID 的重复注册。

## 实现

- `FinderExtension.m`：Finder 空白处菜单，使用数值 tag 将点击关联到扩展进程内的命令快照。
- `Host.m`：原生设置窗口、URL 请求校验、安全创建及 Finder 定位。
- `NewFileConfig.m`：默认类型、自定义类型校验和本用户偏好存储。
- 扩展运行于沙盒，仅声明对宿主自身偏好域的只读共享权限；文件写入由宿主处理。
- 文件创建使用目录句柄及 `openat(..., O_CREAT | O_EXCL, 0600)`。

## 停用与卸载

在系统设置中关闭本应用的 Finder 扩展，然后将 `/Applications/Mac新建文件.app` 移到废纸篓。个人后缀设置保存在当前用户的应用偏好域中。

## 许可证

遵循仓库已有的 [Apache License 2.0](LICENSE)。
