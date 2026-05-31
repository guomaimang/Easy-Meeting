# 悬浮字幕窗

Easy Meeting 的透明悬浮窗，常驻桌面显示实时原文与译文。

## 结构

- `OverlayWindowController`：管理 `NSPanel`、位置 / 尺寸 / 透明度、快捷键、对外接口。
- `OverlayView`：绘制背景与两栏字幕（左原文、右译文），处理拖拽与缩放。
- `OverlayRecordButton`：角落录音开关按钮。

## 录音开关按钮

悬浮窗左上角内边距处常驻一个 14pt 小按钮，无需打开菜单栏即可控制录音。

- 待机：白色播放三角，点击开始录音。
- 录音中：红色方块，点击停止录音。
- 按钮区域单独接收点击，不触发窗口拖拽 / 缩放（见 `OverlayView.hitTest`）。

### 状态流转

```
点击按钮 → OverlayView.onToggleRecording
        → OverlayWindowController.onToggleRecording
        → StatusBarController.toggleRecording
        → MeetingSessionController.start / stop
        → rebuildMenu → OverlayWindowController.setRecording
        → OverlayRecordButton.isRecording → 切换三角 / 方块
```

录音状态由 `MeetingSessionController.isRecording` 统一管理，菜单栏"开始 / 停止录音"项与悬浮窗按钮共用同一套切换逻辑，状态保持一致。
