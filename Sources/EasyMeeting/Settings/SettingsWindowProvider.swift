import AppKit

@MainActor
extension SettingsWindowController {
    /// 汇总当前 UI 状态为 AppSettings。
    func currentSettings() -> AppSettings {
        syncCurrentProviderKeyDraft()
        let azureSpeechRegion = regionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppSettings(
            speechProvider: selectedProvider(),
            speechMode: selectedSpeechMode(),
            speechSourceLanguage: selectedSourceCode(),
            speechTargetLanguage: selectedTargetCode(),
            volcengineAPIKey: volcengineKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            azureSpeechKey: azureKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            azureSpeechRegion: azureSpeechRegion.isEmpty ? AppSettings.defaults.azureSpeechRegion : azureSpeechRegion,
            overlayOpacity: opacitySlider.doubleValue,
            overlayFontSize: fontSizeSlider.doubleValue,
            overlayNotesEnabled: notesEnabledCheckbox.state == .on,
            overlayNotesText: notesTextView.string
        )
    }

    func selectedProvider() -> SpeechProvider {
        let index = providerPopUp.indexOfSelectedItem
        guard SpeechProvider.allCases.indices.contains(index) else {
            return .volcengine
        }
        return SpeechProvider.allCases[index]
    }

    /// 当前 provider 已保存的密钥草稿。
    func currentProviderKeyDraft() -> String {
        selectedProvider() == .azure ? azureKeyDraft : volcengineKeyDraft
    }

    /// 把输入框里的密钥写回当前 provider 的草稿。
    func syncCurrentProviderKeyDraft() {
        if selectedProvider() == .azure {
            azureKeyDraft = currentAPIKey()
        } else {
            volcengineKeyDraft = currentAPIKey()
        }
    }

    /// 按 provider 选择诊断信息。
    func currentDiagnostic(for settings: AppSettings) -> String {
        switch settings.speechProvider {
        case .volcengine:
            VolcengineHelperRuntime.diagnostic(settings: settings)
        case .azure:
            AzureHelperRuntime.diagnostic(settings: settings)
        }
    }
}
