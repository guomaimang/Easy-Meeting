# 悬浮窗录音开关按钮

## 变更内容

在悬浮字幕窗左上角加入常驻录音开关按钮，无需打开菜单栏即可控制录音。

- 新增 `OverlayRecordButton`：14pt 小按钮，待机绘制白色播放三角、录音中绘制红色方块。
- `OverlayView` 接入按钮：定位左上角内边距区，`hitTest` 让按钮区域优先接收点击，其余区域仍用于拖拽 / 缩放；暴露 `onToggleRecording` 与 `isRecording`。
- `OverlayWindowController` 暴露 `onToggleRecording` 与 `setRecording(_:)`。
- `StatusBarController` 将按钮点击接到既有 `toggleRecording`，并在 `rebuildMenu` 时同步按钮图标，保持与菜单栏录音状态一致。
- 新增文档 `docs/overlay-window.md`。

## 验证

- `swift build` 通过。
