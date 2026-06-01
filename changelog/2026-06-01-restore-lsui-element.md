# 恢复 LSUIElement，修回状态栏 EM 图标

## 背景

`2026-06-01-app-bundle-menu-bar.md` 那次为了让顶部应用菜单栏显示，从 `Packaging/Info.plist`
里删掉了 `LSUIElement`，但 `Sources/EasyMeeting/main.swift` 仍保留
`app.setActivationPolicy(.accessory)`。这两个设置语义等价，运行期净效果仍然是 agent
形态，**顶部菜单栏永远不会切到本 app**，那次提交的目标根本达不到。

副作用更严重：`.app` 启动时进程先按 regular 应用初始化，再切到 `.accessory`，在 Sonoma /
Sequoia 上这个时序经常导致 `NSStatusItem` 不出现，于是右上角的 `EM` 图标丢了——这才是
用户实际看到的 bug。

## 变更

- `Packaging/Info.plist` 加回 `LSUIElement=YES`，让进程从 dyld 启动那刻就是 agent，
  状态栏槽位稳定预留。
- `docs/packaging.md` 「菜单栏与权限」章节改为当前事实：无 Dock、不占顶部菜单栏，
  所有入口集中在右上角 `EM` 状态栏菜单；并记录"`.accessory` 与顶部菜单可见互斥"的
  结论，避免下次再绕回来。

## 不动的地方

- `main.swift` 的 `app.setActivationPolicy(.accessory)` 保留，作为 Info.plist 缺失时的
  兜底。
- `AppDelegate.setupMainMenu()` 保留：它虽然不显示在顶部，但仍向响应链注册
  `Cmd+C / Cmd+V / Cmd+A` 等文本快捷键，设置窗口里的输入框依赖这些。

## 验证

- 重新跑 `zsh scripts/package-app.sh`，确认 `.app/Contents/Info.plist` 含
  `LSUIElement` 且为 `<true/>`。
- 启动 `.app`，右上角状态栏出现 `EM`，点击后可看到「设置 / 显示悬浮窗 / 显示/隐藏悬浮窗
  / 开始录音 / 翻译模式 / 麦克风 / 最近会议 / 退出」等项。
- `/tmp/em_diag.log` 中 `init` 与 `delayed` 两条记录的 `button` 非 nil、`hasWindow=true`。
