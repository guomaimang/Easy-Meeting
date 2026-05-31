# Azure helper 进程回收对齐 reference 实现

## 背景

上次为解决「主 App 消失后 helper 子进程 CPU 飙到 100%」，给 helper 加了
Worker 线程看门狗（`parentWatchdog.js`）：独立线程轮询父进程 PPID，父进程一消失
就对本进程发 SIGKILL。

复查 reference/Meeting-Copilot 的 Azure 回收实现后确认：看门狗是本项目自创的、
参考里并不存在的机制。参考 `azureSpeechService.js` 的回收链是
`stopContinuousRecognitionAsync → recognizer.close() → 停音频流`，由宿主驱动，
没有任何进程轮询或 SIGKILL 自杀。

追 SDK 源码（`ServiceRecognizerBase.receiveMessage`）也证实：`recognizer.close()`
会置位 `privIsDisposed`，循环开头 `if (this.privIsDisposed) return;` 即从源头终止，
比从外部强杀干净。原文档「read 读空即递归→忙循环」的成因描述与源码对不上。

## 变更

- 删除 `Helpers/AzureSpeechHelper/parentWatchdog.js`（自创看门狗，已无必要）。
- `index.js`：移除 Worker 看门狗及 `worker_threads`/`path` 依赖；保留 stdin EOF /
  SIGTERM / SIGINT 触发 `shutdownAndExit` → `session.finish()` → 强制退出。
- `azureTranslation.js` 的 `finish()` 回收链已与参考一致，无需改动。
- Swift 侧 `stop()` 的 `terminate → SIGKILL` 兜底保留（子进程场景下「宿主销毁」的
  等价物），仅同步注释措辞。
- `docs/azure-speech.md`：重写「进程生命周期与回收」章节，以 `recognizer.close()`
  为回收核心说明，移除看门狗与不准确的「忙循环烧 CPU」成因描述。

## 设计依据

父进程无论正常退出还是被 SIGKILL，内核都会关闭其持有的 stdin 管道写端，子进程
必收到 EOF —— 这是 macOS 上最可靠的「父进程没了」探测，不需要独立线程轮询 PPID。
看门狗想兜的「主线程忙循环饿死 EOF」场景，经源码核查并不成立。

## 验证

- `node --check` 通过（index.js / azureTranslation.js）。
- `swift build` 通过。
</content>
</invoke>
