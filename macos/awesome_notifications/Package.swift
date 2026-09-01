// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "awesome_notifications",
    platforms: [
        .macOS("10.14")
    ],
    products: [
        .library(
            name: "awesome-notifications",
            targets: ["awesome_notifications"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "awesome_notifications",
            dependencies: [
                .product(
                    name: "FlutterFramework",
                    package: "FlutterFramework"
                )
            ]
        )
    ]
)
