# 设置页新增退出按钮（带二次确认）

## 背景

此前用户只能通过状态栏菜单或系统快捷键退出 Easy Meeting，
设置窗口本身没有显式的退出入口。需要在"程序"设置页中加入一个
显眼但不易误触的退出按钮。

## 变更

文件：`Sources/EasyMeeting/Settings/SettingsWindowPages.swift`

- 在 `appPage()` 底部新增一个独立分组（`y = 120, height = 60`），
  内含红色（`bezelColor = .systemRed`）的"退出 Easy Meeting"按钮。
- 新增 `@objc func quitApplication()`：
  - 使用 `NSAlert` 作为二次确认对话框：
    - 标题："确认退出 Easy Meeting？"
    - 说明："退出后会停止当前录音与翻译，并关闭悬浮窗。"
    - 样式：`.warning`。
  - 按钮顺序：先添加"退出"，再添加"取消"；
    显式把"取消"设为回车默认按钮（`keyEquivalent = "\r"`），
    避免按回车误退出，必须显式点击"退出"。
  - 优先以 sheet 形式 `beginSheetModal(for: window, ...)` 弹出，
    没有 window 时降级为 `runModal()`。
  - 用户确认后调用 `NSApp.terminate(nil)`，走系统标准退出流程，
    `AppDelegate.applicationWillTerminate(_:)` 中的清理逻辑（停录音、
    关闭悬浮窗等）会自动触发。

## 影响

- 设置 → 程序页 底部出现"退出 Easy Meeting"红色按钮。
- 点击不会立即退出，会先弹出 sheet 对话框二次确认，默认按钮为"取消"。
- 控制器主文件 `SettingsWindowController.swift` 已 300+ 行，
  按项目规范不再扩张，新方法落在已有的 `SettingsWindowPages` 扩展中。
