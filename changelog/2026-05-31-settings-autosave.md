# 设置中心改为实时自动保存

## 背景

设置窗口此前需要手动点击"保存"按钮才能持久化配置，体验割裂。改为实时自动保存：
选项改动即存、文本框失焦即存、滑块松手即存，移除独立"保存"按钮。

## 变更

- `SettingsWindowController`
  - 删除"保存"按钮及 `save()` 方法，新增 `autosave(successStatus:)` 封装"校验 → 汇总 → 落盘 → 更新 helper/overlay → 状态提示"，语种组合非法时返回 false 且不写入。
  - `checkConfiguration()` 复用 `autosave(successStatus: "已检查")`。
  - `changeProvider()` 切换服务商后自动保存。
  - 透明度、字体大小滑块拖动中只实时预览，松手或键盘调整（非 `.leftMouseDragged`）才落盘，避免高频写 Keychain。
  - 状态行 `statusLabel` 拓宽至占满底部（原宽度为保存按钮预留）。
- `SettingsWindowLanguages`：翻译预设、源/目标语种改动后自动保存。
- `SettingsWindowAPIKey`：
  - 新增 `controlTextDidEndEditing`，API Key 与区域 Region 文本框失焦/回车时落盘。
  - 粘贴、清空 API Key 操作改为调用 `autosave`，立即持久化。
- `docs/settings-center.md`：行为约定与验证标准同步为实时自动保存。

## 验证

- `swift build` 通过。
- 程序化加载（打开窗口、切换服务商重填下拉框）使用 `selectItem(at:)`/`setAttribute`，不触发 action/delegate，故不会在加载时误触发保存。
