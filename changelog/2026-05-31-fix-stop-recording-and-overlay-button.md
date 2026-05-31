# 2026-05-31 修复停止录音误报与悬浮窗录音按钮失效

## 问题 1：点停止转录时显示「停止录音失败」（三家服务商均复现）

### 真实根因（经终端日志调试确认）

录音落盘的 AAC 编码码率设为 **96kbps**，超出了 **16kHz 单声道 AAC 的合法码率上限（48kbps）**。
经 `AVAudioConverter.applicableEncodeBitRates` 验证，该格式合法码率仅为
`[12000, 16000, 20000, 24000, 28000, 32000, 40000, 48000]`，不含 96000。

后果链路：

1. 录音过程中 AVAssetWriter 编码失败，报 `AVFoundationErrorDomain code=-11861 (Cannot Encode Media)`，
   `append` 将 `isRecording` 置为 `false`。
2. 用户点停止时，`stopRecording` 发现 `isRecording=false`，返回 `.notRecording`。
3. UI 显示「停止录音失败」。

由于录音前段已写入文件，播放时「看似成功」，实际文件中途损坏；且与语音识别无关，故三家服务商均复现。

### 调试过程修正了最初的误判

最初推断为「停止时收尾线程竞态（markAsFinished 之后又 append）」，并据此把 writer 收尾改派发到
`captureQueue`。加细粒度日志、从终端实跑后，日志显示根因实为录音中途编码失败，与竞态无关。
收尾改派发到串行队列的改动作为防御性加固予以保留。

### 修复

- 新增 `AudioStreamFormat.aacEncoderBitRate = 32_000`，集中管理录音码率并注明合法区间约束。
- `AudioRecorder` 改用该常量替换硬编码的 96_000。
- `append` 中 writer 进入 `failed` 时记录真实 `domain/code/desc`，作为埋点保留，便于后续排查。
- writer 收尾派发到 `captureQueue`，新增 `AssetWriterInputBox` 满足 `@Sendable` 捕获要求。

### 验证

终端实跑复现：录音全程 `writer.status=writing`、`error=nil`，停止时干净走到
`finishWriting 成功完成。status=completed`，UI 显示「录音已保存」。

## 问题 2：悬浮窗左上角录音开关按钮点击无效

- 根因：`OverlayView.hitTest(_:)` 坐标系处理错误。`hitTest` 传入的 `point` 处于父视图坐标系，
  而 `OverlayView` 为 `isFlipped = true` 翻转视图，原代码未换算坐标即比对命中区，导致 Y 轴方向错位，
  点击落不到按钮、被当作拖拽处理，`onToggle` 永不触发。
- 修复：`hitTest` 中先用 `convert(point, from: superview)` 换算到自身坐标系，再用
  `recordButton.frame.contains(local)` 判定命中。

## 验证

- `swift build` 通过，无警告无报错。
- 问题 1 已终端实跑确认修复。
