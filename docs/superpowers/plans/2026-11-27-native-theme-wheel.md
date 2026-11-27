# PinShot 原生主题与滚轮缩放实现计划

**目标：** 实现用户选中的 A 版界面，修复浅色不可读，并让置顶图片可滚轮缩放。

**架构：** AppKit 视图共用 PinShotTheme 动态颜色与表面组件；PinnedImageZoomPolicy 以纯几何计算锚点缩放，PinnedImageFrameView 接收滚动事件并修改窗口。图片原始数据与界面外观解耦。

**技术栈：** Swift、AppKit、Swift Package Manager，macOS 13+。

## 任务

- [x] 1. 在 Tests/PinShotAppTests/TestRunner.swift 添加现有 OCR 在浅色外观下文字对比度及滚动事件缩放的失败测试；在 Tests/PinShotTests/TestRunner.swift 验证锚点和缩放上下限。
  - `zsh scripts/check-app-interactions.sh` 应报告 light OCR contrast 和 wheel zoom 失败。
  - 几何测试使用 frame `(100,100,400,250)`、锚点 `(200,200)`，验证锚点相对比例不变、尺寸比为 1.6、超大滚动受限。
- [x] 2. 创建 Sources/PinShot/PinShotTheme.swift，提供系统动态前景、背景、分隔线和浮动表面；更新 AnnotationToolbarView、OCRStatusPanelView、PinnedImageFrameView，移除 PinnedImageWindowManager 的强制深色。用 `viewDidChangeEffectiveAppearance()` 刷新 CALayer 色值。
- [x] 3. 按 A 版增加工具栏取消、复制、完成按钮，连接 CaptureOverlayView 的既有 CaptureCommand；保留撤销/重做快捷键。使用 SF Symbols 和可访问标签，设置窗口原生分组布局，重绘 MenuBarIcon 四角模板图标。
- [x] 4. 创建 Sources/PinShotCore/PinnedImageZoomPolicy.swift，按指数因子 `exp(delta * sensitivity)` 缩放，钳制尺寸，按归一化锚点重算 origin。PinnedImageFrameView.scrollWheel 路由原图视图和工具条事件，忽略惯性与横向滚动。
- [x] 5. 运行逻辑和 AppKit 测试并导出浅/深界面 PNG 人工检查；修复发现的布局问题。更新 README、版本为 1.2.0，执行 `./scripts/package-dmg.sh`、`codesign --verify --deep --strict dist/PinShot.app` 与 `hdiutil verify dist/PinShot-1.2.0.dmg`。

界面改动以真实渲染验证为主，不添加镜像实现的样式快照断言。滚轮数学与事件路由通过行为测试验证。

## 执行结果

- 分支：`codex/pinshot-native-theme-wheel`。
- 红灯：AppKit 测试复现浅色 OCR 对比度不足、缺少三项输出按钮、滚轮不缩放，共 6 项预期失败。
- 绿灯：77 项逻辑检查和 48 项 AppKit 交互检查通过；包含真实 OCR、复制原图、滚轮路由、触控板惯性、动态外观更新和工具栏输出命令。
- 实际渲染：`dist/ui-preview/pinshot-light.png`、`dist/ui-preview/pinshot-dark.png`。修复了深色材质混合使自绘按钮文字和截图像素消失的问题（禁用这两处的 vibrancy）。
- 构建：1.2.0 release 应用与 DMG 完成，签名校验和映像 CRC 校验通过，Mach-O 最低系统为 13.0。
- 工具链提示：本机 Command Line Tools 输出缺少其默认 Developer/Library 搜索目录的链接警告，构建成功；hdiutil 输出 create 子命令弃用提示，映像生成和校验成功。
