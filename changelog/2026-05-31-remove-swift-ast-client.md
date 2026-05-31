# 2026-05-31 移除 Swift AST 客户端

## 变更

- 删除旧的 Swift 原生火山 AST 客户端路线。
- 移除 SwiftProtobuf 运行时依赖和构建期 proto 生成配置。
- 文档改为 Go helper 单一路线，Swift 主 App 只通过 JSON Lines 处理领域事件。
- 新增随 App 打包的 `easy-meeting-ast-helper`，复用 `ref/_extracted/go/ast_go` 的官方 AST proto 和协议依赖。

## 验证

- `go build -C Helpers/VolcengineASTHelper -o ../../.build/debug/easy-meeting-ast-helper` 通过。
- `swift build` 通过。
- `zsh scripts/package-app.sh` 通过。
