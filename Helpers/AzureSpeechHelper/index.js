'use strict'

/**
 * Azure 流式翻译 helper 入口
 * 通过 stdin/stdout JSON Lines 与 Swift 主 App 通信，
 * 协议与火山 Go helper 一致：start / audio / finish 命令，
 * status / source / translation / error 事件。
 */
const readline = require('readline')
const { AzureTranslationSession } = require('./azureTranslation')

/** 向 Swift 输出一条领域事件（单行 JSON + 换行） */
function emit(event) {
  process.stdout.write(`${JSON.stringify(event)}\n`)
}

/** 调试日志走 stderr，不污染事件流 */
function log(message) {
  process.stderr.write(`${message}\n`)
}

const session = new AzureTranslationSession(emit, log)

function handleCommand(cmd) {
  switch (cmd.type) {
    case 'start':
      session.start(cmd)
      break
    case 'audio': {
      const buffer = Buffer.from(cmd.dataBase64 || '', 'base64')
      if (buffer.length > 0) {
        session.sendAudio(buffer)
      }
      break
    }
    case 'finish':
    case 'stop':
      session.finish()
      break
    default:
      emit({ type: 'error', message: `unknown command: ${cmd.type}` })
  }
}

const rl = readline.createInterface({ input: process.stdin })

rl.on('line', (line) => {
  const trimmed = line.trim()
  if (!trimmed) {
    return
  }
  let cmd
  try {
    cmd = JSON.parse(trimmed)
  } catch (err) {
    emit({ type: 'error', message: `invalid command: ${err.message}` })
    return
  }
  try {
    handleCommand(cmd)
  } catch (err) {
    emit({ type: 'error', message: err.message })
  }
})

/**
 * 退出回收：失去父进程时停掉识别器并退出。
 * 对齐 reference/Meeting-Copilot 的 stopRecognition → close 回收链：
 * recognizer.close() 会置位 SDK 的 privIsDisposed，receiveMessage 开头即 return，
 * 从源头掐断接收循环，避免残留会话空烧 CPU。详见 docs/azure-speech.md。
 */
let exiting = false
function shutdownAndExit(code) {
  if (exiting) {
    return
  }
  exiting = true
  try {
    session.finish()
  } catch (_) {
    /* ignore */
  }
  // 给 finish 的异步收尾（stopContinuousRecognitionAsync → close）留点时间，
  // 但无论如何强制退出，不让 SDK 事件循环吊住进程。unref 不阻止正常退出。
  setTimeout(() => process.exit(code), 1000).unref()
}

// 父进程消失的信号来源（macOS 上最可靠的「父进程没了」探测）：
// 父进程无论正常退出还是被 SIGKILL，内核都会关闭它持有的 stdin 管道写端，
// 子进程随即收到 EOF（readline close / stdin end），触发回收并退出。
rl.on('close', () => shutdownAndExit(0))
process.stdin.on('end', () => shutdownAndExit(0))

// Swift 侧 stop() 会先发 SIGTERM，收到即回收退出；SIGINT 同理。
process.on('SIGTERM', () => shutdownAndExit(0))
process.on('SIGINT', () => shutdownAndExit(0))

process.on('uncaughtException', (err) => {
  emit({ type: 'error', message: `uncaught: ${err.message}` })
})
