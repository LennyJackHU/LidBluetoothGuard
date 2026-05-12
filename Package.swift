// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LidBluetoothGuard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LidBluetoothGuard", targets: ["LidBluetoothGuard"])
    ],
    targets: [
        .executableTarget(
            name: "LidBluetoothGuard",
            linkerSettings: [
                .linkedFramework("IOBluetooth"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
