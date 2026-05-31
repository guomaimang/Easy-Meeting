import Foundation

enum SpeechLanguage: String, CaseIterable {
    case zh
    case en
    case de
    case fr
    case es
    case id
    case ja
    case pt
    case ko
    case tr
    case ms
    case nl
    case ro
    case pl
    case cs
    case ar
    case th
    case vi
    case ru
    case it
    case yueCN = "yue-CN"
    case shCN = "sh-CN"
    case zhen

    static let sourceCases = allCases
    static let targetCases = allCases.filter(\.canBeTarget)

    var title: String {
        switch self {
        case .zh: "中文"
        case .en: "英文"
        case .de: "德语"
        case .fr: "法语"
        case .es: "西班牙语"
        case .id: "印尼语"
        case .ja: "日语"
        case .pt: "葡萄牙语"
        case .ko: "韩语"
        case .tr: "土耳其语"
        case .ms: "马来语"
        case .nl: "荷兰语"
        case .ro: "罗马尼亚语"
        case .pl: "波兰语"
        case .cs: "捷克语"
        case .ar: "阿拉伯语"
        case .th: "泰语"
        case .vi: "越南语"
        case .ru: "俄语"
        case .it: "意大利语"
        case .yueCN: "粤语"
        case .shCN: "上海话"
        case .zhen: "中英反转互译"
        }
    }

    var menuTitle: String {
        "\(title)（\(rawValue)）"
    }

    var canBeTarget: Bool {
        self != .yueCN && self != .shCN
    }

    var isChineseOrEnglish: Bool {
        self == .zh || self == .en || self == .zhen
    }
}

struct SpeechTranslationConfiguration {
    let sourceLanguage: SpeechLanguage
    let targetLanguage: SpeechLanguage

    var title: String {
        "\(sourceLanguage.title)转\(targetLanguage.title)"
    }

    var detail: String {
        "\(sourceLanguage.rawValue) → \(targetLanguage.rawValue)"
    }

    var isValidForS2T: Bool {
        if sourceLanguage == .zhen || targetLanguage == .zhen {
            return sourceLanguage == .zhen && targetLanguage == .zhen
        }
        return sourceLanguage.isChineseOrEnglish || targetLanguage.isChineseOrEnglish
    }
}
