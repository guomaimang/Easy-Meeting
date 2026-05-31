# 修复 Azure Helper 父目录遍历死循环导致应用启动卡死

## 问题

应用启动后主线程 CPU 占满（实测 98%），悬浮窗与菜单栏均不显示，应用无响应。

## 根因

`AzureHelperRuntime.helperCandidates(underAncestorsOf:)` 逐级向上遍历父目录寻找
`Helpers` 目录时，使用 `while true` 循环，仅靠 `parent.path == directory.path`
字符串相等作为终止条件。`deletingLastPathComponent()` 在某些路径形态下产生的 URL
经 `.path` 比较无法收敛，导致循环永不退出，主线程被占满。

调用链：`applicationDidFinishLaunching` → Azure 配置诊断 → `scriptURL()` →
`candidateURLs()` → `helperCandidates(underAncestorsOf:)`，因此应用启动即卡死。

## 修复

改用路径组件数量 `directory.pathComponents.count > 1` 作为硬性终止条件。
每轮 `deletingLastPathComponent` 必定减少一个路径组件，保证一定收敛到根目录后退出，
不再依赖脆弱的字符串相等比较。

## 验证

- 对空串、相对路径、`/`、带尾斜杠目录、当前工作目录等边界输入均能正常收敛终止。
- 重新编译运行：CPU 由 98% 降至 0%，进程进入空闲事件循环，悬浮窗正常显示。
