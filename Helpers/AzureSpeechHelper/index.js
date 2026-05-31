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

rl.on('close', () => {
  session.finish()
})

process.on('uncaughtException', (err) => {
  emit({ type: 'error', message: `uncaught: ${err.message}` })
})
