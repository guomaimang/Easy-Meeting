# 状态栏菜单去重 & 隐藏后字幕不再强行弹回

## 背景

状态栏菜单里同时存在「显示悬浮窗 ⌘S」和「显示/隐藏悬浮窗 ⌘H」两项，含义重叠，
其中前者只是把 overlay 拉回前台并写入「Easy Meeting is ready.」状态文本，
和后者的 toggle 只是行为子集。

更严重的是 toggle 把 overlay 隐藏后，只要会议还在跑，`MeetingSessionController`
的字幕回调每来一帧都会落到 `OverlayWindowController.showStatus(...)`，而旧实现
里 `showStatus` 末尾无条件 `show()`，于是窗口立刻被拉回前台 —— 用户的「隐藏」
形同虚设。

## 变更

- 删除菜单项「显示悬浮窗 ⌘S」与对应的 `StatusBarController.showOverlay`，
  保留唯一入口「显示/隐藏悬浮窗 ⌘H」。
- 同步移除 `OverlayWindowController.showReadyStatus()`（再无调用方，按
  `AGENTS.md` 「直接删除」原则清理）。
- `OverlayWindowController` 新增 `isUserHidden` 标记：
  - `toggleVisibility()` 隐藏时置 `true`，重新显示时置 `false`。
  - `showStatus(source:translation:)` 始终刷新文本内容，但仅在
    `isUserHidden == false` 时才调用 `show()` 把窗口拉回前台。
- 这样录音中字幕推送只更新内容，不会破坏用户的隐藏意图；用户重新按
  ⌘H 时再恢复显示，最新字幕也已经在缓冲中。

## 不动的地方

- `moveBy / adjustOpacity / resetFrame` 这类全局快捷键路径仍走 `show()`，
  它们是用户主动操作，沿用「主动操作可重新唤出」语义。
- `AppDelegate` 启动时的 `overlayController.show()` 不受影响：
  `isUserHidden` 初始为 `false`，首次启动仍然正常出窗。

## 验证

1. `swift build` 通过。
2. 启动 `.app`，开启录音 → 见字幕滚动 → 按 ⌘H 隐藏 →
   持续说话观察 4–5 帧字幕事件 → 窗口保持隐藏，不再被拉回。
3. 再按一次 ⌘H → 窗口恢复显示，字幕内容是最新一条，未丢失。
4. 状态栏菜单确认只剩单一「显示/隐藏悬浮窗 ⌘H」项。
