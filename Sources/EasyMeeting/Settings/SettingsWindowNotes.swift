import AppKit

@MainActor
extension SettingsWindowController {
    /// 备注页布局：开关 + 多行文本框，文本框带垂直滚动条。
    func notesPage() -> NSView {
        let page = pageView(title: "备注")
        let group = groupView(y: 0, height: 360)
        page.addSubview(group)

        addRowTitle("显示备注栏", to: group, y: 322)
        notesEnabledCheckbox.frame = NSRect(x: 220, y: 320, width: 230, height: 24)
        group.addSubview(notesEnabledCheckbox)
        addDivider(to: group, y: 304)

        addRowTitle("备注内容", to: group, y: 270)
        let hint = NSTextField(labelWithString: "用于演示时对照的稿子或提示，悬浮窗右侧栏会同步显示。")
        hint.font = .systemFont(ofSize: 11, weight: .regular)
        hint.textColor = .secondaryLabelColor
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 2
        hint.frame = NSRect(x: 220, y: 252, width: 338, height: 32)
        group.addSubview(hint)

        notesScrollView.frame = NSRect(x: 18, y: 18, width: 540, height: 220)
        group.addSubview(notesScrollView)
        return page
    }

    /// 配置备注页控件，仅在 setupContent 阶段调用一次。
    func setupNotesControls() {
        notesEnabledCheckbox.title = "启用悬浮窗备注栏"
        notesEnabledCheckbox.setButtonType(.switch)
        notesEnabledCheckbox.target = self
        notesEnabledCheckbox.action = #selector(toggleNotesEnabled)

        notesScrollView.borderType = .bezelBorder
        notesScrollView.hasVerticalScroller = true
        notesScrollView.hasHorizontalScroller = false
        notesScrollView.autohidesScrollers = true
        notesScrollView.drawsBackground = true

        notesTextView.minSize = NSSize(width: 0, height: 0)
        notesTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        notesTextView.isVerticallyResizable = true
        notesTextView.isHorizontallyResizable = false
        notesTextView.autoresizingMask = .width
        notesTextView.textContainer?.containerSize = NSSize(
            width: notesScrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        notesTextView.textContainer?.widthTracksTextView = true
        notesTextView.font = .systemFont(ofSize: 13, weight: .regular)
        notesTextView.allowsUndo = true
        notesTextView.isRichText = false
        notesTextView.usesFindBar = true
        notesTextView.delegate = self
        notesScrollView.documentView = notesTextView
    }

    /// 把当前 settings 的备注内容回填到文本框，仅 loadSettings 调用。
    func loadNotesIntoUI(from settings: AppSettings) {
        notesEnabledCheckbox.state = settings.overlayNotesEnabled ? .on : .off
        if notesTextView.string != settings.overlayNotesText {
            notesTextView.string = settings.overlayNotesText
        }
    }

    @objc func toggleNotesEnabled() {
        // 开关切换实时同步给悬浮窗，并立即落盘。
        overlayController.setNotesEnabled(notesEnabledCheckbox.state == .on)
        autosave()
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView,
              textView === notesTextView else { return }
        // 编辑时只实时预览悬浮窗，避免高频写 UserDefaults。
        overlayController.setNotesText(textView.string)
    }

    func textDidEndEditing(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView,
              textView === notesTextView else { return }
        autosave()
    }
}
