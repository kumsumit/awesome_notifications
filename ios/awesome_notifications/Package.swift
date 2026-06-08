// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "awesome_notifications",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "awesome-notifications", targets: ["awesome_notifications"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // IosAwnCore is a standalone (non-Flutter) Swift package, so it must be referenced by
        // its released tag — Flutter symlinks plugins into ephemeral/Packages/.packages, which
        // breaks relative paths to non-plugin packages. For local validation before a tag is
        // published, temporarily replace this with an absolute `path:` to the IosAwnCore repo.
        .package(name: "IosAwnCore", path: "/Users/rafaelsetragni/Development/Repositories/Plugins/IosAwnCore"),
    ],
    targets: [
        .target(
            name: "awesome_notifications",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "IosAwnCore", package: "IosAwnCore"),
            ]
        )
    ]
)
