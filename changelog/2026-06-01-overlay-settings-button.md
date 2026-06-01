# 悬浮窗顶栏新增设置入口齿轮按钮

## 变更内容

- 新增 `Sources/EasyMeeting/Overlay/OverlaySettingsButton.swift`：24pt 半透明圆底，绘制 SF Symbol `gearshape` 齿轮图标，与录音按钮视觉风格一致；自身处理鼠标点击，避免被 `OverlayView` 拦截为窗口拖拽。
- `OverlayToolbarView`：新增 `onOpenSettings` 回调和齿轮按钮；`layout()` 把齿轮按钮紧贴麦克风下拉右侧（间距 8pt），下拉按内容自适应宽度，不再撑满整条工具栏。
- `OverlayView` / `OverlayWindowController`：新增 `onOpenSettings` 透传属性，把按钮事件转发到状态栏控制器。
- `StatusBarController.init`：在已有 `onToggleRecording` / `onSelectDevice` / `onOpacityChange` 之外，把 `overlayController.onOpenSettings` 接到内部的 `openSettings()`，与菜单栏「设置」入口共用同一份 `SettingsWindowController.show()` 逻辑。
- `docs/overlay-window.md`：在「结构」「顶部工具栏」与新增的「设置入口按钮」小节同步说明齿轮按钮的位置、命中区与回调链路。

## 用户可感知效果

- 悬浮字幕窗顶栏从左到右依次为：开始/停止录音按钮 → 麦克风下拉 → 齿轮按钮，点击齿轮直接打开设置窗口，无需绕到屏幕右上角的菜单栏。
- 录音中、未录音状态下都可点击；按钮与录音按钮视觉风格一致，下拉按内容自适应宽度。

## 验证

- `swift build` 通过，无 lint 错误。
- 手动 E2E：点击悬浮窗麦克风下拉右侧的齿轮 → 设置窗口出现；与菜单栏「设置」入口打开的是同一个 `SettingsWindowController` 实例，状态保持一致；录音过程中点击齿轮不影响识别与字幕。
