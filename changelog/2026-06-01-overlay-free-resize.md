# 悬浮窗自由拖拽尺寸

## 背景

此前 `OverlayWindowController` 在 `Layout` 中硬编码了 `minimumSize = 420×140`、
`maximumSize = 1280×360`，并在 `resizedFrame` 内对拖拽出的尺寸做 `min/max` 钳制，
导致用户拖拽悬浮窗时高度最大只能到 360pt，宽度最大只能到 1280pt，无法满足"自由调整尺寸"的诉求。

## 变更

文件：`Sources/EasyMeeting/Overlay/OverlayWindowController.swift`

- 移除 `Layout.maximumSize`，不再对拖拽尺寸设置上限。
- `Layout.minimumSize` 改为直接复用 `Layout.defaultSize`（`760 × 184`），
  即"最小尺寸 = 默认初始尺寸"，禁止用户把悬浮窗拖到比初始尺寸更小，
  避免内容被压缩到不可读。
- `resizedFrame` 中的尺寸钳制由 `min(max(..., min), max)` 简化为 `max(..., min)`，
  仅做最小尺寸保护，宽高均不再设上限。
- 屏幕边界由 `clamped(_:)` 仅约束位置（保证窗口原点落在 `visibleFrame` 内），
  尺寸本身不再被限制，可超出屏幕可视区域。

## 影响

- 用户可以通过拖拽悬浮窗四边/四角自由放大宽高，包括拖出比屏幕更大的尺寸。
- 用户**无法**把悬浮窗拖到比 `760 × 184` 更小的尺寸。
- 重置快捷键仍会把窗口还原为 `defaultSize = 760×184` 的默认尺寸与默认位置，
  与最小尺寸保持一致。
