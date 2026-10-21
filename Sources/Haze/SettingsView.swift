import AppKit
import ServiceManagement
import SwiftUI

/// The Settings window: one per app. Closed, it lets go of its view, so nothing in it
/// keeps redrawing (or keeps the lid sensor polled) while nobody's looking.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private weak var engine: HazeEngine?

    func show(engine: HazeEngine) {
        self.engine = engine
        let content = NSHostingController(rootView: SettingsView(settings: .shared, engine: engine))
        if let window {
            if window.contentViewController == nil { window.contentViewController = content }
        } else {
            let window = NSWindow(contentViewController: content)
            window.title = "Haze"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        engine.isWatched = true
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        engine?.isWatched = false
        window?.contentViewController = nil
    }
}

struct SettingsView: View {
    @ObservedObject var settings: HazeSettings
    @ObservedObject var engine: HazeEngine
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Haze", isOn: $settings.isEnabled)
                Picker("Plays on", selection: $settings.trigger) {
                    ForEach(HazeSettings.Trigger.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(!settings.isEnabled)
            } footer: {
                Text(triggerDescription)
                    .foregroundStyle(.secondary)
            }

            Section {
                if let angle = engine.angle {
                    LabeledContent("Lid now") {
                        Text("\(Int(angle))° · \(Int((engine.haze(at: angle) * 100).rounded()))% haze")
                            .monospacedDigit()
                    }
                }
                angleRow("Starts at", settings.startAngle) {
                    settings.startAngle = max($0, settings.fullAngle + 5)
                }
                angleRow("Full haze at", settings.fullAngle) {
                    settings.fullAngle = min($0, settings.startAngle - 5)
                }
                LabeledContent("Clears after") {
                    HStack {
                        Slider(value: Binding(get: { settings.clearDelay },
                                              set: { settings.clearDelay = ($0 * 2).rounded() / 2 }),
                               in: HazeSettings.clearDelayRange)
                        Text(String(format: "%g s", settings.clearDelay))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            } header: {
                Text("When")
            } footer: {
                Text(engine.angle == nil
                     ? "This Mac has no lid angle sensor, so the haze only clears when it wakes."
                     : "No haze above the start angle; it builds as the lid closes and is full at the full-haze angle. Tilt the lid to an angle and click Set to use it. Holding the lid still clears the screen after the delay.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Blur") { percentSlider($settings.blur) }
                LabeledContent("Dimming") { percentSlider($settings.dimming) }
                HStack {
                    Spacer()
                    Button("Preview") { engine.preview() }
                }
            } header: {
                Text("Look")
            }

            Section {
                Toggle("Open at login", isOn: $opensAtLogin)
                    .onChange(of: opensAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            NSLog("Haze: changing Open at Login failed: \(error)")
                        }
                        opensAtLogin = SMAppService.mainApp.status == .enabled
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
    }

    private var triggerDescription: String {
        switch settings.trigger {
        case .both: return "The screen hazes over as the lid closes and clears as it opens."
        case .close: return "The screen hazes over as the lid closes; opening it, the screen is simply clear."
        case .open: return "Closing the lid leaves the screen as it is; it wakes hazed and clears as the lid opens."
        }
    }

    /// A degree slider, plus a Set button that takes the lid's current angle.
    private func angleRow(_ title: String, _ value: Double, set: @escaping (Double) -> Void) -> some View {
        LabeledContent(title) {
            HStack {
                // Rounded by hand: a stepped slider draws a tick for every degree.
                Slider(value: Binding(get: { value }, set: { set($0.rounded()) }), in: HazeSettings.angleRange)
                Text("\(Int(value))°")
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
                if let angle = engine.angle {
                    Button("Set") { set(min(max(angle.rounded(), HazeSettings.angleRange.lowerBound),
                                            HazeSettings.angleRange.upperBound)) }
                        .help("Use the lid's current angle, \(Int(angle))°")
                }
            }
        }
    }

    private func percentSlider(_ value: Binding<Double>) -> some View {
        HStack {
            Slider(value: value, in: 0...1)
            Text("\(Int((value.wrappedValue * 100).rounded()))%")
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }
}
