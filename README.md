# Easy Meeting

Easy Meeting 是一个 macOS 本地会议助手，目标是提供透明悬浮字幕、实时转录翻译、本地录音、历史记录和导出能力。

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
- Mock 实时语音链路，用于完整验证字幕、存储和导出。
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

尚未完成：

- AST protobuf 消息 codec。
- 麦克风音频帧转换为 AST 要求的协议包。
- 真实识别/翻译事件解析。

火山同声传译 2.0 文档显示业务消息使用 protobuf，因此真实接入需要官方 proto 定义生成 Swift codec 后继续完成。

## 屏幕共享说明

悬浮窗使用 macOS 原生透明窗口实现。共享单个应用窗口时通常不会进入共享内容；共享整个屏幕时不能保证不可见。应用不会使用私有 API 强行绕过系统录屏或会议软件。
