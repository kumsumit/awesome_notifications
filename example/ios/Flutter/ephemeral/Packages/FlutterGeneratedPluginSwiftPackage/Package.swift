// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "vibration", path: "../.packages/vibration-9a885c56151886a63dd933a87ea34c3f3289eeca"),
        .package(name: "device_info_plus", path: "../.packages/device_info_plus-6c7da3a509e79af5385ecd5856abcf07d1d07e9c"),
        .package(name: "url_launcher_ios", path: "../.packages/url_launcher_ios-6bee057709a4d0eeae60a9169101870c7ba14490"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-9cc1319b50ee22bf03c96627c0cd056f89f22baf"),
        .package(name: "fluttertoast", path: "../.packages/fluttertoast-db24aa96199b0e51bea3e8648b9ef124d71fd528"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "vibration", package: "vibration"),
                .product(name: "device-info-plus", package: "device_info_plus"),
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "fluttertoast", package: "fluttertoast"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
