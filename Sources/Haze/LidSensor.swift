import Foundation
import IOKit.hid

/// Reads the hinge angle from the lid sensor in recent MacBooks: an Apple HID device
/// on the sensor usage page (0x20) with the orientation usage (0x8A). It's
/// undocumented, so older Macs simply don't have it and `angle()` returns nil.
final class LidSensor {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var lastAttempt = Date.distantPast

    init() { connect() }

    deinit { disconnect() }

    var isAvailable: Bool { device != nil }

    /// The lid angle in degrees (0 = shut), or nil when there's no sensor to read.
    func angle() -> Double? {
        // The device handle can go stale across sleep; retry now and then, not every tick.
        if device == nil, Date().timeIntervalSince(lastAttempt) > 5 { connect() }
        guard let device else { return nil }

        var report = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(report.count)
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess, length >= 3 else {
            disconnect()
            return nil
        }
        // Report 1: [report id, angle low byte, angle high byte].
        return Double(UInt16(report[2]) << 8 | UInt16(report[1]))
    }

    func reconnect() {
        disconnect()
        connect()
    }

    private func connect() {
        lastAttempt = Date()
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDProductIDKey: 0x8104,
            kIOHIDPrimaryUsagePageKey: 0x0020,
            kIOHIDPrimaryUsageKey: 0x008A,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let device = devices.first(where: {
                  IOHIDDeviceOpen($0, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess
              })
        else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return
        }
        self.manager = manager
        self.device = device
    }

    private func disconnect() {
        if let device { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
        if let manager { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        device = nil
        manager = nil
    }
}
