import AppKit
import Foundation
import IOBluetooth
import IOKit
import SwiftUI

@_silgen_name("IOBluetoothPreferenceGetControllerPowerState")
private func IOBluetoothPreferenceGetControllerPowerState() -> Int32

@_silgen_name("IOBluetoothPreferenceSetControllerPowerState")
private func IOBluetoothPreferenceSetControllerPowerState(_ powerState: Int32)

private enum LidState {
    case open
    case closed
    case unavailable
}

private struct BluetoothPowerController {
    private static let off: Int32 = 0
    private static let on: Int32 = 1

    func turnOffIfNeeded() {
        guard IOBluetoothPreferenceGetControllerPowerState() == Self.on else {
            return
        }

        IOBluetoothPreferenceSetControllerPowerState(Self.off)
    }
}

private final class ClamshellReader {
    private var rootDomain: io_service_t = 0

    init() {
        rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    }

    deinit {
        if rootDomain != 0 {
            IOObjectRelease(rootDomain)
        }
    }

    func currentState() -> LidState {
        if rootDomain == 0 {
            rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        }

        guard rootDomain != 0 else {
            return .unavailable
        }

        guard let property = IORegistryEntryCreateCFProperty(
            rootDomain,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        ) else {
            return .unavailable
        }

        let value = property.takeRetainedValue()
        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((value as! CFBoolean)) ? .closed : .open
        }

        if let number = value as? NSNumber {
            return number.boolValue ? .closed : .open
        }

        return .unavailable
    }
}

private final class AppModel: ObservableObject {
    @Published var guardEnabled: Bool {
        didSet {
            defaults.set(guardEnabled, forKey: "guardEnabled")
            enforcePolicyIfNeeded()
        }
    }

    private let defaults = UserDefaults.standard
    private let bluetooth = BluetoothPowerController()
    private let clamshell = ClamshellReader()
    private var pollTimer: Timer?

    init() {
        guardEnabled = defaults.object(forKey: "guardEnabled") as? Bool ?? true
        startPolling()
        enforcePolicyIfNeeded()
    }

    deinit {
        pollTimer?.invalidate()
    }

    var menuBarImage: String {
        guardEnabled ? "power.circle" : "pause.circle"
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.enforcePolicyIfNeeded()
        }

        pollTimer?.tolerance = 1
    }

    private func enforcePolicyIfNeeded() {
        guard guardEnabled else {
            return
        }

        guard clamshell.currentState() == .closed else {
            return
        }

        bluetooth.turnOffIfNeeded()
    }
}

@main
struct LidBluetoothGuardApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            Toggle("合盖时关闭蓝牙", isOn: $model.guardEnabled)

            Divider()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: model.menuBarImage)
        }
    }
}
