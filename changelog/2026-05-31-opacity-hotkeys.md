# 2026-05-31 快捷键改为调整悬浮窗透明度

## 变更内容

- 将 `Command + +` / `Command + =` / `Command + -` 由"放大 / 缩小悬浮窗"改为"调整悬浮窗不透明度"。
  - `Command + +` / `Command + =`：每次提高不透明度 0.05（更清晰）。
  - `Command + -`：每次降低不透明度 0.05（更透明）。
  - 取值钳制在 0.1–1，调整后立即生效并写入 `UserDefaults`。
- 窗口缩放仅保留鼠标边缘 / 角落拖拽，移除键盘缩放快捷键，删除 `resizeBy` 与 `Layout.resizeStep` 死代码。
- `Command + 方向键`（移动）、`Command + 0`（恢复位置和尺寸）保持不变。
- 移除菜单栏下拉里的"悬浮窗透明度（低 / 中 / 高）"子菜单：透明度已可由快捷键和设置中心滑块调整，菜单档位多余。删除 `opacityMenuItem`、`setOpacityLow/Medium/High`、`saveOpacity` 死代码。

## 涉及文件

- `Sources/EasyMeeting/OverlayHotKeyController.swift`：枚举与回调由 `enlarge` / `shrink` 改名为 `increaseOpacity` / `decreaseOpacity`。
- `Sources/EasyMeeting/OverlayWindowController.swift`：新增 `adjustOpacity(by:)` 与 `onOpacityChange` 回调，删除 `resizeBy`。
- `Sources/EasyMeeting/StatusBarController.swift`：接入 `onOpacityChange`，抽出 `persistOpacity` 复用透明度持久化逻辑；移除菜单栏透明度子菜单及其专用方法。
- `docs/settings-center.md`：同步快捷键说明，更新菜单栏快捷操作描述。
