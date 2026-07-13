# PinShot 多显示器非激活截图实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让 PinShot 在所有显示器上同时进入截图态，并在抓图前保持当前前台 App 的激活状态和临时浮层。

**架构：** 将多显示器截图顺序提取为 PinShotCore 中可测试的启动计划。AppKit 层按计划先在后台抓取全部屏幕，再用非激活面板一次性展示各屏覆盖层；会话控制器负责统一结束。

**技术栈：** Swift 5.9、AppKit、CoreGraphics、Swift Concurrency

---

### 任务 1：锁定多显示器启动顺序

**文件：**
- 创建：`Sources/PinShotCore/MultiDisplayCapturePlan.swift`
- 修改：`Tests/PinShotTests/TestRunner.swift`

- [x] **步骤 1：编写失败测试**

测试两个显示器 ID 都进入计划，并且计划明确要求先捕获全部显示器再展示覆盖层；空数组不生成步骤。

- [x] **步骤 2：运行测试验证失败**

运行逻辑测试，预期因 `MultiDisplayCapturePlan` 尚不存在而编译失败。

- [x] **步骤 3：编写最少实现**

创建纯 Swift 计划类型，输出稳定的显示器 ID 列表和捕获、展示两个阶段。

- [x] **步骤 4：运行测试验证通过**

运行逻辑测试，预期全部检查通过。

### 任务 2：实现后台多屏抓图和非激活展示

**文件：**
- 修改：`Sources/PinShot/CaptureSessionController.swift`
- 修改：`Sources/PinShot/ScreenCaptureService.swift`
- 修改：`Sources/PinShot/CaptureOverlayWindowController.swift`

- [x] **步骤 1：收集全部屏幕捕获目标**

为每个 `NSScreen` 生成显示器 ID 与尺寸，截图准备阶段阻止重复快捷键。

- [x] **步骤 2：先抓图后展示**

后台顺序捕获每块显示器；回到主线程后为成功结果创建覆盖控制器并统一展示。

- [x] **步骤 3：移除截图阶段的 App 激活**

移除 `NSApp.activate`，覆盖面板加入 `.nonactivatingPanel`，展示时只调用 `orderFrontRegardless()`。

- [x] **步骤 4：处理失败与会话结束**

全部抓取失败时提示错误；任意屏幕完成或取消时关闭所有覆盖层。

### 任务 3：验证

**文件：**
- 验证：`Tests/PinShotTests/TestRunner.swift`
- 验证：`scripts/smoke-startup.sh`

- [x] **步骤 1：运行完整逻辑测试**

预期全部检查通过且无失败。

- [x] **步骤 2：运行 Release 构建**

预期 Swift Release 构建退出码为 0。

- [x] **步骤 3：运行启动与截图 GUI 烟测**

预期 startup 和 capture 两种烟测均输出 `PASS`。

- [x] **步骤 4：检查变更范围**

确认变更只涉及多屏启动、覆盖窗口激活策略、测试与对应文档。

### 任务 4：修复首次拖动和 Esc 取消

**文件：**
- 创建：`Sources/PinShotCore/CaptureInteractionPolicy.swift`
- 修改：`Sources/PinShot/HotKeyMonitor.swift`
- 修改：`Sources/PinShot/CaptureSessionController.swift`
- 修改：`Sources/PinShot/CaptureOverlayView.swift`
- 修改：`Tests/PinShotTests/TestRunner.swift`

- [x] **步骤 1：编写失败测试**

验证截图覆盖层接受首次鼠标事件，取消键为无修饰 `Esc`，主快捷键和取消快捷键 ID 不相同且只匹配自身。

- [x] **步骤 2：运行测试验证失败**

运行逻辑测试，预期因 `CaptureInteractionPolicy` 和 `HotKeyIdentity` 尚不存在而编译失败。

- [x] **步骤 3：实现首次鼠标与会话级 Esc**

覆盖视图返回首次鼠标事件可用；截图会话开始时注册 `Esc`、结束时注销；Carbon 回调按事件 ID 过滤。

- [x] **步骤 4：运行完整验证**

预期逻辑测试、Release 构建、启动烟测和截图烟测全部通过，截图烟测同时验证 `Esc` 注册成功。
