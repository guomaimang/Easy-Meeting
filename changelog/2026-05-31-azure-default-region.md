# 预设 Azure 默认区域

- Azure Region 默认预设为 `eastasia`，用户只填写 Azure 语音密钥即可启动。
- 读取历史配置、保存设置和启动 Azure helper 时都会把空 Region 归一为默认值。
- 配置检查不再因为 Region 为空阻断，只保留 Azure 语音密钥、Node 和 helper 脚本检查。
- 同步更新 Azure 接入、技术栈和设置中心文档。
