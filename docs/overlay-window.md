# 悬浮字幕窗

Easy Meeting 的透明悬浮窗，常驻桌面显示实时原文与译文。

代码位于 `Sources/EasyMeeting/Overlay/`。

## 结构

- `OverlayWindowController`：管理 `NSPanel`、位置 / 尺寸 / 透明度、快捷键、对外接口。
- `OverlayView`：布局顶栏与字幕区，处理拖拽与缩放。字幕区按"备注栏开关"在两栏（原文 / 译文）与三栏（原文 / 译文 / 备注）之间切换。
- `OverlayToolbarView`：顶部工具栏，承载录音按钮、麦克风下拉与设置入口。
- `OverlayRecordButton`：录音开关按钮。
- `OverlaySettingsButton`：设置入口按钮，绘制齿轮图标，点击直接打开设置窗口。
- `OverlayScrollView`：字幕滚动视图，内部 `documentView` 使用 `NSTextView`（`OverlaySubtitleTextView`）承载字幕，走 TextKit 增量排版以保证长字幕与窗口缩放下仍然流畅。提供 `updateText(_:font:color:)` 与 `scrollToBottom()`，支持「贴底自动跟随」：写入文本前快照 `isPinnedToBottom`，写入后通过 `layoutManager.ensureLayout(for:)` 强制完成可见区排版再滚到底，避免读到旧 `contentSize` 导致跟随失效。

## 顶部工具栏

悬浮窗顶部常驻一条工具栏，上方留 8pt margin，与下方字幕区分隔。无需打开菜单栏即可控制录音、切换麦克风、打开设置。

- 左侧：录音开关按钮。
- 紧邻按钮：麦克风下拉（`NSPopUpButton`，深色外观融入半透明 HUD），按下拉项内容自适应宽度，不撑满整条工具栏。
- 麦克风下拉右侧：设置入口齿轮按钮，点击触发 `OverlayWindowController.onOpenSettings`，由状态栏控制器调用 `SettingsWindowController.show()` 打开设置窗口；与菜单栏「设置」入口共用同一窗口实例。
- 工具栏区域交给子控件接收点击（见 `OverlayView.hitTest`），其余区域仍归窗口拖拽 / 缩放，并允许非激活悬浮窗的首次点击直接触发。
- 麦克风下拉与齿轮按钮之间保留 8pt 间距；下拉宽度按可用空间收缩，但不会侵占齿轮按钮的命中区。

### 设置入口按钮

- 与录音按钮同样使用 24pt 半透明圆形底，14pt 齿轮图标（SF Symbol `gearshape`），与录音按钮视觉风格保持一致。
- 录音状态变化不影响该按钮可用性，任何时刻都允许打开设置窗口。
- 命中区独立于拖拽 / 缩放区域，避免点击落到 `OverlayView` 上误触发窗口移动。

### 麦克风下拉

- 下拉项与菜单栏「麦克风」子菜单共享 `AudioDeviceManager` 状态，选中项实时同步。
- 录音中切换走热切换路径，识别与字幕不中断，详见 `docs/audio-hot-swap.md`。
- 未录音时切换仅记录选择，下次开始录音生效。

## 录音开关按钮

- 待机：白色播放三角，点击开始录音。
- 录音中：红色方块，点击停止录音。
- 启动中 / 停止中：保持当前可见图标，不重复提交开始或停止请求，只提示当前操作正在进行。
- 按钮使用 24pt 点击热区和 14pt 图标，保证小按钮可点中。

### 状态流转

```
点击按钮 → OverlayToolbarView.onToggleRecording
        → OverlayWindowController.onToggleRecording
        → StatusBarController.toggleRecording
        → MeetingSessionController.start / stop
        → rebuildMenu → OverlayWindowController.setRecording
        → OverlayToolbarView.isRecording → 切换三角 / 方块
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

## 备注栏（演示稿）

悬浮窗最右侧可选第三栏，用于显示用户在设置中预先录入的演示稿 / 提词，方便分享屏幕做 presentation 时直接对照念稿，同时不影响左侧实时字幕。

- 默认关闭。开启后字幕区从两栏布局切换为三栏等宽布局（原文 / 译文 / 备注）。
- 备注内容来自"设置 → 备注 → 备注内容"多行文本框，编辑时悬浮窗实时刷新文本，文本框失去焦点后写入持久化。
- 备注栏支持鼠标滚轮上下滚动，独立维护滚动位置，不与原文 / 译文相互牵动；备注内容更新时不会强制滚动到底部，避免打断当前阅读位置。
- 备注开关与备注内容均保存到 `UserDefaults`，下次启动恢复。
- 备注栏文本字号沿用字幕字体大小设置，配色采用纯白以保证演示场景下的可读性。
