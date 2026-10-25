// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Riji",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Riji", targets: ["Riji"])
    ],
    targets: [
        .target(
            name: "RijiCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Riji",
            dependencies: ["RijiCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "RijiChecks",
            dependencies: ["RijiCore"],
            path: "Tests/RijiChecks",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
