# 会议结束时自动导出原文/译文 markdown

## 变更内容

- 正常点击「停止录音」结束会议时，自动在会议目录生成两份 markdown：
  - `transcript-source.md`（原文）
  - `transcript-translation.md`（译文）
- 异常退出（崩溃/强制退出）不会走停止流程，因此不会触发导出，符合预期。

## 实现

- `MeetingExporter` 新增 `exportTranscriptMarkdown(meeting:segments:)`，按原文/译文分别生成带时间码的 markdown，跳过空内容段。
- `MeetingStore` 新增 `exportTranscriptMarkdown(for:)`，将 `MeetingRecord` 转为 `StoredMeetingSummary` 后取段导出。
- `MeetingSessionController.finishMeeting` 在会议结束保存后调用导出，并在悬浮窗状态栏反馈导出的文件名；导出失败不影响录音保存结果。

## 文档同步

- `docs/storage.md`：更新停止录音的行为说明与 `MeetingExporter` 能力描述。

## 验证

- 本次改动的 `MeetingExporter`、`MeetingStore`、`MeetingSessionController` 类型/语法正确。
- 注意：整个 target 当前被一个无关的 Azure 语音模块编译错误（`AppSettings.azureSpeechRegion` 字段缺失，位于未跟踪的 `Sources/EasyMeeting/Speech/Azure/`）阻断，`swift build` 暂无法完整通过。该错误与本任务无关，待修复后再做完整端到端验证。
