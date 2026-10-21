// Draws Haze's app icon and writes Packaging/Haze.icns.
//
//   swift Packaging/make-icons.swift
//
// Drawn in code on the macOS icon grid — an 824 pt continuous-corner tile on
// a 1024 pt canvas, the same tile as Sleeve and Spindle.
import AppKit
import SwiftUI

let packaging = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

// MARK: - Shared pieces

/// The macOS tile: continuous corners, a soft drop shadow, a faint top highlight.
struct Tile<Content: View>: View {
    var colors: [Color]
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 185, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            content
            shape.fill(LinearGradient(colors: [.white.opacity(0.22), .clear],
                                      startPoint: .top, endPoint: .center))
            shape.strokeBorder(.white.opacity(0.18), lineWidth: 3)
        }
        .frame(width: 824, height: 824)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.35), radius: 22, y: 14)
        .frame(width: 1024, height: 1024)
    }
}

// MARK: - Haze: a MacBook mid-fold

/// A white MacBook whose screen does what Haze does: crisp at the hinge, frosted
/// toward the top edge.
struct HazeIcon: View {
    var body: some View {
        Tile(colors: [Color(white: 0.34), Color(white: 0.07)]) {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .fill(Color.white)
                    HazyScreen()
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .padding(18)
                }
                .frame(width: 560, height: 370)
                UnevenRoundedRectangle(bottomLeadingRadius: 30, bottomTrailingRadius: 30, style: .continuous)
                    .fill(Color(white: 0.93))
                    .frame(width: 680, height: 34)
                    .overlay(alignment: .top) {
                        // The thumb notch in the front edge of the base.
                        UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8, style: .continuous)
                            .fill(Color(white: 0.78))
                            .frame(width: 110, height: 9)
                    }
            }
            .shadow(color: .black.opacity(0.45), radius: 18, y: 16)
            .offset(y: 24)
        }
    }
}

struct HazyScreen: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.30), Color(white: 0.10)],
                           startPoint: .top, endPoint: .bottom)
            // Sharp near the hinge...
            rows.mask(LinearGradient(stops: [.init(color: .clear, location: 0.3),
                                             .init(color: .black, location: 0.72)],
                                     startPoint: .top, endPoint: .bottom))
            // ...frosted toward the free edge.
            rows.blur(radius: 20)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.3),
                                             .init(color: .clear, location: 0.72)],
                                     startPoint: .top, endPoint: .bottom))
            LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)],
                           startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.6))
        }
    }

    /// Lines of "content" on the screen, there for the blur to soften.
    private var rows: some View {
        VStack(alignment: .leading, spacing: 30) {
            ForEach(Array([330, 240, 290, 200, 260].enumerated()), id: \.offset) { _, width in
                Capsule().fill(Color.white).frame(width: CGFloat(width), height: 26)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 56)
    }
}

// MARK: - Rendering

@MainActor
func png<V: View>(_ view: V, size: Int) -> Data? {
    let renderer = ImageRenderer(content: view.frame(width: 1024, height: 1024))
    renderer.scale = CGFloat(size) / 1024
    guard let cg = renderer.cgImage else { return nil }
    return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
}

@MainActor
func makeIcon<V: View>(_ view: V, name: String) throws {
    let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).iconset")
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    for base in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let suffix = scale == 2 ? "@2x" : ""
            guard let data = png(view, size: base * scale) else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: iconset.appendingPathComponent("icon_\(base)x\(base)\(suffix).png"))
        }
    }
    if let preview = png(view, size: 512) {
        try preview.write(to: packaging.appendingPathComponent("\(name)-icon.png"))
    }
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", packaging.appendingPathComponent("\(name).icns").path]
    try iconutil.run()
    iconutil.waitUntilExit()
    print("\(name).icns:", iconutil.terminationStatus == 0 ? "ok" : "iconutil failed")
}

MainActor.assumeIsolated {
    do {
        try makeIcon(HazeIcon(), name: "Haze")
    } catch {
        print("error:", error)
    }
}
