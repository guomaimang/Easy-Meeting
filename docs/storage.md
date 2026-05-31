# 本地存储方案

## 结论

采用 SQLite + 本地文件系统的混合方案。

- SQLite 保存会议索引、分段文本、翻译、时间戳和导出状态。
- 用户文稿目录保存录音、转录、导出文件和大体积附件，保证用户能在 Finder 中直接触达。
- Keychain 保存 API Key、Secret、Token 等敏感配置。

## 为什么不用单一方案

只用文件：

- 查询历史记录、搜索、分页、过滤会越来越慢。
- 分段转录更新容易产生并发和一致性问题。

只用数据库：

- 录音文件体积大，不适合直接存成 BLOB。
- 导出、备份、清理和用户访问都不方便。

Core Data：

- 适合复杂对象图，但本项目以日志型数据、分段文本和历史查询为主。
- SQLite 更透明，便于迁移、调试和性能控制。

## 目录结构

```text
~/Library/Application Support/Easy Meeting/
  easy_meeting.sqlite

~/Documents/Easy Meeting/
  Meetings/
    <yyyy-MM-dd_HHmmss>_<meeting_id>/
      audio.m4a
      metadata.json
      transcript.txt
      transcript-source.txt
      transcript-translation.txt
      transcript.md
      transcript.srt
      transcript.json
```

`Application Support` 只保存应用内部数据库。会议产物默认放入用户文稿目录，
避免录音和文本藏在用户不容易打开的位置。

## 数据表

### meetings

| 字段 | 说明 |
|---|---|
| id | 本地 UUID |
| title | 会议标题 |
| mode | 翻译模式 |
| source_language | 源语言 |
| target_language | 目标语言 |
| started_at | 开始时间 |
| ended_at | 结束时间 |
| audio_path | 录音相对路径 |
| created_at | 创建时间 |
| updated_at | 更新时间 |

### transcript_segments

| 字段 | 说明 |
|---|---|
| id | 本地 UUID |
| meeting_id | 会议 ID |
| start_ms | 分段开始时间 |
| end_ms | 分段结束时间 |
| source_text | 原文 |
| translated_text | 译文 |
| source_language | 源语言 |
| target_language | 目标语言 |
| is_final | 是否最终结果 |
| vendor_payload | 服务商原始事件 JSON |
| created_at | 创建时间 |

### exports

| 字段 | 说明 |
|---|---|
| id | 本地 UUID |
| meeting_id | 会议 ID |
| format | 导出格式 |
| path | 导出相对路径 |
| created_at | 创建时间 |

## 当前实现状态

- 已创建 `meetings` 表。
- 已创建 `transcript_segments` 表。
- 开始录音时写入会议记录。
- 停止录音时更新结束时间，并自动导出原文与译文两份 markdown（`transcript-source.md`、`transcript-translation.md`）到会议目录。异常退出（崩溃/强制退出）不会走停止流程，因此不触发导出。
- 如果用户在音频采集尚未产生首帧时立即停止录音，停止流程仍视为成功：会议记录正常收口，转录导出照常尝试，录音文件可能为空或不存在。
- 录音文件、原文文本、译文文本和 `metadata.json` 已保存到用户文稿目录下的会议目录。
- 单次会议产物按最长约 8 小时设计；当前录音达到 4 小时时由会话控制器自动停止并走正常保存、导出流程。
- 菜单栏「最近会议」直接在 Finder 中打开会议根目录（用户文稿目录下的 `Easy Meeting/Meetings`），不再展开会议列表。
- `MeetingExporter` 提供原文/译文 markdown 导出，以及保留的 `transcript.srt`、`transcript.json` 全量导出能力。
- `exports` 表会在导出功能落地时创建。

## 索引

- `meetings(started_at)`
- `meetings(updated_at)`
- `transcript_segments(meeting_id, start_ms)`
- `transcript_segments(meeting_id, is_final)`
- `exports(meeting_id, format)`

## 写入策略

- 音频流边录边写入临时文件，会议结束后原子改名。
- 实时转录分段先写临时结果，再用最终结果覆盖同一分段。
- 数据库写入放在后台串行队列，避免 UI 阻塞。
- 每个会议一个目录，删除会议时可完整清理。

## 后续扩展

- 全文搜索：接入 SQLite FTS5。
- 云同步：在会议目录粒度做同步。
- 加密：数据库和录音文件增加本地加密层。
- 摘要：新增 `meeting_summaries` 表，不污染转录分段表。
