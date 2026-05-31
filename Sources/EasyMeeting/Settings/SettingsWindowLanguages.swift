import AppKit

@MainActor
extension SettingsWindowController {
    @objc func changeSpeechMode() {
        let configuration = selectedSpeechMode().configuration
        selectSourceLanguage(configuration.sourceLanguage)
        selectTargetLanguage(configuration.targetLanguage)
        updateSpeechModeDetail()
    }

    @objc func changeSpeechLanguage() {
        selectMatchingSpeechModeIfNeeded()
        updateSpeechModeDetail()
    }

    func updateSpeechModeDetail() {
        let configuration = selectedSpeechConfiguration()
        speechModeDetailLabel.stringValue = configuration.detail
        speechModeDetailLabel.textColor = .secondaryLabelColor
        speechLanguageWarningLabel.stringValue = configuration.isValidForS2T ? "" : "语种组合无效：源语种或目标语种必须包含中文/英文；zhen 必须两边同时选择。"
        speechLanguageWarningLabel.isHidden = configuration.isValidForS2T
    }

    func selectedSpeechMode() -> SpeechMode {
        let index = speechModePopUp.indexOfSelectedItem
        guard SpeechMode.allCases.indices.contains(index) else {
            return .englishToChinese
        }
        return SpeechMode.allCases[index]
    }

    func selectedSourceLanguage() -> SpeechLanguage {
        let index = sourceLanguagePopUp.indexOfSelectedItem
        guard SpeechLanguage.sourceCases.indices.contains(index) else { return .en }
        return SpeechLanguage.sourceCases[index]
    }

    func selectedTargetLanguage() -> SpeechLanguage {
        let index = targetLanguagePopUp.indexOfSelectedItem
        guard SpeechLanguage.targetCases.indices.contains(index) else { return .zh }
        return SpeechLanguage.targetCases[index]
    }

    func selectedSpeechConfiguration() -> SpeechTranslationConfiguration {
        SpeechTranslationConfiguration(
            sourceLanguage: selectedSourceLanguage(),
            targetLanguage: selectedTargetLanguage()
        )
    }

    func selectSourceLanguage(_ language: SpeechLanguage) {
        guard let index = SpeechLanguage.sourceCases.firstIndex(of: language) else { return }
        sourceLanguagePopUp.selectItem(at: index)
    }

    func selectTargetLanguage(_ language: SpeechLanguage) {
        let fallback = language.canBeTarget ? language : .zh
        guard let index = SpeechLanguage.targetCases.firstIndex(of: fallback) else { return }
        targetLanguagePopUp.selectItem(at: index)
    }

    func selectMatchingSpeechModeIfNeeded() {
        let configuration = selectedSpeechConfiguration()
        if let mode = SpeechMode.allCases.first(where: { mode in
            mode.configuration.sourceLanguage == configuration.sourceLanguage &&
                mode.configuration.targetLanguage == configuration.targetLanguage
        }), let index = SpeechMode.allCases.firstIndex(of: mode) {
            speechModePopUp.selectItem(at: index)
        }
    }

    func validateSpeechLanguages() -> Bool {
        let configuration = selectedSpeechConfiguration()
        guard configuration.isValidForS2T else {
            statusLabel.stringValue = "语种组合无效：源语种或目标语种必须包含中文/英文，zhen 必须两边同时选择。"
            return false
        }
        return true
    }
}
