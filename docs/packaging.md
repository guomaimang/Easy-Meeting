# 打包与分发

Easy Meeting 提供两条打包路径，按用途区分：

| 脚本 | 用途 | 构建模式 | Node | 签名 | 产物 |
| --- | --- | --- | --- | --- | --- |
| `scripts/package-app.sh` | 本机开发调试 | debug | 系统 Node | 不签名 | `.app` |
| `scripts/dist-app.sh` | 跨机器分发 | release | 内置 Node | Ad-hoc | `.app` + `.zip` |

两条路径打出的 `.app` 内部结构一致，差异只在构建模式、Node 来源和签名。

## 开发组装

```bash
zsh scripts/package-app.sh
```

产物：`.build/debug/Easy Meeting.app`。

debug 构建、使用本机系统 Node（Homebrew / nvm / 系统路径），不签名。仅供本机
快速验证 UI、存储和链路，不可拷到其他机器。

## 分发打包

```bash
zsh scripts/dist-app.sh
```

产物：

```text
.build/release/Easy Meeting.app
.build/release/Easy Meeting.zip
```

release 构建，把 Node 二进制内置进 app 包，做 Ad-hoc 签名。打出的 `.app` 自包含，
拷到任意 Apple Silicon Mac 即可运行，目标机器无需预装 Node。

### 自包含的原理

应用运行需要三个原生可执行文件，全部打进包内，且经核对都只依赖 macOS 系统库与
随系统自带的 Swift 运行时，无任何外部动态库：

- 主程序 `EasyMeeting`（Swift）。
- 火山链路 `easy-meeting-ast-helper`（Go，静态自包含）。
- Azure 链路所需的 `node` 二进制 + `AzureSpeechHelper`（纯 JS，无原生模块）。

因此目标机器不需要安装 Node.js，火山和 Azure 两条链路都开箱即用。

### 内置 Node 的查找优先级

`AzureHelperRuntime.nodeURL()` 按以下顺序定位 Node，命中即用：

1. 包内 `Contents/Helpers/node`（分发包走这里）。
2. 系统路径 `/opt/homebrew/bin`、`/usr/local/bin`、`/usr/bin` 与 `PATH`（开发态走这里）。

开发包内没有内置 Node，自动回退到系统 Node；分发包内有，则优先使用，两种场景互不影响。

## 产物结构

```text
Easy Meeting.app/
  Contents/
    Info.plist
    MacOS/
      EasyMeeting                       # 主程序
    Helpers/
      easy-meeting-ast-helper           # 火山 Go helper
      node                              # 内置 Node（仅分发包）
      AzureSpeechHelper/
        index.js
        azureTranslation.js
        package.json
        node_modules/                   # Azure SDK，纯 JS
```

## 代码签名说明

分发包使用 **Ad-hoc 签名**（`codesign -s -`），不依赖付费 Apple Developer 账号。
签名顺序为先内层后外层：先逐个签 `node`、`easy-meeting-ast-helper`、`EasyMeeting`，
最后整包签名。顺序颠倒会使外层签名失效。

Ad-hoc 签名未经 Apple 公证，目标机器首次打开会被 Gatekeeper 拦截。这是内部分发的
预期代价，接收方按下节做一次去隔离即可。

## 接收方首次打开

把 `Easy Meeting.zip` 传到目标 Apple Silicon Mac，解压后把 `Easy Meeting.app`
拖入 `/Applications`，然后任选一种方式放行：

**方式一：命令行去隔离（推荐）**

```bash
xattr -dr com.apple.quarantine "/Applications/Easy Meeting.app"
```

执行后直接双击即可打开。

**方式二：右键打开**

在 Finder 中右键点击 `Easy Meeting.app` → 打开 → 在弹窗中再次点击「打开」。
首次放行后，后续可直接双击。

## 权限

应用是菜单栏常驻应用（`LSUIElement`），启动后在顶部菜单栏显示 `Easy Meeting` 入口。
首次开始录音时，系统会请求麦克风权限，需在「系统设置 → 隐私与安全性 → 麦克风」中授权。

## 系统要求

- Apple Silicon（arm64）Mac。当前分发包不含 Intel 架构。
- macOS 14.0 及以上。
- 火山链路开箱即用；Azure 链路同样开箱即用（Node 已内置），仅需在设置页填入
  对应密钥。

## 验证清单

打包后建议核对：

```bash
APP=".build/release/Easy Meeting.app"

# 整包签名有效
codesign --verify --verbose "$APP"

# 内置 Node 只依赖系统库（无 nvm / homebrew 残留路径）
otool -L "$APP/Contents/Helpers/node"

# 三个可执行文件就位
ls "$APP/Contents/MacOS/EasyMeeting"
ls "$APP/Contents/Helpers/easy-meeting-ast-helper"
ls "$APP/Contents/Helpers/node"
ls "$APP/Contents/Helpers/AzureSpeechHelper/index.js"
```
