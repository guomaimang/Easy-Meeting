# 对齐两条打包路径的运行时形态

## 背景

此前 `package-app.sh`（开发组装）与 `dist-app.sh`（分发）产物结构并不一致：

- 开发包：使用系统 Node、不签名、Azure helper 放在 `Contents/Helpers/AzureSpeechHelper`。
- 分发包：内置 Node、Ad-hoc 签名、Azure helper 放在 `Contents/Resources/AzureSpeechHelper`。

两套形态意味着开发态和分发态可能出现行为分裂——例如在 dev 上跑通的链路换到分发包后
因签名或路径差异翻车，反过来也成立。

## 变更

让 debug 与 release 的产物结构、Node 来源、签名方式完全一致，仅保留必要差异
（编译模式、是否打 zip）。

- `scripts/package-app.sh`：重写，加入内置 Node、Ad-hoc 签名，Azure helper 改放
  `Contents/Resources/`，与 `dist-app.sh` 对齐。仍走 `swift build -c debug`，不打 zip。
- `Sources/EasyMeeting/Speech/Azure/AzureHelperRuntime.swift`：删除已废弃的
  `Contents/Helpers/AzureSpeechHelper` 候选路径（debug 也走 Resources 后这条已死，
  按"删除死代码"原则清理）。`swift run` 直接跑源码二进制时仍可经父目录回溯到
  `Helpers/AzureSpeechHelper/index.js`，开发体验不受影响。
- `docs/packaging.md`：更新对照表与产物结构说明，明确两条路径仅在构建模式与
  是否打 zip 上有差异。

## 影响

- `.app` 启动后无论 debug 还是 release，都使用包内 `Contents/Helpers/node`，
  不再回退系统 Node。
- 开发包不再"跑得过但分发包翻车"或反之的风险。
- 仅 `swift run` 等不经过打包脚本的场景仍依赖系统 Node。
