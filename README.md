# Easy Meeting

Easy Meeting 是一个完整的 macOS 本地会议助手产品，目标是把会议中的听、看、存、查、导出做成稳定的本地工作流。

产品必须长期围绕以下闭环演进：

- 会前：配置语音服务、选择麦克风、调整悬浮字幕窗。
- 会中：实时采集麦克风音频，显示原文和译文字幕，保存录音和转录。
- 会后：查看历史会议，导出录音、字幕、转录和结构化记录。


## 当前能力

- 菜单栏常驻应用。
- 透明悬浮字幕窗。
- 麦克风权限请求。
- 麦克风输入设备选择。
- 本地录音到 `audio.m4a`。
- 本地会议目录和 `metadata.json`。
- SQLite 会议索引和转录分段存储。
- 三种翻译模式：
  - 英文转中文。
  - 粤语转中文。
  - 中英互译。
- 最近会议菜单。
- 导出：
  - `transcript.txt`
  - `transcript.md`
  - `transcript.srt`
  - `transcript.json`
  - `audio.m4a`
- 设置窗口。
- Keychain 保存火山 API Key。
- 火山同声传译 2.0 AST WebSocket 客户端骨架。

## 产品方向

核心产品能力：

- 菜单栏常驻，适合会议中低打扰使用。
- 透明、置顶、可调样式的悬浮字幕窗。
- 麦克风输入设备管理。
- 英文转中文、粤语转中文、中英互译。
- 火山引擎真实实时识别和翻译。
- 本地录音、转录、翻译和历史记录。
- 会议数据导出。
- 设置、密钥、本地数据管理。

第一阶段的工程重点是打通真实会议闭环。任何模拟链路只能作为内部开发验证工具，不能作为产品能力或验收标准。第二阶段补足产品化体验，例如快捷键、字幕样式、拖动/锁定、导出位置选择、错误恢复、状态诊断和屏幕共享实测记录。

## 本地运行

编译：

```bash
swift build
```

打包 `.app`：

```bash
zsh scripts/package-app.sh
```

生成路径：

```text
.build/debug/Easy Meeting.app
```

启动后如果没有配置火山凭证，应用会自动打开设置窗口。应用同时会在 macOS 顶部菜单栏显示 `Easy Meeting` 入口，可从这里打开设置、开始录音、选择麦克风和查看最近会议。

## 数据目录

会议数据保存在：

```text
~/Library/Application Support/Easy Meeting/
  easy_meeting.sqlite
  meetings/
    <meeting_id>/
      audio.m4a
      metadata.json
      transcript.txt
      transcript.md
      transcript.srt
      transcript.json
```

## 火山引擎接入状态

当前已完成：

- 设置窗口配置语音服务。
- Keychain 保存 API Key。
- 固定使用 AST 2.0 Resource ID `volc.service_type.10053`。
- 设置窗口可检查 API Key、固定 Resource ID 和本地 helper 状态。
- 创建 AST WebSocket 连接。
- 接收 WebSocket 消息和错误反馈。
- 录音时把采集到的音频帧交给语音客户端。
- 通过 Go helper 复用火山 AST 官方示例协议实现。
- Swift 主 App 通过 JSON Lines 与 helper 通信。

尚未完成：

- 真实账号环境下验证音频格式、字幕事件时序和翻译质量。
- 完整的字幕配对、断线重连、失败重试和错误分级。
- 服务不可用时的恢复建议和诊断日志导出。

火山同声传译 2.0 文档显示业务消息使用 protobuf。Easy Meeting 通过随 App 打包的 Go helper 复用官方 Go 示例客户端协议实现，Swift 主 App 只处理领域化字幕、状态和错误事件。

## 屏幕共享说明

悬浮窗使用 macOS 原生透明窗口实现。共享单个应用窗口时通常不会进入共享内容；共享整个屏幕时不能保证不可见。应用不会使用私有 API 强行绕过系统录屏或会议软件。
