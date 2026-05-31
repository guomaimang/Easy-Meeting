# 2026-05-31 火山 helper Swift 侧分层

## 变更

- 将原先内联在 `VolcengineHelperSpeechClient.swift` 的协议类型与运行时检测拆分为独立文件，遵循单一职责：
  - 新增 `VolcengineHelperProtocol.swift`：承载 JSON 线协议类型 `VolcengineHelperCommand`、`VolcengineHelperEvent` 和 `VolcengineHelperError`。
  - 新增 `VolcengineHelperRuntime.swift`：承载 helper 可执行文件定位（bundle / 可执行目录 / `.build/debug`）与配置诊断文本生成。
  - `VolcengineHelperSpeechClient.swift` 删除内联的命令、事件、错误类型与 `helperURL()`，改为复用上述两个文件，去除死代码。
- 设置窗口新增“检查配置”按钮：保存后调用 `VolcengineHelperRuntime.diagnostic`，在“本地 helper”一栏展示 App Key / Access Key / Resource ID 与 helper 可执行性的诊断结果。
- 同步更新 `docs/volcengine-speech.md`，记录 Swift 侧三文件分层职责。

## 验证

- `swift build -c debug` 全量编译通过。
- `zsh scripts/package-app.sh` 通过，`.app` 内同时打包主程序与 `easy-meeting-ast-helper`。
- helper JSON 协议冒烟：`finish` 正常退出、非法 JSON 与未知命令均返回 `error` 事件。
- 全部源文件均在 300 行规约内。
