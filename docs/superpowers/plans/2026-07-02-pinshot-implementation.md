# PinShot 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 构建一个轻量 macOS 菜单栏区域截图工具，支持选区编辑、复制、保存、置顶和手动 OCR。

**架构：** 使用 Swift Package 管理两个 target：`PinShotCore` 保存配置、快捷键、文件命名、选区和标注模型；`PinShot` 使用 AppKit 实现状态栏、全局快捷键、截图遮罩、编辑画布、偏好设置、OCR 和置顶窗口。

**技术栈：** Swift 5.9、AppKit、CoreGraphics、Vision、ServiceManagement、Carbon HotKey API。

---

### 任务 1：工程骨架与核心配置

**文件：**
- 创建：`Package.swift`
- 创建：`Sources/PinShotCore/KeyboardShortcut.swift`
- 创建：`Sources/PinShotCore/PinShotConfiguration.swift`
- 创建：`Sources/PinShotCore/ScreenshotFileNamer.swift`
- 创建：`Tests/PinShotTests/TestRunner.swift`

- [ ] 编写核心逻辑测试，覆盖默认配置、快捷键匹配、默认文件名。
- [ ] 实现 `PinShotCore` 的配置模型和文件命名。
- [ ] 运行 `swift run PinShotLogicTests` 验证通过。

### 任务 2：菜单栏 App 与偏好设置

**文件：**
- 创建：`Sources/PinShot/PinShotApp.swift`
- 创建：`Sources/PinShot/StatusItemController.swift`
- 创建：`Sources/PinShot/PreferencesStore.swift`
- 创建：`Sources/PinShot/PreferencesWindowController.swift`
- 创建：`Sources/PinShot/LaunchAtLoginController.swift`
- 创建：`Sources/PinShot/MenuBarIcon.swift`

- [ ] 状态栏左键不响应，右键菜单包含偏好设置和退出。
- [ ] 偏好设置支持默认动作、保存目录、快捷键、开机自启。
- [ ] 配置变更后立即持久化。

### 任务 3：全局快捷键与截图会话

**文件：**
- 创建：`Sources/PinShot/HotKeyMonitor.swift`
- 创建：`Sources/PinShot/CaptureSessionController.swift`
- 创建：`Sources/PinShot/ScreenCaptureService.swift`

- [ ] 注册默认 `Command + Shift + 2` 热键。
- [ ] 快捷键触发时请求屏幕录制权限并捕获屏幕。
- [ ] 每次截图结束后释放遮罩窗口和编辑状态。

### 任务 4：选区和标注编辑器

**文件：**
- 创建：`Sources/PinShotCore/SelectionGeometry.swift`
- 创建：`Sources/PinShotCore/AnnotationModel.swift`
- 创建：`Sources/PinShot/CaptureOverlayWindowController.swift`
- 创建：`Sources/PinShot/CaptureOverlayView.swift`
- 创建：`Sources/PinShot/AnnotationToolbarView.swift`

- [ ] 支持拖拽创建选区。
- [ ] 支持编辑态拖动选区。
- [ ] 支持矩形、箭头、画笔、文字、马赛克。
- [ ] 支持撤销、重做、清空。
- [ ] 支持 `Enter` 完成和 `Esc` 取消。

### 任务 5：输出、OCR 和置顶窗口

**文件：**
- 创建：`Sources/PinShot/ScreenshotRenderer.swift`
- 创建：`Sources/PinShot/PasteboardWriter.swift`
- 创建：`Sources/PinShot/PinnedImageWindowManager.swift`
- 创建：`Sources/PinShot/ImageTextRecognizer.swift`
- 创建：`Sources/PinShot/OCRResultWindowController.swift`

- [ ] 渲染选区图片并叠加标注。
- [ ] 复制图片到系统剪贴板。
- [ ] 保存 PNG 到配置目录。
- [ ] 支持多图片置顶。
- [ ] 手动 OCR 识别并展示复制入口。

### 任务 6：打包和验证

**文件：**
- 创建：`Resources/Info.plist`
- 创建：`scripts/package-app.sh`
- 创建：`scripts/package-dmg.sh`
- 创建：`README.md`

- [ ] `swift run PinShotLogicTests` 通过。
- [ ] `swift build -c release` 通过。
- [ ] `scripts/package-app.sh` 生成可签名 `.app`。
- [ ] `codesign --verify --deep --strict` 通过。

