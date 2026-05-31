# 麦克风热切换

会议进行中随时更换麦克风，识别会话、实时字幕、录音文件三条线全部不中断，
只丢失切换瞬间几十毫秒音频。

## 为什么能做到「无感知」

音频链路存在一个解耦点（`MeetingSessionController`）：

```
AudioRecorder ──AudioFrame──▶ onAudioFrame ──▶ SpeechClient（续着线的识别会话）
      │
      └──▶ AVAssetWriter（录音文件）
```

`SpeechClient` 只消费 `AudioFrame` 流，不关心这帧来自哪个麦克风。
因此只要换麦时不触碰 `SpeechClient`、`AVAssetWriter` 与字幕缓冲，下游就完全无感知：
识别会话不重连、字幕不清空、录音文件连续写入。换掉的只是「水龙头」，水管下游一概不动。

## 实现：热插拔 AVCaptureSession 的 input

`AudioRecorder.switchDevice(to:completion:)` 在 `captureQueue`（与音频帧 `append` 同一串行队列，
天然 FIFO，杜绝「切换中又来新帧」的竞态）上执行：

```
1. 先用新设备创建 AVCaptureDeviceInput（失败直接抛错，session 原地不动）
2. session.beginConfiguration()
3. removeInput(旧 input)
4. canAddInput(新 input) 成立 → addInput(新)
   不成立 → 回滚：重新 addInput(旧)，抛 cannotAddInput
5. session.commitConfiguration()
```

全程 `output`、采集 delegate、`onAudioFrame`、`AVAssetWriter`、`writerInput` 均原地不动。

## 为什么录音文件（AVAssetWriter）扛得住

- **格式不变**：`output.audioSettings` 已把采集格式强制统一为 16kHz / 单声道 / 16bit
  （见 `AudioStreamFormat`），换麦后吐出的帧格式不变，writer 不会因格式突变报
  `Cannot Encode Media`。
- **时间戳单调**：同一个 `AVCaptureSession` 共用 host clock，换 input 不会让 PTS 回退，
  `writerInput.append` 不会因时间戳倒流报错。

## 调用链

```
浮窗顶栏麦克风下拉 / 菜单栏麦克风项
        → StatusBarController.onSelectDevice
        → MeetingSessionController.switchMicrophone(to:)
            ├─ 录音中：audioRecorder.switchDevice + 更新 selectedDeviceID（热切，下游不动）
            └─ 未录音：仅更新 audioDeviceManager.selectedDeviceID（下次开始录音生效）
```

## 边界

- 切换失败（设备拔出、被占用）时回滚到原 input，录音继续，向用户提示失败原因。
- 切换瞬间的极短静音（几十毫秒）属预期行为，流式识别可容忍，体感上是「卡了半个字」。
