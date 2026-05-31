# 技术栈

## 目标

Easy Meeting 是一个完整的 macOS 本地会议助手产品。

产品目标：

- 透明悬浮字幕窗。
- 选择麦克风输入。
- 实时识别和翻译。
- 本地保存录音、转录、翻译和历史记录。
- 历史会议查看和导出。
- 设置、密钥和本地数据管理。
- 悬浮窗默认声明为不可共享窗口，尽可能降低被屏幕共享、录屏或截图捕获的概率。

开发测试可以使用内部替身验证 UI、存储和导出边界，但应用默认路径和产品交付标准必须使用火山引擎真实实时语音能力。

## 客户端

- 语言：Swift。
- UI：SwiftUI + AppKit。
- 悬浮窗：AppKit `NSPanel` / `NSWindow`。
- 音频采集：AVFoundation / AVAudioEngine。
- 本地数据库：SQLite，保存到 Application Support 目录。
- 会议文件：用户文稿目录 `~/Documents/Easy Meeting/Meetings/`。
- AST 协议编解码：随 App 打包的 Go helper。
- 密钥保存：Keychain。
- 普通配置：UserDefaults。
- 日志：开发环境 DEBUG 级别，生产环境 INFO 级别。
- 打包：SwiftPM 构建可执行文件，脚本组装 macOS `.app`。

## 外部服务

优先接入火山引擎/豆包实时语音能力：

- 实时语音翻译：用于英文转中文、中英互译、粤语转中文等会议字幕场景。
- 实时语音识别：作为备选链路，用于只需要原文转录、服务降级或翻译链路拆分时。

可选接入微软 Azure 认知服务实时语音翻译：

- 与火山 S2T 平级的另一条流式翻译链路，源语种 → 目标语种。
- 通过 Node helper 子进程调用 Azure Speech SDK，协议与火山 helper 一致。
- 需要 Speech Key；Region 默认预设为 `eastasia`，仍可在设置页调整，详见 `docs/azure-speech.md`。

AST 协议编解码与 Azure SDK 字段只允许出现在各自的 helper 基础设施层，
方便未来替换服务商。

## 为什么选择原生 macOS

原生方案对以下能力控制更稳定：

- 透明、置顶、穿透点击的悬浮窗。
- macOS 麦克风权限和音频设备选择。
- 菜单栏、快捷键、登录启动等系统体验。
- 后续接入本地模型或 Core ML。

Electron/Tauri 可以作为后续跨平台方案评估，但第一阶段不采用。

## 不做的事情

- 不采集系统 Loopback 音频。
- 不使用私有 API 强行绕过录屏或屏幕共享。
- 不承诺所有第三方共享软件的底层像素采集都能排除悬浮窗。
- 不把录音二进制直接存入数据库。

## 本地运行

调试编译：

```bash
swift build
```

组装本地 `.app`：

```bash
zsh scripts/package-app.sh
```

生成路径：

```text
.build/debug/Easy Meeting.app
```
