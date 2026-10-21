import AppKit

/// Turns the lid angle into how hazy the screen should be and eases the overlay
/// toward it. The haze depends on the angle alone: none above the start angle, full
/// at the full-haze angle, in between in proportion. Opening the lid only ever clears
/// it, and if the lid stays put for a moment the screen clears too, so you can work
/// with it tilted low.
@MainActor
final class HazeEngine: ObservableObject {
    /// The last angle read, for the menu and Settings. Nil without a lid sensor.
    @Published private(set) var angle: Double?

    private let settings = HazeSettings.shared
    private let sensor = LidSensor()
    private let overlay = HazeOverlay()
    private var timer: Timer?
    private var lastTick = Date()

    private var anchorAngle: Double?
    private var isOpening = false
    private var lastMove = Date.distantPast
    private var target: CGFloat = 0
    private var shown: CGFloat = 0
    private var previewStart: Date?
    private var previewTop = 110.0

    private let shutAngle = 5.0  // the lid is closed: keep it hazed so it opens hazed
    private let deadZone = 1.5   // the lid wobbling while you type shouldn't count as moving

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.willSleep() }
            }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.didWake() }
            }
        }
        tick()
    }

    /// Plays a close-and-open of the lid without touching it.
    func preview() {
        previewTop = min(settings.startAngle + 25, 135)
        previewStart = Date()
        tick()
    }

    /// How hazy the screen is at a lid angle, 0...1, from the settings alone.
    func haze(at angle: Double) -> CGFloat {
        let start = settings.startAngle
        let full = min(settings.fullAngle, start - 5)
        return CGFloat(min(max((start - angle) / (start - full), 0), 1))
    }

    /// Leave the screen hazed going to sleep, so it wakes up hazed and clears as the lid
    /// opens. Without a lid sensor that's the whole effect: it clears on wake.
    private func willSleep() {
        guard settings.isEnabled else { return }
        shown = 1
        target = 1
        overlay.apply(1, blur: settings.blur, dimming: settings.dimming)
    }

    private func didWake() {
        sensor.reconnect()
        lastTick = Date()
        tick()
    }

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTick), 0.1)
        lastTick = now

        let measured = sensor.angle()
        if measured != angle { angle = measured }
        if let reading = previewAngle(at: now) ?? measured {
            track(reading, at: now)
        } else {
            target = 0
        }
        if !settings.isEnabled && previewStart == nil { target = 0 }

        // Haze comes in fast enough to keep up with the lid, and clears a little slower.
        let rate = target > shown ? 20.0 : 9.0
        shown += (target - shown) * CGFloat(1 - exp(-dt * rate))
        if abs(target - shown) < 0.003 { shown = target }

        if let hold = UserDefaults.standard.string(forKey: "HazeHold").flatMap(Double.init) {
            shown = CGFloat(hold) // `open Haze.app --args -HazeHold 0.6` freezes the effect for a look
        }
        overlay.apply(shown, blur: settings.blur, dimming: settings.dimming)

        let busy = previewStart != nil || shown != target
            || now.timeIntervalSince(lastMove) < settings.clearDelay + 0.5
        schedule(every: busy ? 1.0 / 60 : 1.0 / 15)
    }

    private func track(_ angle: Double, at now: Date) {
        if let anchor = anchorAngle, abs(angle - anchor) < deadZone {
            // Not moving.
        } else {
            if let anchor = anchorAngle { isOpening = angle > anchor }
            anchorAngle = angle
            lastMove = now
        }

        if angle <= shutAngle {
            target = 1
        } else if now.timeIntervalSince(lastMove) > settings.clearDelay {
            target = 0 // held still: let the screen clear
        } else if isOpening {
            target = min(haze(at: angle), shown) // opening only clears, never hazes
        } else {
            target = haze(at: angle)
        }
    }

    /// A fake lid for `preview()`: closes, pauses nearly shut, opens again.
    private func previewAngle(at now: Date) -> Double? {
        guard let start = previewStart else { return nil }
        let t = now.timeIntervalSince(start)
        let shut = shutAngle - 2
        func ease(_ x: Double) -> Double { let x = min(max(x, 0), 1); return x * x * (3 - 2 * x) }
        switch t {
        case ..<1.2: return previewTop + (shut - previewTop) * ease(t / 1.2)
        case ..<1.8: return shut
        case ..<3.4: return shut + (previewTop - shut) * ease((t - 1.8) / 1.6)
        default:
            previewStart = nil
            lastMove = .distantPast // clear right away instead of waiting on the delay
            return nil
        }
    }

    private func schedule(every interval: TimeInterval) {
        guard timer?.timeInterval != interval else { return }
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
