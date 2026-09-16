// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "AllToastForMac",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "all-toast-for-mac", targets: ["AllToastForMac"])],
    targets: [
        .executableTarget(
            name: "AllToastForMac",
            path: "Sources/AllToastForMac"
        )
    ]
)
