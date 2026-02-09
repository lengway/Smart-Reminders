// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmartRemindersCore",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SmartRemindersCore",
            targets: ["SmartRemindersCore"])
    ],
    targets: [
        .target(
            name: "SmartRemindersCore",
            dependencies: []),
        .testTarget(
            name: "SmartRemindersCoreTests",
            dependencies: ["SmartRemindersCore"])
    ]
)
