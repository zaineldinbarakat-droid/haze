import AppKit

/// Haze: the iPhone Duo's fold blur, on a MacBook lid.
@main
enum HazeMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = HazeAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class HazeAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = HazeSettings.shared
    private let engine = HazeEngine()
    private let settingsWindow = SettingsWindowController()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "Haze")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        engine.start()
    }

    /// Opening Haze again while it runs shows Settings, in case its icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show(engine: engine)
        return true
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        engine.refreshAngle()
        let status = engine.angle.map { "Lid at \(Int($0))°" } ?? "No lid sensor: Haze plays on wake only"
        menu.addItem(NSMenuItem(title: status, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        addItem(to: menu, "Haze on Lid \(settings.trigger.menuTitle)", #selector(toggleEnabled), on: settings.isEnabled)
        addItem(to: menu, "Preview", #selector(preview))
        addItem(to: menu, "Settings…", #selector(showSettings), key: ",")
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Haze", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector, on: Bool? = nil, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let on { item.state = on ? .on : .off }
        menu.addItem(item)
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
    }

    @objc private func preview() {
        engine.preview()
    }

    @objc private func showSettings() {
        settingsWindow.show(engine: engine)
    }
}
