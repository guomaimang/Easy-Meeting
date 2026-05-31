# 接入 Azure 流式翻译

接入微软 Azure 认知服务的实时语音翻译，作为与火山引擎 S2T 平级的语音服务。
范围限定为流式翻译（源语种 → 目标语种），不做说话人区分、双麦克风、TTS。

## 主要变更

### 文档

- 新建 `docs/azure-speech.md`：接入设计、进程间协议、事件映射、语种映射、打包说明。
- 更新 `docs/tech-stack.md`：外部服务章节增加 Azure 可选链路说明。

### Node helper（`Helpers/AzureSpeechHelper/`）

- `package.json`：依赖 `microsoft-cognitiveservices-speech-sdk@1.50.0`。
- `azureTranslation.js`：移植 reference 的 `TranslationRecognizer` 配置与事件绑定，
  音频输入改用 Node `PushAudioInputStream`，直接写入 16kHz/16bit/单声道 PCM。
- `index.js`：stdin/stdout JSON Lines 主循环，协议与火山 Go helper 一致。

### Swift Azure 客户端（`Sources/EasyMeeting/Speech/Azure/`）

- `AzureHelperProtocol.swift`：定义命令与事件的 JSON 线协议。
- `AzureHelperRuntime.swift`：定位 node 与 helper 脚本，生成配置诊断。
- `AzureHelperSpeechClient.swift`：实现 `SpeechClient`，拉起 node 子进程、
  推送音频、解析事件，映射到 `RealtimeSpeechEvent`。
- `AzureLanguageMapping.swift`：`SpeechLanguage` → Azure 识别码/翻译码映射与校验，
  明确拒绝 Azure 不支持的 `zhen`。

### 设置层

- `SpeechProvider` 新增 `.azure`，`SpeechClientFactory` 分发。
- `AppSettings`/`AppSettingsStore` 新增 `azureSpeechKey`（Keychain）和
  `azureSpeechRegion`（UserDefaults）。
- 设置页改为 provider 感知：选择 Azure 时显示「区域 Region」和「Azure 语音密钥」，
  替换火山的 Resource ID 行；按 provider 切换诊断信息与语种校验。
- 按 provider 分别缓存密钥草稿，切换服务商不丢失已输入内容。
- `SettingsWindowController.swift` 拆出 `SettingsWindowProvider.swift`，
  控制文件行数。

### 打包

- `scripts/package-app.sh` 增加构建/复制 Azure helper 到
  `Contents/Helpers/AzureSpeechHelper/`，含 `node_modules`。

## 验证

- `swift build` 通过。
- Node helper 用假凭据喂 start/audio/finish，事件流正常、不崩溃、
  无法连服务端时输出 error 事件。
- `package-app.sh` 跑通，helper 与 SDK 正确打入 `.app`，从打包位置可独立运行。

## 待办

- 把 Node helper 打成单可执行文件（pkg / Node SEA），免去交付依赖系统 Node。
- 真实账号验证事件时序、字幕配对、断线重连与错误码。
