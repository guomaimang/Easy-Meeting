# 2026-05-31 修复停止录音误报与悬浮窗录音按钮失效

## 问题 1：点停止转录时误报「停止录音失败」（三家服务商均复现）

- 现象：Agent / Azure / 火山豆包任一模式下点停止，都提示「停止录音失败」，但日志与实际体验均显示已正常停止、文件可用。
- 根因：`AudioRecorder` 的写入收尾存在线程竞态。`append(_:)` 运行在串行队列 `captureQueue`，而 `stopRecording` 在主线程直接调用 `markAsFinished()`。若停止瞬间仍有在途音频帧在 `captureQueue` 上执行，会发生「`markAsFinished` 之后又 `append`」，触发 AVAssetWriter 写入报错，进而误报失败。
- 修复：将 writer 收尾（`markAsFinished` / `finishWriting`）整体派发到 `captureQueue.async`。先由 `stopCaptureOnly()` 摘除采集 delegate，再借串行队列 FIFO 顺序保证所有在途 `append` 先执行完，杜绝竞态。新增 `AssetWriterInputBox` 以满足 `@Sendable` 闭包捕获要求。

## 问题 2：悬浮窗左上角录音开关按钮点击无效

- 现象：悬浮窗左上角的开始 / 停止按钮点了没反应。
- 根因：`OverlayView.hitTest(_:)` 坐标系处理错误。`hitTest` 传入的 `point` 处于父视图坐标系，而 `OverlayView` 为 `isFlipped = true` 翻转视图，原代码未换算坐标即比对 `bounds` 与按钮命中区，导致 Y 轴方向命中区错位，点击落不到按钮、被当作拖拽处理，`onToggle` 永不触发。
- 修复：`hitTest` 中先用 `convert(point, from: superview)` 换算到自身坐标系，再用 `recordButton.frame.contains(local)` 判定命中。回调链路 `OverlayRecordButton → OverlayView → OverlayWindowController → StatusBarController.toggleRecording` 本身正常，无需改动。

## 验证

- `swift build` 通过，无警告无报错。
