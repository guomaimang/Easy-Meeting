# 修复 app 包启动菜单栏显示

## 变更

- 从 `Packaging/Info.plist` 移除 `LSUIElement`，避免 `.app` 启动时被 LaunchServices
  当作 agent 应用压掉标准应用菜单栏。
- 保留入口代码的 `.accessory` activation policy，使应用仍按无 Dock、状态栏常驻方式运行。
- 同步更新打包文档，说明 `.app` 菜单栏行为与右上角 `EM` 状态栏入口。

## 验证

- 重新组装 debug `.app` 后检查包内 `Info.plist` 不再包含 `LSUIElement`。
- 执行 lint 收尾，确认 Swift 代码可编译。
