import AppKit

/// 悬浮窗顶部工具栏：左侧录音开关按钮，紧邻麦克风下拉，右侧齿轮按钮打开设置。
///
/// 无需打开菜单栏即可控制录音、切换麦克风、打开设置。录音中切麦走热切换，
/// 识别与字幕不中断（详见 docs/audio-hot-swap.md）。
final class OverlayToolbarView: NSView {
    private enum Layout {
        static let buttonSize: CGFloat = 24
        static let gap: CGFloat = 8
        static let popUpHeight: CGFloat = 22
        static let popUpMaxWidth: CGFloat = 240
    }

    /// 录音按钮点击回调。
    var onToggleRecording: (() -> Void)?
    /// 麦克风下拉选择回调，回传设备 ID。
    var onSelectDevice: ((String) -> Void)?
    /// 设置按钮点击回调，由上层打开设置窗口。
    var onOpenSettings: (() -> Void)?

    /// 录音状态，转发给录音按钮切换三角 / 方块。
    var isRecording: Bool = false {
        didSet {
            recordButton.isRecording = isRecording
        }
    }

    private let recordButton = OverlayRecordButton()
    private let settingsButton = OverlaySettingsButton()
    private let devicePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    /// 下拉项顺序对应的设备 ID，索引对齐 devicePopUp.itemArray。
    private var deviceIDs: [String] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    /// 刷新麦克风下拉项并同步选中项。无设备时显示占位且禁用。
    func updateDevices(_ devices: [AudioInputDevice], selectedID: String?) {
        deviceIDs = devices.map(\.id)
        devicePopUp.removeAllItems()

        guard devices.isEmpty == false else {
            devicePopUp.addItem(withTitle: "无可用麦克风")
            devicePopUp.isEnabled = false
            needsLayout = true
            return
        }

        devicePopUp.isEnabled = true
        devices.forEach { device in
            let title = device.isDefault ? "\(device.name)（系统默认）" : device.name
            devicePopUp.addItem(withTitle: title)
        }

        if let selectedID, let index = deviceIDs.firstIndex(of: selectedID) {
            devicePopUp.selectItem(at: index)
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()

        recordButton.frame = NSRect(
            x: 0,
            y: (bounds.height - Layout.buttonSize) / 2,
            width: Layout.buttonSize,
            height: Layout.buttonSize
        )

        // 麦克风下拉按内容自适应宽度，避免被撑满整条工具栏；齿轮按钮紧贴在它右侧。
        let popUpX = recordButton.frame.maxX + Layout.gap
        let intrinsicWidth = max(devicePopUp.intrinsicContentSize.width, 0)
        let maxAvailableWidth = max(bounds.width - popUpX - Layout.gap - Layout.buttonSize, 0)
        let popUpWidth = max(min(intrinsicWidth, Layout.popUpMaxWidth, maxAvailableWidth), 0)
        devicePopUp.frame = NSRect(
            x: popUpX,
            y: (bounds.height - Layout.popUpHeight) / 2,
            width: popUpWidth,
            height: Layout.popUpHeight
        )

        let settingsX = devicePopUp.frame.maxX + Layout.gap
        settingsButton.frame = NSRect(
            x: settingsX,
            y: (bounds.height - Layout.buttonSize) / 2,
            width: Layout.buttonSize,
            height: Layout.buttonSize
        )
    }

    private func setup() {
        recordButton.onToggle = { [weak self] in
            self?.onToggleRecording?()
        }
        addSubview(recordButton)

        devicePopUp.bezelStyle = .rounded
        devicePopUp.controlSize = .small
        devicePopUp.font = .systemFont(ofSize: 11)
        // 深色外观融入半透明 HUD，避免浅色控件在黑底上突兀。
        devicePopUp.appearance = NSAppearance(named: .darkAqua)
        devicePopUp.target = self
        devicePopUp.action = #selector(deviceSelectionChanged)
        devicePopUp.toolTip = "切换麦克风"
        addSubview(devicePopUp)

        settingsButton.onOpen = { [weak self] in
            self?.onOpenSettings?()
        }
        addSubview(settingsButton)
    }

    @objc private func deviceSelectionChanged() {
        let index = devicePopUp.indexOfSelectedItem
        guard deviceIDs.indices.contains(index) else { return }
        let deviceID = deviceIDs[index]
        NSLog("悬浮窗麦克风下拉选择：%@", devicePopUp.titleOfSelectedItem ?? deviceID)
        onSelectDevice?(deviceID)
    }
}

