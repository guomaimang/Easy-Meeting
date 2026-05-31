import AppKit

final class SettingsBackgroundView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }
}
