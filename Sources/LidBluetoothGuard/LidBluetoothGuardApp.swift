import AppKit
import Darwin
import Foundation
import IOKit
import SwiftUI

private enum LidState {
    case open
    case closed
    case unavailable
}

private final class BluetoothPowerController {
    private static let off: Int32 = 0
    private static let on: Int32 = 1
    private typealias GetPowerState = @convention(c) () -> Int32
    private typealias SetPowerState = @convention(c) (Int32) -> Void

    private let handle: UnsafeMutableRawPointer?
    private let getPowerState: GetPowerState?
    private let setPowerState: SetPowerState?

    init() {
        let frameworkPath = "/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth"
        handle = dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL)

        if let handle {
            getPowerState = dlsym(handle, "IOBluetoothPreferenceGetControllerPowerState").map {
                unsafeBitCast($0, to: GetPowerState.self)
            }
            setPowerState = dlsym(handle, "IOBluetoothPreferenceSetControllerPowerState").map {
                unsafeBitCast($0, to: SetPowerState.self)
            }
        } else {
            getPowerState = nil
            setPowerState = nil
        }
    }

    deinit {
        if let handle {
            dlclose(handle)
        }
    }

    var isOn: Bool {
        getPowerState?() == Self.on
    }

    private var isOff: Bool {
        getPowerState?() == Self.off
    }

    private func turnOff() {
        setPowerState?(Self.off)
    }

    private func turnOn() {
        setPowerState?(Self.on)
    }

    func turnOffIfNeeded() -> Bool {
        guard setPowerState != nil, isOn else {
            return false
        }

        turnOff()
        return isOff
    }

    func turnOnIfNeeded() -> Bool {
        guard setPowerState != nil else {
            return false
        }

        guard !isOn else {
            return true
        }

        turnOn()
        return isOn
    }
}

private final class ClamshellMonitor {
    private static let clamshellStateChangeMessage: UInt32 = {
        let systemIOKit = UInt32(0x38) << 26
        let subsystemPowerManagement = UInt32(13) << 14
        return systemIOKit | subsystemPowerManagement | UInt32(0x100)
    }()

    private var rootDomain: io_service_t = 0
    private var notificationPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private let onChange: (LidState) -> Void

    init(onChange: @escaping (LidState) -> Void) {
        self.onChange = onChange
        start()
    }

    deinit {
        if notifier != 0 {
            IOObjectRelease(notifier)
        }

        if rootDomain != 0 {
            IOObjectRelease(rootDomain)
        }

        if let notificationPort {
            IONotificationPortDestroy(notificationPort)
        }
    }

    private func start() {
        rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != 0 else {
            onChange(.unavailable)
            return
        }

        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            onChange(Self.readState(rootDomain: rootDomain))
            return
        }

        notificationPort = port
        if let runLoopSource = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        let refCon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let result = IOServiceAddInterestNotification(
            port,
            rootDomain,
            kIOGeneralInterest,
            { refCon, _, messageType, _ in
                guard messageType == ClamshellMonitor.clamshellStateChangeMessage, let refCon else {
                    return
                }

                let monitor = Unmanaged<ClamshellMonitor>.fromOpaque(refCon).takeUnretainedValue()
                let state = ClamshellMonitor.readState(rootDomain: monitor.rootDomain)

                if Thread.isMainThread {
                    monitor.onChange(state)
                } else {
                    DispatchQueue.main.async {
                        monitor.onChange(state)
                    }
                }
            },
            refCon,
            &notifier
        )

        if result != KERN_SUCCESS {
            onChange(Self.readState(rootDomain: rootDomain))
            return
        }

        onChange(Self.readState(rootDomain: rootDomain))
    }

    private static func readState(rootDomain: io_service_t) -> LidState {
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
            if !guardEnabled {
                appTurnedBluetoothOff = false
                return
            }

            enforcePolicy(for: lastKnownLidState)
        }
    }

    @Published var restoreOnOpen: Bool {
        didSet {
            defaults.set(restoreOnOpen, forKey: "restoreOnOpen")
            enforcePolicy(for: lastKnownLidState)
        }
    }

    private let defaults = UserDefaults.standard
    private let bluetooth = BluetoothPowerController()
    private var clamshellMonitor: ClamshellMonitor?
    private var appTurnedBluetoothOff: Bool {
        get {
            defaults.bool(forKey: "appTurnedBluetoothOff")
        }
        set {
            defaults.set(newValue, forKey: "appTurnedBluetoothOff")
        }
    }
    private var lastKnownLidState: LidState = .unavailable

    init() {
        guardEnabled = defaults.object(forKey: "guardEnabled") as? Bool ?? true
        restoreOnOpen = defaults.object(forKey: "restoreOnOpen") as? Bool ?? false
        clamshellMonitor = ClamshellMonitor { [weak self] state in
            self?.handleLidStateChange(state)
        }
    }

    var menuBarImage: String {
        guardEnabled ? "power.circle" : "pause.circle"
    }

    private func handleLidStateChange(_ state: LidState) {
        lastKnownLidState = state
        enforcePolicy(for: state)
    }

    private func enforcePolicy(for lidState: LidState) {
        guard guardEnabled else {
            return
        }

        switch lidState {
        case .closed:
            if bluetooth.turnOffIfNeeded() {
                appTurnedBluetoothOff = true
            }

        case .open:
            if restoreOnOpen, appTurnedBluetoothOff {
                if bluetooth.turnOnIfNeeded() {
                    appTurnedBluetoothOff = false
                }
            }

        case .unavailable:
            break
        }
    }
}

@main
struct LidBluetoothGuardApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            Toggle("合盖时关闭蓝牙", isOn: $model.guardEnabled)
            Toggle("开盖后恢复蓝牙", isOn: $model.restoreOnOpen)

            Divider()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: model.menuBarImage)
        }
    }
}
