# 2026-05-31 用户可见会议文件

## 变更

- 将新会议的录音和文本默认保存到 `~/Documents/Easy Meeting/Meetings/`。
- 保留 SQLite 数据库在 `~/Library/Application Support/Easy Meeting/`。
- 实时转录追加时新增 `transcript-source.txt` 和 `transcript-translation.txt`。
- 同步更新 README、技术栈和本地存储文档。

## 验证

- `swift build` 通过。
- `zsh scripts/package-app.sh` 通过，生成 `.build/debug/Easy Meeting.app`。
- `swift test` 可执行到构建完成，但当前仓库没有 `Tests` target。
- 未发现独立 E2E 或 Lint 脚本。
