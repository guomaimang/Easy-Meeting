# 2026-05-31 火山 AST 客户端骨架

## 变更

- 新增语音客户端工厂，根据设置选择 Mock 或火山引擎。
- 新增火山同声传译 2.0 WebSocket 客户端骨架。
- 火山客户端从 Keychain/UserDefaults 读取 API Key 和 Resource ID。
- 火山客户端支持建连、接收消息和错误状态反馈。
- README 补充运行、数据目录、导出和火山接入状态。

## 备注

- AST 业务消息是 protobuf，当前还没有接入官方 proto codec。
- 真实实时字幕还需要音频帧转换和 protobuf 编解码。
