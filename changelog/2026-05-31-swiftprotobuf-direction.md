# 2026-05-31 SwiftProtobuf 方案

## 变更

- 明确火山 AST protobuf 编解码采用 SwiftProtobuf，不手写二进制 codec。
- SwiftPM 引入 `apple/swift-protobuf` 的 `SwiftProtobuf` 运行时依赖，并固定版本保证构建可重复。
- 同步 README、技术栈、产品计划和火山语音文档。

## 验证

- 待执行 `swift build`。
