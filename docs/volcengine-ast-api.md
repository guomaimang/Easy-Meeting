# 火山 AST 2.0 接入摘要

## 来源

本页沉淀自本地粘贴材料《同声传译2.0-API接入文档》，用于指导 Easy Meeting 的 Go helper 接入。

## 目标

- 使用 AST 2.0 WebSocket 接口承载实时同声传译。
- 第一阶段只实现 `s2t`，即语音输入、原文和译文文本输出。
- `s2s`、TTS 音频和音色能力暂不进入产品路径，但保留协议认知。

## 接口

- 地址：`wss://openspeech.bytedance.com/api/v4/ast/v2/translate`
- 传输：WebSocket 二进制消息。
- 编码：业务请求和响应均为 protobuf。
- 连接成功后服务端会在响应 Header 返回 `X-Tt-Logid`，客户端需要记录到日志，便于排查。

## 鉴权

新版控制台推荐请求头：

- `X-Api-Key`：控制台 API Key。
- `X-Api-Resource-Id`：固定为 `volc.service_type.10053`。

旧版控制台请求头：

- `X-Api-App-Id`：旧版 App ID。
- `X-Api-Access-Key`：旧版 Access Token。
- `X-Api-Resource-Id`：固定为 `volc.service_type.10053`。

文档样例中还出现过 `X-Api-App-Key`，与新版表格字段不一致。实现时以控制台实际返回和联调结果为准，配置层需要避免把字段名写死在 UI。

## 语种

`s2t` 约束：

- 必须指定 `source_language` 和 `target_language`。
- 源语言或目标语言必须包含中文 `zh` 或英文 `en`。
- 支持中英反转互译：`source_language` 和 `target_language` 同时传 `zhen`。
- 源语言支持 20 个外语和 2 个方言。
- 目标语言支持 20 个外语。

常用语言码：

| 语言 | 参数值 | 备注 |
|---|---|---|
| 中文 | `zh` | 中英语种之一 |
| 英文 | `en` | 中英语种之一 |
| 粤语 | `yue-CN` | 方言，仅可作为源语言 |
| 上海话 | `sh-CN` | 方言，仅可作为源语言 |
| 中英反转互译 | `zhen` | 源和目标都传 `zhen` |

其他外语包括 `de`、`fr`、`es`、`id`、`ja`、`pt`、`ko`、`tr`、`ms`、`nl`、`ro`、`pl`、`cs`、`ar`、`th`、`vi`、`ru`、`it`。

## 音频格式

源音频配置必须满足：

- `format`：`wav`。
- `codec`：`raw`，表示 PCM。
- `rate`：`16000`。
- `bits`：`16`。
- `channel`：`1`，当前仅支持单声道。

`TaskRequest` 音频数据要求为 16kHz、16bit、单声道 wav/pcm，建议每包 80ms。

## 上行事件

| 事件 | 值 | 用途 |
|---|---:|---|
| `StartSession` | 100 | 建立业务会话 |
| `TaskRequest` | 200 | 发送音频数据 |
| `UpdateConfig` | 201 | 会话中更新热词、术语、替换词 |
| `FinishSession` | 102 | 音频发送完成后结束会话 |

`StartSession` 必填字段：

- `request_meta.session_id`：建议 UUID。
- `event`：`StartSession`。
- `request.mode`：第一阶段固定 `s2t`。
- `request.source_language`。
- `request.target_language`。
- `source_audio`：按上方音频格式填写。

收到 `SessionStarted` 后才允许发送参数更新包和音频包。

## 下行事件

| 事件 | 值 | 处理方式 |
|---|---:|---|
| `SessionStarted` | 150 | 标记会话可发送音频 |
| `SourceSubtitleStart` | 650 | 开始一个原文分段 |
| `SourceSubtitleResponse` | 651 | 原文增量文本 |
| `SourceSubtitleEnd` | 652 | 原文分段完成 |
| `TranslationSubtitleStart` | 653 | 开始一个译文分段 |
| `TranslationSubtitleResponse` | 654 | 译文增量文本 |
| `TranslationSubtitleEnd` | 655 | 译文分段完成 |
| `UsageResponse` | 154 | 记录计量数据 |
| `SessionFinished` | 152 | 标记正常结束 |
| `SessionFailed` | 153 | 标记失败并上报错误 |
| `AudioMuted` | 250 | 记录静音状态，可用于 UI 状态提示 |

`s2t` 阶段忽略 `TTSSentenceStart`、`TTSResponse`、`TTSSentenceEnd`，但 helper 解码层不能因未知或暂不用事件崩溃。

## 响应字段

常用响应字段：

- `response_meta.status_code`：错误码。
- `response_meta.message`：错误信息。
- `response_meta.billing`：计量信息，仅 `UsageResponse` 使用。
- `event`：响应事件。
- `text`：原文或译文文本。
- `start_time`：分段起始时间，毫秒。
- `end_time`：分段结束时间，毫秒。
- `spk_chg`：说话人是否切换。
- `muted_duration_ms`：静音时长，毫秒。

字幕事件需要映射为领域模型，UI 和 SQLite 不直接依赖 protobuf 字段。

## 错误码

| 错误码 | 含义 | 处理建议 |
|---:|---|---|
| 20000000 | 成功 | 正常处理 |
| 45000001 | 请求参数无效 | 记录参数摘要和 logid |
| 45000002 | 空音频 | 检查采集、静音和发包时序 |
| 45000081 | 等包超时 | 触发重连或结束当前会话 |
| 45000151 | 音频格式不正确 | 检查 PCM 转换和 `source_audio` |
| 550xxxxx | 服务内部处理错误 | 提示服务异常并允许重试 |
| 55000031 | 服务器繁忙 | 退避后重试 |

## 实现约束

- Go helper 负责 Header、WebSocket、protobuf 编解码和事件翻译。
- Swift 主 App 只通过 JSON Lines 收发领域化命令和事件。
- helper 必须在开发环境记录连接参数摘要、事件类型、分段时间和错误码。
- 生产环境不能输出密钥、原始音频或过量 DEBUG 日志。
- `UpdateConfig` 只用于热词、术语、替换词等配置更新，不支持会话中切换语言和 mode。
- 切换翻译模式、源语言或目标语言时必须重新建立会话。

## 待验证

- 新版鉴权字段到底使用 `X-Api-Key` 还是兼容 `X-Api-App-Key`。
- Go 示例 proto 中字段命名和文档字段命名是否完全一致。
- `format=wav` 但 `codec=raw` 时，`TaskRequest.data` 是否需要裸 PCM，还是需要 WAV 片段头。
- 80ms 发包在 macOS `AVAudioEngine` 当前转换链路下的延迟和稳定性。
- 粤语 `yue-CN` 到中文的准确率、断句延迟和说话人切换表现。
