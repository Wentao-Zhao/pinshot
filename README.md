# PinShot

PinShot 是一个 macOS 13+ 菜单栏区域截图工具，支持选区标注、复制、保存、置顶和 OCR。

从 [GitHub Releases](https://github.com/Wentao-Zhao/pinshot/releases/latest) 下载 DMG（Apple Silicon），将 PinShot 拖入「应用程序」。升级前先从菜单栏退出旧版，再打开新版。

## 功能

- 默认使用 `Command + Shift + 2` 呼出区域截图。
- 拖拽选择截图区域，选区完成后仍可拖动。
- 支持矩形、箭头、画笔、文字、马赛克标注。
- 文字工具可点击已有文字原位重新编辑。
- 普通模式可拖动单个标注；拖动空白区域仍会移动整个截图选区。
- 支持撤销、重做、清空标注。
- 原生简洁工具栏按绘图、编辑和输出分组，提供取消、复制按钮；回车按默认动作完成截图。
- 截图工具栏、颜色弹窗、OCR、置顶操作条和设置窗口随 macOS 浅色/深色外观实时切换。
- 菜单栏采用简洁的四角取景框图标，自动适配深浅色背景。
- 应用图标采用「轻盈取景」方案：白色底、蓝色开放取景符号与小方块，提供 16–1024 像素及 Retina 图标资源。
- 支持复制到剪贴板、保存到文件、置顶显示。
- 支持多张图片同时无框置顶。鼠标移入图片时，右上角显示复制、识别文字和关闭；拖动图片可移动，拖动右下角可等比缩放。
- 鼠标移到置顶图片上，滚轮向上放大、向下缩小；触控板连续滚动也可缩放。以鼠标位置为中心保持比例，限制最小尺寸和当前屏幕内的最大尺寸。
- 点选置顶图片后按 `⌘C`，或右键选择「复制图片」，即可复制原图。
- 截图选区和置顶图片都支持 OCR。结果可滚动、拖选后按 `⌘C` 局部复制，也可点「复制全部」。
- 菜单栏右键提供「偏好设置」和「退出」。
- 偏好设置支持开机自启、默认完成动作、截图快捷键、保存目录。

## 默认配置

- 默认快捷键：`Command + Shift + 2`
- 默认完成动作：复制到剪贴板
- 默认保存目录：`~/Desktop`
- 默认文件名：`Screenshot-YYYYMMDD-HHmmss.png`
- 开机自启：关闭

## 权限说明

区域截图需要 macOS 屏幕录制权限。首次截图时如果没有权限，系统会提示授权。也可以手动进入：

```text
系统设置 > 隐私与安全性 > 屏幕录制
```

允许「PinShot」后重新触发截图。

## 使用

1. 启动 `PinShot.app`。
2. 按 `Command + Shift + 2`。
3. 拖动选择截图区域。
4. 使用工具栏标注，或直接点击「完成」。
5. 按偏好设置中的默认动作复制、保存或置顶。

## 构建

```bash
cd PinShot
./scripts/package-app.sh
```

生成文件：

```text
dist/PinShot.app
```

## 生成 DMG

```bash
./scripts/package-dmg.sh
```

生成文件：

```text
dist/PinShot-1.3.0.dmg
```

## 自动化检查

```bash
swift run --disable-sandbox PinShotLogicTests
zsh scripts/check-app-interactions.sh
```

导出实际 AppKit 组件的浅色/深色界面预览（需要本机图形会话）：

```bash
PINSHOT_UI_PREVIEW_DIR="$PWD/dist/ui-preview" zsh scripts/check-app-interactions.sh
```


## 手动检查更新（Sparkle）

在应用菜单或菜单栏右键菜单选择「检查更新…」，可查看新版并确认下载安装、替换应用和重启。仅手动触发，不自动轮询、下载或上传系统信息。首次需手动安装一版带 Sparkle 的新包。

更新框架固定为 Sparkle 2.10.1，原始许可随应用打包在 `Contents/Resources/Sparkle-LICENSE.txt`。应用保持现有最低 macOS 要求。

### 维护与发布

- 发布配置：`Resources/UpdateRelease.json`；公钥与更新源：`Resources/Info.plist`。
- 私钥保存在本机登录钥匙串的独立账户。禁止将私钥导出至仓库或提交；备份钥匙串，丢失后旧用户可能无法升级。
- 更新源是 GitHub Release 的 `releases/latest/download/appcast.xml`，清单和 DMG 都签名。每次 Release 必须同时发布 appcast.xml、DMG 与 SHA256SUMS；不能只上传新 DMG。
- 正式对外分发可配置 Developer ID 签名和公证；本次仍使用本地临时签名，无需额外购买服务。

准备本地更新包（构建、检查更新器配置、签名和公钥验证）：

```bash
zsh scripts/release-update.sh --prepare
```

发布前提升 `CFBundleShortVersionString` 和递增 `CFBundleVersion`，提交并推送代码及对应的 annotated `v版本` 标签，再执行：

```bash
zsh scripts/release-update.sh --publish
```

发布脚本先创建草稿并上传全部附件，再设为最新版；不会覆盖已有 Release。`zsh scripts/check-updater.sh --network` 可检查线上 feed；`python3 Tests/UpdateTests/test_appcast.py` 验证生成与失败处理（可选真实密钥测试使用 Python cryptography，生产签名校验使用系统 CryptoKit）。

置顶截图后，按 Esc 关闭按键所属的图片；OCR 弹窗内 Esc 关闭其所属图片，不影响其他置顶图片。
