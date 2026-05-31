import AppKit

@MainActor
extension SettingsWindowController {
    @objc func pasteAPIKey() {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        setAPIKey(text.trimmingCharacters(in: .whitespacesAndNewlines))
        activeAPIKeyField().selectText(nil)
        statusLabel.stringValue = "已从剪贴板粘贴 API Key"
    }

    @objc func toggleAPIKeyVisibility() {
        setAPIKey(currentAPIKey())
        apiKeyVisible.toggle()
        updateAPIKeyVisibility()
        activeAPIKeyField().selectText(nil)
    }

    @objc func clearAPIKey() {
        setAPIKey("")
        activeAPIKeyField().selectText(nil)
        statusLabel.stringValue = "已清空 API Key"
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              textField === apiKeyField || textField === apiKeyVisibleField else {
            return
        }
        setAPIKey(textField.stringValue)
    }

    func setupAPIKeyControls() {
        [apiKeyField, apiKeyVisibleField].forEach { field in
            field.delegate = self
            field.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
            field.placeholderString = "粘贴控制台 API Key"
            field.lineBreakMode = .byTruncatingMiddle
            field.cell?.usesSingleLineMode = true
        }
        apiKeyVisibleField.isHidden = true
        apiKeyLengthLabel.textColor = .secondaryLabelColor

        pasteAPIKeyButton.target = self
        pasteAPIKeyButton.action = #selector(pasteAPIKey)
        revealAPIKeyButton.target = self
        revealAPIKeyButton.action = #selector(toggleAPIKeyVisibility)
        clearAPIKeyButton.target = self
        clearAPIKeyButton.action = #selector(clearAPIKey)
    }

    func setAPIKey(_ value: String) {
        if apiKeyField.stringValue != value {
            apiKeyField.stringValue = value
        }
        if apiKeyVisibleField.stringValue != value {
            apiKeyVisibleField.stringValue = value
        }
        updateAPIKeyLength()
    }

    func currentAPIKey() -> String {
        apiKeyVisible ? apiKeyVisibleField.stringValue : apiKeyField.stringValue
    }

    func activeAPIKeyField() -> NSTextField {
        apiKeyVisible ? apiKeyVisibleField : apiKeyField
    }

    func updateAPIKeyVisibility() {
        apiKeyField.isHidden = apiKeyVisible
        apiKeyVisibleField.isHidden = apiKeyVisible == false
        revealAPIKeyButton.title = apiKeyVisible ? "隐藏" : "显示"
    }

    func updateAPIKeyLength() {
        let count = currentAPIKey().count
        apiKeyLengthLabel.stringValue = count == 0 ? "未填写" : "已输入 \(count) 位"
    }
}
