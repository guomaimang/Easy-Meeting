import AppKit

@MainActor
extension SettingsWindowController {
    @objc func changeSpeechMode() {
        let configuration = selectedSpeechMode().configuration(for: selectedProvider())
        selectSourceCode(configuration.sourceCode)
        selectTargetCode(configuration.targetCode)
        updateSpeechModeDetail()
        autosave()
    }

    @objc func changeSpeechLanguage() {
        selectMatchingSpeechModeIfNeeded()
        updateSpeechModeDetail()
        autosave()
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

        reloadSpeechModePopUp()
        selectMatchingSpeechModeIfNeeded()
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
        let presets = currentSpeechModePresets()
        guard presets.indices.contains(index) else {
            return .englishToChinese
        }
        return presets[index]
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

    func reloadSpeechModePopUp(selectedMode: SpeechMode? = nil) {
        let presets = currentSpeechModePresets()
        speechModePopUp.removeAllItems()
        speechModePopUp.addItems(withTitles: presets.map(\.title))

        let modeToSelect = selectedMode ?? .englishToChinese
        let selectedIndex = presets.firstIndex(of: modeToSelect) ?? 0
        speechModePopUp.selectItem(at: selectedIndex)
        speechModePopUp.isEnabled = presets.isEmpty == false
    }

    func currentSpeechModePresets() -> [SpeechMode] {
        SpeechMode.presets(for: selectedProvider())
    }

    /// 源/目标命中当前服务商的某个预设时同步勾选翻译预设。
    func selectMatchingSpeechModeIfNeeded() {
        let configuration = selectedSpeechConfiguration()
        let presets = currentSpeechModePresets()
        if let mode = presets.first(where: { mode in
            let presetConfiguration = mode.configuration(for: configuration.provider)
            return presetConfiguration.sourceCode == configuration.sourceCode &&
                presetConfiguration.targetCode == configuration.targetCode
        }), let index = presets.firstIndex(of: mode) {
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
