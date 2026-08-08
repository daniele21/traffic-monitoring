// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrafficMonitoringCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TrafficMonitoringCore", targets: ["TrafficMonitoringCore"])
    ],
    targets: [
        .target(
            name: "TrafficMonitoringCore",
            path: "TrafficMonitoring",
            exclude: ["App", "Platform", "Persistence", "Analytics", "Features"],
            sources: ["Domain", "Tracking"]
        ),
        .testTarget(
            name: "TrafficMonitoringCoreTests",
            dependencies: ["TrafficMonitoringCore"],
            path: "TrafficMonitoringCoreTests"
        )
    ]
)
