# 2026-05-31 AST protobuf 链路

## 变更

- 接入 SwiftProtobuf 构建插件，按火山 AST proto 在构建时生成 Swift 类型。
- 新增火山 AST 协议适配层，编码 `StartSession`、`TaskRequest` 和 `FinishSession`。
- 火山客户端开始发送真实 protobuf 消息，并解析下行 protobuf 响应为领域事件。
- 更新完整 APP 验收路线和火山语音接入状态。

## 验证

- `swift build` 通过。
- `zsh scripts/package-app.sh` 通过。
