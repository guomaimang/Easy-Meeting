# 悬浮窗透明度下限调整为 10%

## 变更内容

将悬浮字幕窗透明度的可调下限从 25% 降到 10%，让窗口可以更透明。

涉及的下限钳制统一改为 `0.1`：

- `SettingsWindowController.opacitySlider`：滑块 `minValue` 0.25 → 0.1
- `AppSettingsStore.clampedOpacity`：钳制下限 0.25 → 0.1
- `OverlayWindowController.init` / `setOpacity`：钳制下限 0.25 → 0.1

## 验证

- `swift build` 编译通过。
