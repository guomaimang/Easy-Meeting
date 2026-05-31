# 最近会议菜单改为直接打开文件夹

## 变更内容

- 菜单栏「最近会议」由展开会议子菜单（逐条列出每场会议）改为单个可点击项，点击后用 Finder 打开会议根目录 `~/Documents/Easy Meeting/Meetings`。
- 删除 `StatusBarController` 中不再使用的 `historyMenuItem()` 与 `exportMeeting(_:)` 方法，新增 `openMeetingsFolder()`。
- 保留 `MeetingStore.recentMeetings()`、`MeetingStore.exportMeeting()` 与 `MeetingExporter` 导出实现，待后续重新接入入口。

## 文档同步

- `docs/storage.md`：更新「最近会议」菜单行为说明。

## 验证

- `swift build` 编译通过。
