// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Grayson's Helper",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .app(
            name: "Grayson's Helper",
            targets: ["Grayson's Helper"]),
    ],
        dependencies: [
  .package(url: "https://github.com/CoreOffice/CoreXLSX.git",
           .upToNextMinor(from: "0.14.1"))
],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Grayson's Helper",
            dependencies: ["CoreXLSX"]),
        .testTarget(
            name: "Grayson's HelperTests",
            dependencies: ["Grayson's Helper"]),
    ]

)
