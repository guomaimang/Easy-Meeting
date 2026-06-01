# 打包与分发

Easy Meeting 提供两条打包路径，构建产物结构与运行依赖完全一致，仅在构建模式
（debug / release）和是否额外打 zip 上有差异：

| 脚本 | 用途 | 构建模式 | Node | 签名 | 产物 |
| --- | --- | --- | --- | --- | --- |
| `scripts/package-app.sh` | 本机开发组装 | debug | 内置 Node | Ad-hoc | `.app` |
| `scripts/dist-app.sh` | 跨机器分发 | release | 内置 Node | Ad-hoc | `.app` + `.zip` |

两条路径都把 Node 二进制内置进 `.app`，都做 Ad-hoc 签名，Azure helper 都放在
`Contents/Resources/`。这样开发态和分发态行为一致，避免出现「dev 跑得通、分发跑
不通」或反之的环境分裂问题。

## 开发组装

```bash
zsh scripts/package-app.sh
```

产物：`.build/debug/Easy Meeting.app`。

debug 构建，内置 Node 与 Ad-hoc 签名同 release 完全一致，仅在编译优化级别上不同，
便于本机调试。

## 分发打包

```bash
zsh scripts/dist-app.sh
```

产物：

```text
.build/release/Easy Meeting.app
.build/release/Easy Meeting.zip
```

release 构建，二进制经 `-ldflags "-s -w"` 瘦身，并额外打一个 zip 便于传输。

### 自包含的原理

应用运行需要三个原生可执行文件，全部打进包内，且经核对都只依赖 macOS 系统库与
随系统自带的 Swift 运行时，无任何外部动态库：

- 主程序 `EasyMeeting`（Swift）。
- 火山链路 `easy-meeting-ast-helper`（Go，静态自包含）。
- Azure 链路所需的 `node` 二进制 + `AzureSpeechHelper`（纯 JS，无原生模块）。

因此目标机器不需要安装 Node.js，火山和 Azure 两条链路都开箱即用。

### 内置 Node 的查找优先级

`AzureHelperRuntime.nodeURL()` 按以下顺序定位 Node，命中即用：

1. 包内 `Contents/Helpers/node`（`.app` 启动走这里，开发与分发一致）。
2. 系统路径 `/opt/homebrew/bin`、`/usr/local/bin`、`/usr/bin` 与 `PATH`
   （`swift run` 直接跑源码二进制时走这里）。

只要从 `.app` 启动，无论 debug 还是 release，都使用包内 Node；只有不经过打包
脚本、直接 `swift run` 时才会回退系统 Node。

## 产物结构

```text
Easy Meeting.app/
  Contents/
    Info.plist
    MacOS/
      EasyMeeting                       # 主程序
    Helpers/
      easy-meeting-ast-helper           # 火山 Go helper
      node                              # 内置 Node
    Resources/
      AppIcon.icns                      # 应用图标
      AzureSpeechHelper/                # Azure helper（纯资源，避免 codesign 误判）
        index.js
        azureTranslation.js
        package.json
        node_modules/                   # Azure SDK，纯 JS
```

> Azure helper 放在 `Contents/Resources/` 而非 `Contents/Helpers/`：其 `node_modules`
> 内含大量 `package.json`，若置于会被 codesign 递归扫描的位置，会被误判为嵌套
> bundle 而导致整包签名失败。`Resources/` 是 codesign 认可的纯资源目录，不递归当
> 代码处理。

## 代码签名说明

两条路径都使用 **Ad-hoc 签名**（`codesign -s -`），不依赖付费 Apple Developer 账号。
签名顺序为先内层后外层：先逐个签 `node`、`easy-meeting-ast-helper`、`EasyMeeting`，
最后整包签名。顺序颠倒会使外层签名失效。

不使用 `--deep`：内层三个 Mach-O 已逐个显式签名，Azure helper 的 `node_modules`
是纯资源，由外层签名作为资源封入。`--deep` 会误把资源当代码递归处理而报错。

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

## 应用图标

图标源为根目录的 `logo.png`（青绿对话气泡），生成流程已固化为脚本：

```bash
zsh scripts/build-icon.sh            # 默认用 logo.png
zsh scripts/build-icon.sh other.png  # 也可指定其他源图
```

流程：`scripts/make-icon.swift` 用 CoreGraphics 合成 1024 底图（白色圆角底板 +
logo 居中），再经 `sips` 生成各尺寸、`iconutil` 打包为 `Packaging/AppIcon.icns`。

两个打包脚本都会把 `AppIcon.icns` 复制到 `Contents/Resources/`，`Info.plist` 通过
`CFBundleIconFile` 声明。换 logo 后重跑 `build-icon.sh` 再打包即可。

> 若替换图标后 Finder 仍显示旧图，是 LaunchServices 缓存所致。重新打包并执行
> `lsregister -f "<path>/Easy Meeting.app"` 可刷新。

## 菜单栏与权限

应用以 macOS agent 形态运行：`Info.plist` 声明 `LSUIElement=YES`，入口代码再
`setActivationPolicy(.accessory)` 兜底。两者一致地确保应用**无 Dock 图标、不占据屏幕
顶部系统菜单栏**，所有用户入口集中在屏幕右上角状态栏的 `EM` 图标里（设置、显示/隐藏
悬浮窗、开始/停止录音、翻译模式、麦克风、最近会议、退出）。

> 注意：曾尝试只删除 `LSUIElement` 来让顶部菜单栏显示，结果与 `.accessory` 时序冲突，
> 反而导致状态栏 `EM` 图标在 `.app` 启动后不出现。`.accessory` 与"顶部菜单可见"在
> macOS 上互斥，本项目选择前者。`AppDelegate.setupMainMenu()` 构建的 `Easy Meeting`
> 与「编辑」菜单仅用于注册 `Cmd+C/V/A` 等文本快捷键的响应链，不会显示在屏幕顶部。

首次开始录音时，系统会请求麦克风权限，需在「系统设置 → 隐私与安全性 → 麦克风」中授权。

## 系统要求

- Apple Silicon（arm64）Mac。当前分发包不含 Intel 架构。
- macOS 14.0 及以上。
- 火山链路开箱即用；Azure 链路同样开箱即用（Node 已内置），仅需在设置页填入
  对应密钥。

## 验证清单

打包后建议核对：

```bash
APP=".build/release/Easy Meeting.app"   # debug 时换成 .build/debug/...

# 整包签名有效
codesign --verify --verbose "$APP"

# 内置 Node 只依赖系统库（无 nvm / homebrew 残留路径）
otool -L "$APP/Contents/Helpers/node"

# 三个可执行文件就位
ls "$APP/Contents/MacOS/EasyMeeting"
ls "$APP/Contents/Helpers/easy-meeting-ast-helper"
ls "$APP/Contents/Helpers/node"
ls "$APP/Contents/Resources/AzureSpeechHelper/index.js"
```
