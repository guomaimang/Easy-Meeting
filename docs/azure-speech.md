# Azure 流式翻译接入

## 目标

接入微软 Azure 认知服务的实时语音翻译（Speech Translation），作为与火山引擎 S2T 平级的语音服务。

范围：

- 只做流式翻译 `TranslationRecognizer`，源语种 → 目标语种。
- 不做说话人区分（ConversationTranscriber）。
- 不做双麦克风并行识别。
- 不做服务端语音合成（TTS）。

## 为什么用 Node helper 子进程

Azure 语音翻译只能通过官方 Speech SDK，没有 REST 接口；且官方 SDK 没有 Go 绑定。

因此沿用火山引擎已验证的子进程架构：

- Swift 主 App 负责 macOS UI、麦克风权限、设备选择、录音、SQLite、导出、设置。
- Node helper 负责 Azure Speech SDK 的 `SpeechTranslationConfig`、`TranslationRecognizer`、推流和事件解析。
- 二者通过 stdin/stdout 的 JSON Lines 协议通信，与火山 helper 完全一致。
- Azure SDK 字段只出现在 Node helper 内，Swift 侧只接收领域化的字幕、状态、错误事件。

`ref/Meeting-Copilot-main` 是 Web 前端，用 JS SDK 在浏览器里跑 `TranslationRecognizer`。
本项目复用它的识别器配置与事件绑定逻辑，但音频输入从浏览器 `MediaStream`
改为 Node 的 `PushAudioInputStream`，由 Swift 通过 stdin 推送 PCM 帧。

## 凭据

Azure 需要两个凭据，与火山只需一个 API Key 不同：

- `Speech Key`：语音服务密钥，保存到 Keychain。
- `Region`：服务区域，如 `eastasia`、`southeastasia`、`eastus`，保存到 UserDefaults。

设置页在选择 Azure 服务时显示这两个字段，替换火山的 Resource ID 行。

## 进程间协议（JSON Lines）

Swift → helper 命令：

```json
{"type":"start","speechKey":"...","region":"eastasia","sourceLanguage":"en-US","targetLanguage":"zh-Hans","meetingID":"<uuid>"}
{"type":"audio","sampleRate":16000,"channels":1,"bitsPerChannel":16,"timestampMilliseconds":0,"dataBase64":"..."}
{"type":"finish"}
```

helper → Swift 事件：

```json
{"type":"status","message":"session_started"}
{"type":"source","sourceText":"hello world","isInterim":true}
{"type":"source_end","sourceText":"hello world.","isInterim":false}
{"type":"translation","translatedText":"你好世界","isInterim":true}
{"type":"translation_end","sourceText":"hello world.","translatedText":"你好世界。","isFinal":true}
{"type":"error","message":"..."}
```

事件类型与火山 helper 保持一致，复用 Swift 侧 `RealtimeSpeechEvent` 与
`SubtitleDisplayBuffer`，上层无需改动。

## 音频管道

录音模块统一输出 `AudioFrame`（PCM 16kHz、单声道、16bit，小端有符号整型），
正好是 Azure `AudioStreamFormat.getWaveFormatPCM(16000, 16, 1)` 的默认格式，
helper 直接把解码后的 PCM 写入 `PushAudioInputStream`，无需重采样。

## 事件映射

Azure SDK 事件 → 本项目事件：

| Azure 事件 | reason | 本项目事件 | 说明 |
|---|---|---|---|
| `recognizing` | RecognizingSpeech | `source` | 原文草稿，刷新左侧当前行 |
| `recognizing` | RecognizingSpeech | `translation` | 译文草稿，刷新右侧当前行 |
| `recognized` | TranslatedSpeech | `source_end` | 原文定稿 |
| `recognized` | TranslatedSpeech | `translation_end` | 译文定稿，唯一落库提交点 |
| `recognized` | NoMatch | （忽略） | 无有效语音 |
| `canceled` | — | `error` | 输出错误详情与错误码 |
| `sessionStopped` | — | `status` | 会话结束 |

`translation_end` 是一次完整双语字幕的唯一提交点，与火山规则一致，避免重复落库。

## 语种设计：按服务商分表

语言表按服务商分开维护，UI 下拉框直接产出当前服务商的原生代号，
不做跨服务商的统一枚举（这是早期实现的错误，已纠正）。

Azure 的源和目标是两套**不同**的代号体系：

- 识别语言（源）：BCP-47 带地区后缀，如 `en-US`、`zh-CN`、`zh-HK`、`yue-CN`、`ja-JP`。
- 翻译语言（目标）：简码/脚本码，如 `zh-Hans`、`zh-Hant`、`yue`、`en`、`ja`。

同一种语言在源和目标里写法不同（中文：源 `zh-CN`，目标 `zh-Hans`），不能混用。
当前为会议常用精选（约 18 种），数据来源：
https://learn.microsoft.com/azure/ai-services/speech-service/language-support

相关文件：

- `Speech/Languages/SpeechLanguageOption.swift`：语言选项（代号 + 显示名）。
- `Speech/Languages/AzureLanguageCatalog.swift`：Azure 识别/翻译两张表。
- `Speech/Languages/VolcengineLanguageCatalog.swift`：火山源/目标表（共用代号）。
- `Speech/Languages/SpeechLanguageCatalog.swift`：按服务商取表、默认值、校验。

### 与火山的差异

- 火山源/目标共用一套代号（`zh`/`en`/`ja`/`zhen`…），`zhen` 中英互译两边必须同时选。
- Azure 不提供单识别器的中英双向互译，因此 Azure 表里**没有** `zhen`；
  火山专属的方言码 `yue-CN`、`sh-CN` 也不出现在 Azure 表，避免无意义选项。
- 切换服务商时下拉框按新服务商重填，并回落到新服务商默认语种。

## Swift 侧分层

`Sources/EasyMeeting/Speech/Azure/` 按职责拆分，镜像火山结构，每文件 < 300 行：

- `AzureHelperSpeechClient.swift`：实现 `SpeechClient`，拉起 Node helper、写命令、
  按行解析 stdout、回传领域事件。配置里的源/目标代号已是 Azure 原生码，直接透传。
- `AzureHelperProtocol.swift`：定义 `AzureHelperCommand`、`AzureHelperEvent`、
  `AzureHelperError`，唯一描述线协议的地方。
- `AzureHelperRuntime.swift`：定位 helper（bundle、可执行目录、`Helpers/` 源码目录）
  与生成配置诊断文本，供设置页“检查配置”复用。

## Node helper 结构

`Helpers/AzureSpeechHelper/`：

- `package.json`：依赖 `microsoft-cognitiveservices-speech-sdk`。
- `index.js`：stdin 主循环，解析命令，分发到翻译会话。
- `azureTranslation.js`：`SpeechTranslationConfig` + `TranslationRecognizer`
  配置、推流、事件绑定，移植自 reference 的 `azureSpeechRecognizers.js`。

## 运行时与打包

- 开发：用系统 `node` 执行 `Helpers/AzureSpeechHelper/index.js`，依赖
  `node_modules` 就地安装（`npm install`）。
- 打包：`scripts/package-app.sh` 把 `index.js`、`azureTranslation.js`、
  `package.json`、`node_modules` 复制到 `Contents/Helpers/AzureSpeechHelper/`。
- helper 定位优先级：bundle 内 `Contents/Helpers/AzureSpeechHelper/index.js`，
  其次可执行目录同级，最后源码目录 `Helpers/AzureSpeechHelper/index.js`。

## 待办

- 把 Node helper 打成单可执行文件（pkg / Node SEA），免去交付时依赖系统 Node。
- 真实账号验证事件时序、字幕配对、断线重连与错误码。
- 粤语 `yue-CN`、吴语 `wuu-CN` 识别质量真机语料测试。
