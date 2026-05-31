'use strict'

/**
 * Azure 流式翻译会话
 * 移植自 reference/Meeting-Copilot 的 azureSpeechRecognizers.js，
 * 音频输入从浏览器 MediaStream 改为 Node PushAudioInputStream。
 */
const SpeechSDK = require('microsoft-cognitiveservices-speech-sdk')

/** 创建翻译配置：设源识别语言并添加目标翻译语言 */
function createTranslationConfig(speechKey, region, sourceLanguage, targetLanguage) {
  const config = SpeechSDK.SpeechTranslationConfig.fromSubscription(speechKey, region)
  config.speechRecognitionLanguage = sourceLanguage
  config.addTargetLanguage(targetLanguage)
  return config
}

/** 创建 16kHz/16bit/单声道 的推流音频输入 */
function createPushStreamConfig() {
  const format = SpeechSDK.AudioStreamFormat.getWaveFormatPCM(16000, 16, 1)
  const pushStream = SpeechSDK.AudioInputStream.createPushStream(format)
  const audioConfig = SpeechSDK.AudioConfig.fromStreamInput(pushStream)
  return { pushStream, audioConfig }
}

class AzureTranslationSession {
  /** @param {(event: object) => void} emit 输出领域事件的回调 */
  constructor(emit, log) {
    this.emit = emit
    this.log = log
    this.recognizer = null
    this.pushStream = null
    this.targetLanguage = 'zh-Hans'
    this.finalEmitted = false
  }

  start(cmd) {
    if (this.recognizer) {
      throw new Error('session already started')
    }
    const sourceLanguage = cmd.sourceLanguage || 'en-US'
    this.targetLanguage = cmd.targetLanguage || 'zh-Hans'

    const config = createTranslationConfig(cmd.speechKey, cmd.region, sourceLanguage, this.targetLanguage)
    const { pushStream, audioConfig } = createPushStreamConfig()
    this.pushStream = pushStream
    this.finalEmitted = false

    const recognizer = new SpeechSDK.TranslationRecognizer(config, audioConfig)
    this.recognizer = recognizer
    this.bindEvents(recognizer, this.targetLanguage)

    recognizer.startContinuousRecognitionAsync(
      () => this.emit({ type: 'status', message: 'session_started' }),
      (err) => this.emit({ type: 'error', message: `start failed: ${err}` })
    )
  }

  /** 写入一帧解码后的 PCM 数据 */
  sendAudio(buffer) {
    if (!this.pushStream) {
      throw new Error('session not started')
    }
    // SDK 需要 ArrayBuffer，从 Node Buffer 切出对应视图
    this.pushStream.write(buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength))
  }

  finish() {
    if (!this.recognizer) {
      return
    }
    const recognizer = this.recognizer
    this.recognizer = null
    if (this.pushStream) {
      try { this.pushStream.close() } catch (_) { /* ignore */ }
      this.pushStream = null
    }
    recognizer.stopContinuousRecognitionAsync(
      () => { try { recognizer.close() } catch (_) { /* ignore */ } this.emit({ type: 'status', message: 'session_finished' }) },
      () => { try { recognizer.close() } catch (_) { /* ignore */ } }
    )
  }

  bindEvents(recognizer, lang) {
    recognizer.recognizing = (_, event) => {
      const sourceText = event.result.text
      if (sourceText) {
        this.emit({ type: 'source', sourceText, isInterim: true })
      }
      const translation = event.result.translations && event.result.translations.get(lang)
      if (translation) {
        this.emit({ type: 'translation', sourceText, translatedText: translation, isInterim: true })
      }
    }

    recognizer.recognized = (_, event) => {
      const reason = event.result.reason
      if (reason === SpeechSDK.ResultReason.TranslatedSpeech) {
        const sourceText = event.result.text
        const translation = event.result.translations && event.result.translations.get(lang)
        if (sourceText) {
          this.emit({ type: 'source_end', sourceText, isInterim: false })
        }
        if (translation) {
          this.emit({ type: 'translation_end', sourceText, translatedText: translation, isFinal: true })
        }
      } else if (reason === SpeechSDK.ResultReason.NoMatch) {
        this.log(`no match: ${event.result.text}`)
      }
    }

    recognizer.canceled = (_, event) => {
      const detail = event.errorDetails || event.reason
      this.log(`canceled: code=${event.errorCode} reason=${event.reason} detail=${detail}`)
      this.emit({ type: 'error', message: `翻译取消: ${detail}` })
    }

    recognizer.sessionStopped = () => {
      this.emit({ type: 'status', message: 'session_stopped' })
    }
  }
}

module.exports = { AzureTranslationSession }
