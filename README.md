# PinShot

PinShot 是一个 macOS 13+ 菜单栏区域截图工具。首版专注区域截图、选区标注、复制、保存、置顶显示和手动 OCR。

## 功能

- 默认使用 `Command + Shift + 2` 呼出区域截图。
- 拖拽选择截图区域，选区完成后仍可拖动。
- 支持矩形、箭头、画笔、文字、马赛克标注。
- 文字工具可点击已有文字原位重新编辑。
- 普通模式可拖动单个标注；拖动空白区域仍会移动整个截图选区。
- 支持撤销、重做、清空标注。
- 支持复制到剪贴板、保存到文件、置顶显示。
- 支持多张图片同时置顶。
- 支持手动识别选区文字，并复制 OCR 结果。
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
PINSHOT_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
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
dist/PinShot-1.0.0.dmg
```

## 自动化检查

```bash
PINSHOT_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  swift run --disable-sandbox --sdk "$PINSHOT_SDK" PinShotLogicTests
```
