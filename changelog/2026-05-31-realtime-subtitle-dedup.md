# 实时字幕去重与提交时机

- 明确 AST 字幕处理规则：response 事件只刷新草稿行，最终字幕只提交一次。
- 调整 Go helper 的源文和译文 end 事件聚合逻辑，避免同一段字幕被追加两次。
- 在 Swift 展示缓冲和落库前增加文本指纹兜底，防止重复 final 事件造成重复显示或重复保存。
- 修正源文新分段重置 final 状态导致旧译文被再次提交的问题，最终提交只允许由译文 end 触发。
- 对齐 AST 参考实现的启动音频格式，握手使用 `format=wav`、`codec=raw`，实时音频分片继续发送 16k PCM。
- helper 等待 `SessionStarted` 后再发送音频，并按 80ms 切分 PCM，降低服务端攒包造成的字幕延迟。
- 对齐 reference 项目的事件模型，helper 分别输出原文和译文事件，Swift 分别维护两侧草稿，避免合并 subtitle 吞掉流式语义。
