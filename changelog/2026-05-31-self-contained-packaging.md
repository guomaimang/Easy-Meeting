# 自包含分发打包（内置 Node + Ad-hoc 签名）

## 背景

此前只有 `scripts/package-app.sh` 一条开发组装路径：debug 构建、依赖目标机器的系统
Node、不签名。直接拷到其他 Mac 会踩三个坑：未签名被 Gatekeeper 拦截、Azure 链路
依赖系统 Node、产物为 debug。需要一条能跨机器开箱即用的分发路径。

## 变更

### 新增分发打包脚本 scripts/dist-app.sh

- release 构建主程序，Go helper 用 `-ldflags "-s -w"` 瘦身。
- 把系统 `node` 二进制内置进 app 包（已核对仅依赖 macOS 系统库，无 nvm/homebrew
  残留路径），目标机器无需预装 Node。
- 校验内置 node 为 arm64，架构不符直接报错退出。
- Ad-hoc 签名（`codesign -s -`）：先逐个签 `node`、`easy-meeting-ast-helper`、
  `EasyMeeting`，再整包签名；不用 `--deep`。
- 产出 `Easy Meeting.app` 与 `ditto` 压缩的 `Easy Meeting.zip`，并打印接收方去隔离命令。

### Azure helper 改放 Contents/Resources/

- 根因：`node_modules` 内含 39 个 `package.json`，置于 `Contents/Helpers/` 会被
  codesign 递归扫描误判为嵌套 bundle，导致整包签名报 "code object is not signed
  at all"。
- 改放 `Contents/Resources/AzureSpeechHelper/`，codesign 当纯资源处理，不递归签名。
- `AzureHelperRuntime.candidateURLs()` 新增 `Contents/Resources/` 候选（最高优先级），
  保留 `Contents/Helpers/` 候选兼容开发组装包。

### 内置 Node 查找

- `AzureHelperRuntime.nodeURL()` 新增包内 `Contents/Helpers/node` 候选，优先级高于
  系统 Node。分发包优先用内置 Node；开发包内无此文件，自动回退系统 Node，两不冲突。

### package-app.sh 保持不变

- 开发组装脚本维持原样：debug、系统 Node、不签名，供本机快速验证。

## 验证

- `zsh scripts/dist-app.sh` 成功产出已签名 `.app`（144MB）+ `.zip`（45MB）。
- `codesign --verify --deep` 通过，满足 Designated Requirement。
- `otool -L node` 确认仅系统库依赖。
- 冒烟测试：app 进程稳定存活，内置 node 可独立执行（v24.15.0）。

## 文档

- 新增 `docs/packaging.md`：两条打包路径对比、自包含原理、签名取舍、接收方首次打开
  指南、验证清单。
- `README.md` 本地运行小节补充分发打包流程与去隔离命令。
