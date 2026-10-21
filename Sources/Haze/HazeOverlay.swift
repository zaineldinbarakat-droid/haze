import AppKit

/// A click-through window over the built-in display that frosts and dims it, the
/// way the iPhone Duo's inner screen does as it folds: the hinge (the bottom of a
/// MacBook screen) stays sharp longest, the free edge (the top) goes soft and dark
/// first, and by the time the lid is nearly shut the whole screen has faded out.
final class HazeOverlay {
    private var window: NSWindow?
    private let frostHost = NSView()
    private let frost = CAGradientLayer() // masks the blur: where it's opaque, the screen is frosted
    private let shade = CAGradientLayer()
    private var applied: [CGFloat] = [-1, -1, -1]

    /// `strength`: 0 = no effect (the window is ordered out), 1 = lid all but shut.
    /// `blur` and `dimming` (0...1) scale the frost and the darkening at any strength.
    func apply(_ strength: CGFloat, blur: Double, dimming: Double) {
        let strength = min(max(strength, 0), 1)
        let values = [strength, CGFloat(blur), CGFloat(dimming)]
        guard (strength == 0) != (applied[0] == 0)
                || zip(values, applied).contains(where: { abs($0 - $1) > 0.002 }) else { return }
        applied = values

        guard strength > 0, let screen = Self.builtInScreen else {
            window?.orderOut(nil)
            return
        }
        let window = self.window ?? makeWindow()
        if window.frame != screen.frame { window.setFrame(screen.frame, display: false) }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frost.frame = frostHost.bounds
        frost.colors = Self.frostStops.map {
            NSColor(white: 1, alpha: CGFloat(blur) * Self.frost(at: $0, strength)).cgColor
        }
        let dim = CGFloat(dimming) * strength
        shade.colors = [
            NSColor.black.withAlphaComponent(0.85 * dim).cgColor, // free edge
            NSColor.black.withAlphaComponent(0.5 * dim).cgColor,  // hinge
        ]
        CATransaction.commit()

        if !window.isVisible { window.orderFrontRegardless() }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        // Above the menu bar, the Dock and full-screen apps, on every Space.
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.canBecomeVisibleWithoutLogin = true

        let content = NSView()
        content.wantsLayer = true

        let blur = NSVisualEffectView()
        blur.blendingMode = .behindWindow
        blur.material = .fullScreenUI
        blur.appearance = NSAppearance(named: .darkAqua)
        // An accessory app is never active; without this the blur turns into a flat fill.
        blur.state = .active
        blur.autoresizingMask = [.width, .height]

        // The blur sits in a host whose layer mask fades it out toward the hinge. The
        // effect view's own maskImage won't stretch a 1-pixel strip over the screen.
        frostHost.wantsLayer = true
        frostHost.layer?.mask = frost
        frostHost.autoresizingMask = [.width, .height]
        frostHost.addSubview(blur)
        frost.locations = Self.frostStops.map { NSNumber(value: Double($0)) }
        frost.startPoint = CGPoint(x: 0.5, y: 0) // hinge
        frost.endPoint = CGPoint(x: 0.5, y: 1)   // free edge
        content.addSubview(frostHost)

        let shadeView = NSView()
        shadeView.layer = shade // layer first, then wantsLayer: the view hosts the gradient as is
        shadeView.wantsLayer = true
        shade.startPoint = CGPoint(x: 0.5, y: 1)
        shade.endPoint = CGPoint(x: 0.5, y: 0)
        shadeView.autoresizingMask = [.width, .height]
        content.addSubview(shadeView)

        window.contentView = content
        window.setFrame(Self.builtInScreen?.frame ?? .zero, display: false)
        frostHost.frame = content.bounds
        blur.frame = frostHost.bounds
        shadeView.frame = content.bounds
        self.window = window
        return window
    }

    /// Heights the frost mask is sampled at, from the hinge (0) to the free edge (1).
    private static let frostStops: [CGFloat] = (0...16).map { CGFloat($0) / 16 }

    /// How much frost shows at a height. It starts at the free edge and creeps toward
    /// the hinge as the lid closes. It shows from the first few percent of strength on,
    /// so the haze visibly begins right at the start angle: at 10% the top edge is
    /// faintly frosted, at 30% the top third, at 60% everything but the hinge.
    private static func frost(at height: CGFloat, _ strength: CGFloat) -> CGFloat {
        guard strength > 0 else { return 0 }
        let reach = 4 * strength - 2.6 * (1 - height)
        let ramp = min(max(reach, 0), 1)
        return ramp * ramp * (3 - 2 * ramp)
    }

    static var builtInScreen: NSScreen? {
        NSScreen.screens.first { screen in
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let id = screen.deviceDescription[key] as? CGDirectDisplayID else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }
    }
}
