import Foundation

enum SpeechMode: String, CaseIterable {
    case englishToChinese = "english_to_chinese"
    case cantoneseToChinese = "cantonese_to_chinese"
    case chineseEnglishBidirectional = "chinese_english_bidirectional"

    var title: String {
        switch self {
        case .englishToChinese:
            "英文转中文"
        case .cantoneseToChinese:
            "粤语转中文"
        case .chineseEnglishBidirectional:
            "中英互译"
        }
    }

    var sourceLanguage: String {
        switch self {
        case .englishToChinese:
            "en"
        case .cantoneseToChinese:
            "yue"
        case .chineseEnglishBidirectional:
            "auto"
        }
    }

    var targetLanguage: String {
        switch self {
        case .englishToChinese, .cantoneseToChinese:
            "zh"
        case .chineseEnglishBidirectional:
            "auto"
        }
    }
}
