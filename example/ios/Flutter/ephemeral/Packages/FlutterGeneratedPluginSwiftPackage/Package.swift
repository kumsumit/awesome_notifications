// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "awesome_notifications", path: "../.packages/awesome_notifications"),
        .package(name: "device_info_plus", path: "../.packages/device_info_plus-d717c2694eb655595d9de44286483c33334a701b"),
        .package(name: "firebase_core", path: "../.packages/firebase_core-b13259e973e2c0037b04003a8011b0b499036bfb"),
        .package(name: "firebase_messaging", path: "../.packages/firebase_messaging-64e40426bb9dd1abcc62f3d65e0260e6a8839656"),
        .package(name: "fluttertoast", path: "../.packages/fluttertoast-db24aa96199b0e51bea3e8648b9ef124d71fd528"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-9cc1319b50ee22bf03c96627c0cd056f89f22baf"),
        .package(name: "url_launcher_ios", path: "../.packages/url_launcher_ios-6bee057709a4d0eeae60a9169101870c7ba14490"),
        .package(name: "vibration", path: "../.packages/vibration-9a885c56151886a63dd933a87ea34c3f3289eeca"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "awesome-notifications", package: "awesome_notifications"),
                .product(name: "device-info-plus", package: "device_info_plus"),
                .product(name: "firebase-core", package: "firebase_core"),
                .product(name: "firebase-messaging", package: "firebase_messaging"),
                .product(name: "fluttertoast", package: "fluttertoast"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "vibration", package: "vibration"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
