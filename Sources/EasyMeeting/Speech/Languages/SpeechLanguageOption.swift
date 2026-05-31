import Foundation

/// 语音服务的一个语言选项：代号 + 中文显示名。
///
/// 不同服务商、甚至同一服务商的源/目标，代号体系都不同：
/// - Azure 识别（源）：BCP-47 带地区，如 `en-US`、`zh-CN`、`yue-CN`。
/// - Azure 翻译（目标）：简码/脚本码，如 `zh-Hans`、`en`、`ja`。
/// - 火山 AST：源/目标共用，如 `zh`、`en`、`zhen`。
///
/// 因此语言表按服务商分开维护，UI 下拉框直接产出当前服务商的原生代号。
struct SpeechLanguageOption: Equatable {
    let code: String
    let label: String

    /// 下拉框显示文本：中文名（代号）。
    var menuTitle: String {
        "\(label)（\(code)）"
    }
}
