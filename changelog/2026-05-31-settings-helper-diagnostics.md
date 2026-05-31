# 2026-05-31 设置页 helper 诊断

## 变更

- 设置窗口新增“检查配置”按钮，保存当前火山配置并显示诊断结果。
- 新增 helper 运行时查找逻辑，支持 `.app/Contents/Helpers` 和本地 `.build/debug`。
- 拆分 helper JSON Lines 协议类型，保持单文件不超过 300 行。
- 同步 README、火山语音文档和产品计划。

## 验证

- `swift build` 通过。
- `zsh scripts/package-app.sh` 通过。
- `.build/debug/Easy Meeting.app/Contents/Helpers/easy-meeting-ast-helper` 存在且可执行。
