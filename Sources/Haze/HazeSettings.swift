import Foundation

/// What you can change about Haze, kept in UserDefaults.
@MainActor
final class HazeSettings: ObservableObject {
    static let shared = HazeSettings()

    @Published var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: Keys.enabled) } }
    /// The lid angle the haze starts at. Above it the screen stays clear.
    @Published var startAngle: Double { didSet { defaults.set(startAngle, forKey: Keys.startAngle) } }
    /// The lid angle the haze is at its fullest.
    @Published var fullAngle: Double { didSet { defaults.set(fullAngle, forKey: Keys.fullAngle) } }
    /// Seconds the lid has to stay still before the screen clears.
    @Published var clearDelay: Double { didSet { defaults.set(clearDelay, forKey: Keys.clearDelay) } }
    /// How much of the frost shows, 0...1.
    @Published var blur: Double { didSet { defaults.set(blur, forKey: Keys.blur) } }
    /// How dark the screen gets, 0...1.
    @Published var dimming: Double { didSet { defaults.set(dimming, forKey: Keys.dimming) } }

    static let angleRange: ClosedRange<Double> = 5...135
    static let clearDelayRange: ClosedRange<Double> = 1...10

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let enabled = "enabled"
        static let startAngle = "startAngle"
        static let fullAngle = "fullAngle"
        static let clearDelay = "clearDelay"
        static let blur = "blur"
        static let dimming = "dimming"
    }

    private init() {
        defaults.register(defaults: [
            Keys.enabled: true,
            Keys.startAngle: 80.0,
            Keys.fullAngle: 15.0,
            Keys.clearDelay: 3.0,
            Keys.blur: 1.0,
            Keys.dimming: 1.0,
        ])
        isEnabled = defaults.bool(forKey: Keys.enabled)
        startAngle = defaults.double(forKey: Keys.startAngle)
        fullAngle = defaults.double(forKey: Keys.fullAngle)
        clearDelay = defaults.double(forKey: Keys.clearDelay)
        blur = defaults.double(forKey: Keys.blur)
        dimming = defaults.double(forKey: Keys.dimming)
    }
}
