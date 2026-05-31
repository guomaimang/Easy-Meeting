# Azure helper 开发路径修复

- 修复开发运行时 Azure helper 只按当前目录查找的问题，改为从可执行目录和当前工作目录逐级向上定位 `Helpers/AzureSpeechHelper/index.js`。
- 菜单栏状态项标题从 `Easy Meeting` 缩短为 `EM`，保留完整 tooltip，并使用固定宽度避免标题区域过窄导致不可见。
- 修复悬浮窗文本更新时同步强制布局可能导致启动后 CPU 飙高的问题，改为下一轮主队列滚动到底。
