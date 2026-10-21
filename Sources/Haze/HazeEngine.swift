import AppKit
import Combine

/// Turns the lid angle into how hazy the screen should be and eases the overlay
/// toward it. The haze depends on the angle alone: none above the start angle, full
/// at the full-haze angle, in between in proportion. Opening the lid only ever clears
/// it, and if the lid stays put for a moment the screen clears too, so you can work
/// with it tilted low. Settings can limit it to closing or to opening.
///
/// Light on the battery: the sensor is read 5 times a second while the lid is at rest,
/// 12 while it's held hazed, and 60 only while it moves or the haze is changing.
/// Nothing is read while the display sleeps, or while Haze is off and Settings is
/// closed.
@MainActor
final class HazeEngine: ObservableObject {
    /// The last angle read, for the menu and Settings. Nil without a lid sensor.
    @Published private(set) var angle: Double?

    /// Set while Settings is open, so its live angle keeps updating even with Haze off.
    var isWatched = false {
        didSet { if isWatched != oldValue { tick() } }
    }

    private let settings = HazeSettings.shared
    private let sensor = LidSensor()
    private let overlay = HazeOverlay()
    private var timer: Timer?
    private var lastTick = Date()
    private var cancellables = Set<AnyCancellable>()

    private var anchorAngle: Double?
    private var isOpening = false
    private var lastMove = Date.distantPast
    private var target: CGFloat = 0
    private var shown: CGFloat = 0
    /// Clearing as fast as the eye allows: the haze isn't meant to play on opening.
    private var clearsFast = false
    private var isAsleep = false
    private var previewStart: Date?
    private var previewTop = 110.0

    private let shutAngle = 5.0  // the lid is closed
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
        // Turning Haze back on (or any change in Settings) picks the polling back up.
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.tick() }
            .store(in: &cancellables)
        tick()
    }

    /// Plays a close-and-open of the lid without touching it.
    func preview() {
        previewTop = min(settings.startAngle + 25, 135)
        previewStart = Date()
        tick()
    }

    /// A fresh reading for the menu, even while polling is paused.
    func refreshAngle() {
        let measured = sensor.angle()
        if measured != angle { angle = measured }
    }

    /// How hazy the screen is at a lid angle, 0...1, from the settings alone.
    func haze(at angle: Double) -> CGFloat {
        let start = settings.startAngle
        let full = min(settings.fullAngle, start - 5)
        return CGFloat(min(max((start - angle) / (start - full), 0), 1))
    }

    /// Going dark: stop reading the sensor. Leave the screen hazed so it wakes hazed and
    /// clears as the lid opens — or, if the haze only plays on closing, clear it now,
    /// unseen. Without a lid sensor, the wake is the whole effect.
    private func willSleep() {
        isAsleep = true
        schedule(every: nil)
        guard settings.isEnabled else { return }
        let haze: CGFloat = settings.trigger.playsOnOpen ? 1 : 0
        shown = haze
        target = haze
        overlay.apply(haze, blur: settings.blur, dimming: settings.dimming)
    }

    private func didWake() {
        isAsleep = false
        sensor.reconnect()
        lastTick = Date()
        tick()
    }

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTick), 0.1)
        lastTick = now

        let isActive = settings.isEnabled || previewStart != nil
        guard !isAsleep else {
            schedule(every: nil)
            return
        }
        guard isActive || isWatched else {
            // Off, and nobody's watching the angle: clear up and stop reading the sensor.
            shown = 0
            target = 0
            overlay.apply(0, blur: settings.blur, dimming: settings.dimming)
            schedule(every: nil)
            return
        }

        let measured = sensor.angle()
        if measured != angle { angle = measured }
        if isActive, let reading = previewAngle(at: now) ?? measured {
            track(reading, at: now)
        } else {
            target = 0
            clearsFast = false
        }

        // Haze comes in fast enough to keep up with the lid, and clears a little slower.
        let rate = target > shown ? 20.0 : (clearsFast ? 40.0 : 9.0)
        shown += (target - shown) * CGFloat(1 - exp(-dt * rate))
        if abs(target - shown) < 0.003 { shown = target }

        if let hold = UserDefaults.standard.string(forKey: "HazeHold").flatMap(Double.init) {
            shown = CGFloat(hold) // `open Haze.app --args -HazeHold 0.6` freezes the effect for a look
        }
        overlay.apply(shown, blur: settings.blur, dimming: settings.dimming)

        if previewStart != nil || shown != target || now.timeIntervalSince(lastMove) < 0.4 {
            schedule(every: 1.0 / 60)
        } else if shown == 0 {
            // At rest and clear. Each reading is a round trip to the sensor, so read
            // rarely: the first one that sees the lid move switches to 60 a second, and
            // the haze is worked out from the angle itself, so it catches up at once.
            schedule(every: 1.0 / 5)
        } else {
            schedule(every: 1.0 / 12) // hazed and held: watching for the clear-up
        }
    }

    private func track(_ angle: Double, at now: Date) {
        if let anchor = anchorAngle, abs(angle - anchor) < deadZone {
            // Not moving.
        } else {
            if let anchor = anchorAngle { isOpening = angle > anchor }
            anchorAngle = angle
            lastMove = now
        }
        clearsFast = false
        let trigger = settings.trigger

        if angle <= shutAngle {
            // Shut: hazed, so it opens hazed. Only playing on open, it hasn't faded in
            // on the way down, so it jumps there — unseen, the lid's closed.
            target = 1
            if !trigger.playsOnClose { shown = 1 }
        } else if now.timeIntervalSince(lastMove) > settings.clearDelay {
            target = 0 // held still: let the screen clear
        } else if isOpening {
            // Opening only ever clears; playing on close only, it just gets out of the way.
            target = trigger.playsOnOpen ? min(haze(at: angle), shown) : 0
            clearsFast = !trigger.playsOnOpen
        } else {
            target = trigger.playsOnClose ? haze(at: angle) : 0
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

    /// Polls every `interval` seconds, or stops when nil. Idle timers get some slack so
    /// macOS can batch Haze's wakeups with everything else's.
    private func schedule(every interval: TimeInterval?) {
        guard let interval else {
            timer?.invalidate()
            timer = nil
            return
        }
        guard timer?.timeInterval != interval else { return }
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = interval < 0.05 ? 0.002 : interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
