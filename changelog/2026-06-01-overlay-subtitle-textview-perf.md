# 2026-06-01 字幕滚动卡顿与贴底跟随修复

## 背景

转录时间一长，悬浮窗会出现两个问题：

1. 滚动突然失灵，新增字幕不再自动滚到底，看起来"卡死"。
2. 滚轮翻动时帧率明显下降，调整窗口尺寸更是肉眼可见地果冻。

## 根因

`OverlayScrollView` 的 `documentView` 用的是 `OverlayContentView` 包一个
`NSTextField(wrappingLabelWithString:)`，每次写入文本都触发：

- `NSTextField.stringValue =` 整段历史 → cell 重新排版整段文本；
- `OverlayView.layout()` 调用 `label.heightFor(width:)`，内部走
  `cell.cellSize(forBounds:)`，对长文本是 O(N)+ 的同步重排版；
- `update(...)` 末尾 `DispatchQueue.main.async { scrollToBottom() }`，
  当 layout 还没完成时 `documentView.bounds.height` 仍是旧值，
  `scrollToBottom` 实际滚到了"上一帧"的底部，看起来就是不滚了。

每次窗口缩放都会反复跑 `cellSize(forBounds:)`，文本越长越卡。

## 修复

把字幕列改造为 `NSScrollView` + `NSTextView`，让 TextKit 接管排版：

- `NSLayoutManager` 是惰性 + 增量布局，长文本与 resize 不再阻塞主线程；
- `textView.isVerticallyResizable = true` + `widthTracksTextView = true`，
  字幕高度跟随容器自动扩展，`OverlayView.layout()` 不再需要测量文本；
- `OverlayScrollView.updateText(_:font:color:)` 写入文本前先快照
  `isPinnedToBottom`，写入后调用 `layoutManager.ensureLayout(for:)` 强制
  完成可见区排版，再同步滚到底，确保贴底跟随实时生效。

## 变更范围

- `Sources/EasyMeeting/Overlay/OverlayScrollView.swift`：替换为基于
  `NSTextView` 的字幕列，新增 `OverlaySubtitleTextView`、`updateText`、
  `scrollToBottom` 内部 `ensureLayout`。
- `Sources/EasyMeeting/Overlay/OverlayView.swift`：移除三个
  `NSTextField` 与 `OverlayContentView`，改为通过 `updateText` 写入；
  字号缓存当前文本以便 `applyFonts` 重新上色刷新。
- `Sources/EasyMeeting/Overlay/OverlayViewLayout.swift`：删除
  `setupLabels` / `NSTextField.heightFor`，`layoutColumn` 只设置
  scrollView frame；新增 `applyFonts` 复用 `updateText`。

## 验证

- `swift build`：编译通过。
- 期望：长时间录音字幕仍然贴底自动跟随；滚轮、resize 不再果冻。
