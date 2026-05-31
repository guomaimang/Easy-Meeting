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
- 读取 Resource ID。
- 创建 AST WebSocket 连接。
- 接收 WebSocket 消息和错误反馈。
- 录音时把采集到的音频帧交给语音客户端。

尚未完成：

- 使用 SwiftProtobuf 生成 AST protobuf 类型并完成消息编解码。
- 麦克风音频帧转换为 AST 要求的协议包。
- 真实识别/翻译事件解析。
- 连接重试、错误分级、服务不可用时的用户可理解恢复路径。

火山同声传译 2.0 文档显示业务消息使用 protobuf，因此真实接入使用 SwiftProtobuf 基于官方 proto 生成 Swift 类型后继续完成。

## 屏幕共享说明

悬浮窗使用 macOS 原生透明窗口实现。共享单个应用窗口时通常不会进入共享内容；共享整个屏幕时不能保证不可见。应用不会使用私有 API 强行绕过系统录屏或会议软件。
