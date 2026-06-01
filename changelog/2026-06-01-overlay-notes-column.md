# 悬浮窗第三栏（备注）

## 背景

演示场景下用户需要在悬浮窗里同时看到实时字幕和自己提前准备的演示稿 / 提词，避免来回切窗口。

## 变更

- `AppSettings` 新增 `overlayNotesEnabled: Bool` 与 `overlayNotesText: String`，默认关闭、空文本，落到 `UserDefaults`。
- `SettingsSection` 新增 `.notes` 项，归在新的"演示"分组，侧栏图标 `note.text`。
- `SettingsWindowNotes.swift` 新文件：实现"备注"页布局（开关 + 多行文本框），并实现 `NSTextViewDelegate` 实时同步与失焦保存。
- `SettingsWindowController` 注册新页面，将开关 / 文本变化通过 `OverlayWindowController.setNotesEnabled(_:)` / `setNotesText(_:)` 同步到悬浮窗，文本编辑过程中实时预览，失焦后落盘。
- `OverlayView` 新增 `notesEnabled` 与 `updateNotes(_:)`：开启时切换为三栏等宽布局（原文 / 译文 / 备注），关闭时回到原两栏；备注栏复用 `OverlayScrollView`，独立维护滚动位置，不主动滚到底；滚轮按 x 落点分发到 2 / 3 栏。
- 拆出 `OverlayViewLayout.swift` 承载 setup / 布局工具及辅助结构，避免单文件超过 300 行。
- `OverlayWindowController` 在初始化阶段读取设置回填备注开关与文本，并暴露 `setNotesEnabled` / `setNotesText`。

## 文档

- `docs/overlay-window.md`：补充"备注栏"小节描述布局与行为。
- `docs/settings-center.md`：信息架构、行为约定、验证标准均增加"备注"相关条目。

## 验证

- `swift build` 通过。
- 设置 → 备注 切换"启用悬浮窗备注栏"开关，悬浮窗即时切换三栏 / 两栏布局。
- 在多行文本框输入演示稿，悬浮窗右侧栏实时同步文本；失焦后重启应用，备注开关与文本恢复。
- 滚轮在悬浮窗右栏区域只滚动备注，不影响原文 / 译文滚动位置。
