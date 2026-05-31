import AppKit

@MainActor
extension SettingsWindowController {
    @objc func changeSpeechMode() {
        // 翻译预设仅用于火山快捷填充
        guard selectedProvider() == .volcengine else { return }
        let configuration = selectedSpeechMode().configuration
        selectSourceCode(configuration.sourceCode)
        selectTargetCode(configuration.targetCode)
        updateSpeechModeDetail()
    }

    @objc func changeSpeechLanguage() {
        selectMatchingSpeechModeIfNeeded()
        updateSpeechModeDetail()
    }

    /// 按当前 provider 重新填充源/目标语种下拉框。
    func reloadLanguagePopUps(sourceCode: String, targetCode: String) {
        let provider = selectedProvider()
        let sources = SpeechLanguageCatalog.sourceLanguages(for: provider)
        let targets = SpeechLanguageCatalog.targetLanguages(for: provider)

        sourceLanguagePopUp.removeAllItems()
        sourceLanguagePopUp.addItems(withTitles: sources.map(\.menuTitle))
        targetLanguagePopUp.removeAllItems()
        targetLanguagePopUp.addItems(withTitles: targets.map(\.menuTitle))

        selectSourceCode(SpeechLanguageCatalog.validatedSourceCode(sourceCode, for: provider))
        selectTargetCode(SpeechLanguageCatalog.validatedTargetCode(targetCode, for: provider))

        // 翻译预设只对火山有意义
        speechModePopUp.isEnabled = provider == .volcengine
    }

    func updateSpeechModeDetail() {
        let configuration = selectedSpeechConfiguration()
        speechModeDetailLabel.stringValue = configuration.detail
        speechModeDetailLabel.textColor = .secondaryLabelColor
        let validation = configuration.validation
        speechLanguageWarningLabel.stringValue = validation.message ?? ""
        speechLanguageWarningLabel.isHidden = validation.isValid
    }

    func selectedSpeechMode() -> SpeechMode {
        let index = speechModePopUp.indexOfSelectedItem
        guard SpeechMode.allCases.indices.contains(index) else {
            return .englishToChinese
        }
        return SpeechMode.allCases[index]
    }

    func selectedSourceCode() -> String {
        let options = SpeechLanguageCatalog.sourceLanguages(for: selectedProvider())
        let index = sourceLanguagePopUp.indexOfSelectedItem
        guard options.indices.contains(index) else {
            return SpeechLanguageCatalog.defaultSourceCode(for: selectedProvider())
        }
        return options[index].code
    }

    func selectedTargetCode() -> String {
        let options = SpeechLanguageCatalog.targetLanguages(for: selectedProvider())
        let index = targetLanguagePopUp.indexOfSelectedItem
        guard options.indices.contains(index) else {
            return SpeechLanguageCatalog.defaultTargetCode(for: selectedProvider())
        }
        return options[index].code
    }

    func selectedSpeechConfiguration() -> SpeechTranslationConfiguration {
        SpeechTranslationConfiguration(
            provider: selectedProvider(),
            sourceCode: selectedSourceCode(),
            targetCode: selectedTargetCode()
        )
    }

    func selectSourceCode(_ code: String) {
        let options = SpeechLanguageCatalog.sourceLanguages(for: selectedProvider())
        guard let index = options.firstIndex(where: { $0.code == code }) else { return }
        sourceLanguagePopUp.selectItem(at: index)
    }

    func selectTargetCode(_ code: String) {
        let options = SpeechLanguageCatalog.targetLanguages(for: selectedProvider())
        guard let index = options.firstIndex(where: { $0.code == code }) else { return }
        targetLanguagePopUp.selectItem(at: index)
    }

    /// 火山下：源/目标命中某个预设时同步勾选翻译预设。
    func selectMatchingSpeechModeIfNeeded() {
        guard selectedProvider() == .volcengine else { return }
        let configuration = selectedSpeechConfiguration()
        if let mode = SpeechMode.allCases.first(where: { mode in
            mode.configuration.sourceCode == configuration.sourceCode &&
                mode.configuration.targetCode == configuration.targetCode
        }), let index = SpeechMode.allCases.firstIndex(of: mode) {
            speechModePopUp.selectItem(at: index)
        }
    }

    func validateSpeechLanguages() -> Bool {
        let validation = selectedSpeechConfiguration().validation
        if let message = validation.message {
            statusLabel.stringValue = message
            return false
        }
        return true
    }
}
