# 语音语种改为按服务商分表

## 背景

接入 Azure 时早期实现把所有服务商的语种塞进同一张 `SpeechLanguage` 枚举（火山代号），
Azure 只在 helper 边界做一次映射。结果设置页选 Azure 时，源/目标下拉框里仍出现
火山专属的 `zhen`（中英反转互译）、`yue-CN`、`sh-CN`，对 Azure 毫无意义；
而且抹掉了 Azure「源用识别码 `zh-CN`、目标用翻译码 `zh-Hans`」的本质区别。

参考 `ref/Meeting-Copilot` 的设计纠正：语言表按服务商分开，UI 直接产出原生代号。

## 主要变更

### 新增 `Speech/Languages/`

- `SpeechLanguageOption.swift`：语言选项（代号 + 中文显示名）。
- `AzureLanguageCatalog.swift`：Azure 识别（源，BCP-47 带地区）与翻译（目标，简码/脚本码）
  两张独立表，会议常用精选约 18 种。
- `VolcengineLanguageCatalog.swift`：火山源/目标表，共用代号，含方言与 `zhen`。
- `SpeechLanguageCatalog.swift`：按服务商取表、默认值、代号校验与语种对校验。

### 重构配置模型

- `SpeechTranslationConfiguration` 从「两个 `SpeechLanguage` 枚举」改为
  「`provider` + `sourceCode` + `targetCode` 字符串」，由各 SpeechClient 直接透传给 helper。
- 删除 `SpeechLanguage` 枚举（原 `SpeechLanguage.swift` 改名为
  `SpeechTranslationConfiguration.swift`）。
- 删除 `Speech/Azure/AzureLanguageMapping.swift`：Azure 下拉框已产出原生码，无需映射。

### 设置与存储

- `AppSettings.speechSourceLanguage/Target` 由枚举改为 `String` 代号。
- `AppSettingsStore` 读取时按当前服务商校验代号，无效则回落服务商默认值。
- 设置页源/目标下拉框按当前服务商动态填充；切换服务商时重填并回落默认语种；
  翻译预设仅火山可用。

### 菜单栏

- 翻译模式菜单 provider 感知：火山显示预设并可切换；Azure 显示当前语种对并引导去设置。
- 选择火山翻译预设时自动切回火山服务商。

## 验证

- `swift build` 通过，无警告。
- `package-app.sh` 打包通过，应用冒烟启动无崩溃。

## 文档

- 更新 `docs/azure-speech.md` 语种章节为「按服务商分表」。
