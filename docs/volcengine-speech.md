# 火山引擎语音能力梳理

## 文档来源

- 实时语音翻译 API：https://www.volcengine.com/docs/6561/1756902?lang=zh
- Doubao 语音识别 Realtime API：https://www.volcengine.com/docs/6561/1354869
- 本地 AST 2.0 接入摘要：`docs/volcengine-ast-api.md`

## 结论

优先使用实时语音翻译 API 的 S2T 能力。

原因：

- 输入是实时音频。
- 输出包含源语言字幕和目标语言字幕。
- 支持中英、英中、中英互译等会议常用模式。
- 比“实时 ASR + 翻译 API”少一跳，端到端延迟更容易控制。

Doubao 语音识别 Realtime API 作为备选能力保留：

- 用于纯转录模式。
- 用于服务降级。
- 用于未来自研翻译链路。

## 关键能力

实时语音翻译 API 面向同声传译场景，包含：

- S2T：语音输入，文本翻译输出。
- S2S：语音输入，文本和语音翻译输出。

Easy Meeting 只需要 S2T，不需要服务端合成语音。

## 模式映射

| 产品模式 | 接口能力 | 说明 |
|---|---|---|
| 英文转中文 | S2T | 输入英语，输出中文字幕 |
| 粤语转中文 | S2T 或 ASR+翻译 | 需要实测粤语识别质量 |
| 中英互译 | S2T | 输入中英自动处理，输出另一语言 |
| 纯转录 | Realtime ASR | 只保存原文，不翻译 |

## 需要实现的客户端流程

1. 请求麦克风权限。
2. 选择输入设备。
3. 将音频统一转换为接口要求的采样率、声道数和编码格式。
4. 建立实时连接。
5. 按音频帧发送数据。
6. 接收识别和翻译事件。
7. 将分段结果写入本地数据库。
8. 同步更新悬浮字幕窗。
9. 结束会议时关闭连接并落盘导出文件。

## 需要配置的参数

具体参数以后端文档和控制台配置为准，客户端侧需要抽象出：

- API Key。
- 固定 Resource ID：`volc.service_type.10053`。
- 源语言。
- 目标语言。
- 翻译模式。
- 音频格式。
- 采样率。
- 分段策略。

## 风险

- 鉴权细节需要结合火山控制台实际开通结果验证。
- 粤语转中文质量需要真机语料测试，不能只看文档判断。
- 中英互译模式的断句和语言切换延迟需要实测。
- 网络抖动会影响实时字幕，需要做重连和本地缓冲。
- API 返回事件结构需要封装，避免 UI 直接依赖服务商字段。

## 封装原则

客户端只暴露领域模型：

- `SpeechMode`
- `AudioInputDevice`
- `TranscriptSegment`
- `TranslationSegment`
- `RealtimeSpeechEvent`

火山接口字段只允许出现在基础设施层，方便未来替换服务商。

## 当前实现状态

- 已新增 Speech 领域模型。
- 火山 AST 接入改为 Go helper 二进制进程，Swift 主 App 不直接处理 AST protobuf。
- 开始录音后会把麦克风音频帧交给语音客户端。
- 音频采集出口统一为 PCM 16kHz、单声道、16bit，小端有符号整型。
- Go helper 复用 `ref/_extracted/go/ast_go` 官方示例模块中的 AST proto 和协议依赖。
- Swift 与 Go helper 通过 JSON Lines 通信，Swift 只接收领域化字幕、状态和错误事件。
- 设置窗口可检查 API Key、固定 Resource ID 和本地 helper 是否可执行。
- 仍需真实账号和会议语料验证事件时序、字幕配对和错误恢复。

## AST 参考客户端结论

`ref` 目录里的 Go、Python、Java 示例都指向同一套 AST v4 协议：

- 地址：`wss://openspeech.bytedance.com/api/v4/ast/v2/translate`。
- WebSocket Header：
  - `X-Api-Key`
  - `X-Api-Resource-Id`
  - `X-Api-Connect-Id`
- 上行业务消息为 `TranslateRequest` protobuf 二进制。
- 下行业务消息为 `TranslateResponse` protobuf 二进制。
- 会话事件顺序：
  1. `StartSession`
  2. 服务端返回 `SessionStarted`
  3. 持续发送 `TaskRequest` 音频分片
  4. 停止时发送 `FinishSession`
  5. 服务端返回字幕事件和 `SessionFinished`

详细鉴权、事件码、语种约束、音频格式和错误码见 `docs/volcengine-ast-api.md`。设置页只要求填写控制台 API Key，Resource ID 在应用内固定。

## Go helper 方案

- Swift 主 App 负责 macOS UI、麦克风权限、设备选择、录音、SQLite、导出和设置。
- Go helper 负责火山 AST WebSocket、Header、protobuf 编解码、会话事件和字幕事件解析。
- helper 随 `.app` 打包到 `Contents/Helpers/easy-meeting-ast-helper`。
- Swift 通过 stdin/stdout JSON Lines 向 helper 发送 `start`、`audio`、`finish`、`stop` 命令。
- helper 向 Swift 返回 `status`、`subtitle`、`error` 事件。
- 本地调试时 Swift 也会查找 `.build/debug/easy-meeting-ast-helper`。
- 旧的 Swift 原生 AST 客户端路线已删除，不再维护 SwiftProtobuf 生成配置。

### Swift 侧分层

`Sources/EasyMeeting/Speech/Volcengine/` 按职责拆分为三个文件，避免单文件膨胀：

- `VolcengineHelperSpeechClient.swift`：实现 `SpeechClient`，负责拉起 helper 进程、写入命令、按行解析 stdout、把领域事件回传上层。
- `VolcengineHelperProtocol.swift`：定义 Swift 与 helper 间的 JSON 协议类型 `VolcengineHelperCommand`、`VolcengineHelperEvent` 和错误 `VolcengineHelperError`，是唯一描述线协议的地方。
- `VolcengineHelperRuntime.swift`：负责定位 helper 可执行文件（bundle、可执行目录、`.build/debug`）和生成配置诊断文本，供设置窗口的“检查配置”复用。

## 音频管道设计

录音模块必须同时服务两个消费者：

- 本地录音：继续写入 `audio.m4a`。
- 实时语音：输出 `AudioFrame`，由语音客户端按服务商协议发送。

`AudioFrame` 是跨模块边界的数据结构，只包含二进制音频、采样率、声道数、位深和时间戳。当前采集出口固定为 PCM 16kHz、单声道、16bit，小端有符号整型；UI、会议存储和导出模块不直接依赖火山 protobuf 字段。

## 实时字幕提交规则

AST 会分别返回原文字幕和译文字幕，每一侧都有 start、response、end 三类事件。Easy Meeting 的展示和落库规则如下：

- `SourceSubtitleResponse` 和 `TranslationSubtitleResponse` 只更新当前草稿行，悬浮窗必须实时刷新同一行。
- `SourceSubtitleEnd` 只确认原文草稿，不单独提交最终字幕。
- `TranslationSubtitleEnd` 作为一次完整双语字幕的提交点；如果译文先结束，则等待源字幕结束时再提交。
- 同一段字幕提交后，后续重复 end 事件只能更新草稿状态，不能再次追加行或写入数据库。
- Swift 展示层和落库层保留文本指纹兜底，防止服务端重发或 helper 异常导致重复最终文本。
