// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "SonicVision",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "SonicVision",
            targets: ["SonicVision"],
            bundleIdentifier: "com.sonicvision.app",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .mic),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.pad],
            supportedInterfaceOrientations: [.portrait, .portraitUpsideDown, .landscapeRight, .landscapeLeft],
            capabilities: [
                .camera(purposeString: "Sonic Vision uses the camera and LiDAR sensor to detect obstacles and provide spatial audio feedback.")
            ]
        )
    ],
    targets: [
        .executableTarget(name: "SonicVision")
    ]
)
