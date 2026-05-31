import Foundation

enum SpeechMode: String, CaseIterable {
    case englishToChinese = "english_to_chinese"
    case chineseToEnglish = "chinese_to_english"
    case cantoneseToChinese = "cantonese_to_chinese"
    case shanghaineseToChinese = "shanghainese_to_chinese"
    case chineseEnglishBidirectional = "chinese_english_bidirectional"
    case japaneseToChinese = "japanese_to_chinese"
    case koreanToChinese = "korean_to_chinese"

    var title: String {
        switch self {
        case .englishToChinese:
            "英文转中文"
        case .chineseToEnglish:
            "中文转英文"
        case .cantoneseToChinese:
            "粤语转中文"
        case .shanghaineseToChinese:
            "上海话转中文"
        case .chineseEnglishBidirectional:
            "中英反转互译"
        case .japaneseToChinese:
            "日语转中文"
        case .koreanToChinese:
            "韩语转中文"
        }
    }

    var sourceLanguage: String {
        switch self {
        case .englishToChinese:
            "en"
        case .chineseToEnglish:
            "zh"
        case .cantoneseToChinese:
            "yue-CN"
        case .shanghaineseToChinese:
            "sh-CN"
        case .chineseEnglishBidirectional:
            "zhen"
        case .japaneseToChinese:
            "ja"
        case .koreanToChinese:
            "ko"
        }
    }

    var targetLanguage: String {
        switch self {
        case .englishToChinese, .cantoneseToChinese, .shanghaineseToChinese, .japaneseToChinese, .koreanToChinese:
            "zh"
        case .chineseToEnglish:
            "en"
        case .chineseEnglishBidirectional:
            "zhen"
        }
    }

    var detail: String {
        "\(sourceLanguage) → \(targetLanguage)"
    }
}
