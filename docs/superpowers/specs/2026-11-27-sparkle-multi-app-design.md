# 七应用手动 Sparkle 更新与 PinShot Esc

用户已选择免费 Sparkle 方案并明确要求当前七个应用全部接入，另要求 PinShot 置顶图片支持 Esc 关闭。

## 范围与行为

- AppSweep、ClipStack、CodexMeter、MenuBarFold、PinShot、屏幕清洁、SystemMonitor 分别集成固定稳定版 Sparkle 2.10.1。
- App 菜单或状态栏菜单增加「检查更新…」。仅手动触发检查；关闭后台自动检查、自动下载及匿名系统信息提交。
- 使用 Sparkle 标准更新界面，用户确认后下载、验证、安装和重启。失败由更新界面明确提示，不改变原 App 数据或配置。
- 每个应用一套 Ed25519 更新签名密钥和公钥。私钥仅保存在本机登录钥匙串中，禁止写入仓库或输出。
- 更新清单使用该仓库 Release 的固定地址 `https://github.com/Wentao-Zhao/<repo>/releases/latest/download/appcast.xml`，DMG 使用具体版本的 Release 附件地址。无需 Pages、域名或中继服务器。
- 固定源仓库和密钥账户保存在非机密发布配置中。发布脚本先构建、签名并验证 DMG，生成 appcast，先上传草稿，附件完整后才发布并设为最新版。
- 保留各应用现有最低 macOS 版本、Bundle ID、数据路径与原有权限流程；本次使用现有临时签名，不购买或假造 Developer ID。
- 运行时从 App Bundle 的 Frameworks 加载 Sparkle，保留框架目录链接及辅助进程，完整携带第三方许可声明。
- PinShot：仅处理属于当前置顶窗口或其 OCR 弹窗的 Esc，关闭所属图片并取消 OCR，不关闭其他置顶图片或普通窗口。

## 验证

- PinShot Esc 先观察失败测试，再验证正常窗口、OCR 焦点、无关窗口隔离和已有复制缩放行为。
- 七个项目原有逻辑检查均须通过；PinShot AppKit 和其他现有交互检查保持运行。
- 每个 .app 启动独立 updater 检查进程，验证动态库可加载、配置有效、可手动检查、自动检查/下载关闭。
- 每个 DMG 经 EdDSA 签名并以 App 内公钥独立验证；错误密钥、签名或内容变更必须拒绝。
- 每个 Release 的 appcast 可下载且指向对应签名 DMG，比较远端附件校验和与本地文件。
- 从旧版引导安装一版带更新器的 App 后，未来版本才支持程序内升级。实际替换和重启在临时沙盒副本上验证，避免操作用户正在运行的 App。
