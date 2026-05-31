# 悬浮字幕窗

Easy Meeting 的透明悬浮窗，常驻桌面显示实时原文与译文。

## 结构

- `OverlayWindowController`：管理 `NSPanel`、位置 / 尺寸 / 透明度、快捷键、对外接口。
- `OverlayView`：绘制背景与两栏字幕（左原文、右译文），处理拖拽与缩放。
- `OverlayRecordButton`：角落录音开关按钮。

## 录音开关按钮

悬浮窗左上角内边距处常驻一个录音按钮，无需打开菜单栏即可控制录音。

- 待机：白色播放三角，点击开始录音。
- 录音中：红色方块，点击停止录音。
- 启动中 / 停止中：保持当前可见图标，不重复提交开始或停止请求，只提示当前操作正在进行。
- 按钮使用 24pt 点击热区和 14pt 图标，保证小按钮可点中。
- 按钮区域单独接收点击，不触发窗口拖拽 / 缩放（见 `OverlayView.hitTest`），并允许非激活悬浮窗的首次点击直接触发。

### 状态流转

```
点击按钮 → OverlayView.onToggleRecording
        → OverlayWindowController.onToggleRecording
        → StatusBarController.toggleRecording
        → MeetingSessionController.start / stop
        → rebuildMenu → OverlayWindowController.setRecording
        → OverlayRecordButton.isRecording → 切换三角 / 方块
```

录音状态由 `MeetingSessionController.recordingState` 统一管理，菜单栏"开始 / 停止录音"项与悬浮窗按钮共用同一套切换逻辑，状态保持一致。

会话层使用四个状态避免重复触发：

- `idle`：允许开始录音。
- `starting`：正在申请权限、创建会议、启动语音服务和音频采集；忽略重复开始。
- `recording`：允许停止录音。
- `stopping`：正在停止语音服务、写完音频文件和保存会议；忽略重复停止或开始，防止点停止后立刻创建新会议。

## 字幕时间戳

实时字幕每段文本前展示相对本次会议开始的时间戳：

```text
HH:MM:SS: 字幕文本
```

- 时间戳由 `SubtitleDisplayBuffer` 在字幕聚合层生成，Overlay 只负责绘制文本。
- 服务商返回分段时间时优先使用分段开始时间；没有时间字段时使用本地会议开始后的经过时间。
- 单次会议显示范围按最长约 8 小时设计，小时位固定两位，方便扫读和后续导出对齐。
- 当前录音会在 4 小时处自动结束，避免长时间无人值守导致服务连接和本地文件异常膨胀。
