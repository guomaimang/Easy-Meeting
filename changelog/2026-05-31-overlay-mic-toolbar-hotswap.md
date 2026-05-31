# 麦克风会中热切换 + 悬浮窗顶部工具栏

## 背景

此前会中无法切换麦克风：设备在 `startRecording` 时被固定进 `AVCaptureDeviceInput`，
`AudioDeviceManager.selectDevice` 仅改变量，对在跑的会话无效。换麦只能停录音重开，
会中断识别会话、清空字幕、切断录音文件。

## 变更

### 音频热切换

- `AudioRecorder` 新增 `switchDevice(to:completion:)`：在 captureQueue 上事务式
  （`beginConfiguration` / `removeInput` / `addInput` / `commitConfiguration`）替换 input，
  不触碰 output / delegate / onAudioFrame / AVAssetWriter，下游识别与录音文件连续不断。
  新设备无法加入时回滚旧 input，录音继续。
- `AVCaptureSession.inputs` 作为当前 input 的事实来源，移除冗余的 `input` 存储属性，
  避免跨线程读写竞态。`selectedCaptureDevice` 改为静态 `captureDevice`，供闭包内调用。
- 抽出 `AudioCaptureBoxes.swift` 承载三个 `@unchecked Sendable` 包装类，
  使 `AudioRecorder.swift` 回到 300 行以内。
- `MeetingSessionController` 新增 `switchMicrophone(to:onStatus:)`：录音中走热切换，
  未录音仅记录选择；失败时回滚选中项与提示。

### 悬浮窗顶部工具栏

- 4 个 overlay 文件迁入 `Sources/EasyMeeting/Overlay/`，按 feature 组织。
- 新增 `OverlayToolbarView`：顶栏承载录音按钮 + 麦克风 `NSPopUpButton`（深色外观）。
- 录音按钮从字幕区左上角挪到顶栏，顶部留 8pt margin，字幕区下移。
- 抽出 `OverlayScrollView.swift`（含 `OverlayContentView`），`OverlayView` 保持精简。
- `OverlayWindowController` 暴露 `onSelectDevice` / `updateDevices`，默认窗高 156→184、
  最小高 104→140。
- `StatusBarController` 在 `rebuildMenu` 把设备列表推给浮窗下拉，菜单项与下拉
  共用 `switchMicrophone` 入口，两边状态一致。

## 文档

- 新增 `docs/audio-hot-swap.md`：热切麦设计与「无感知」原理。
- 更新 `docs/overlay-window.md`：顶部工具栏与麦克风下拉小节。

## 验证

- `swift build` 通过。
- 待真机验证：录音中下拉切麦，确认字幕连续不断、`writer.status` 不进 failed、
  停止后录音文件时长完整可播放。
