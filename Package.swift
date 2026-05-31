// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EasyMeeting",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EasyMeeting", targets: ["EasyMeeting"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.37.0")
    ],
    targets: [
        .executableTarget(
            name: "EasyMeeting",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            path: "Sources/EasyMeeting",
            plugins: [
                .plugin(name: "SwiftProtobufPlugin", package: "swift-protobuf")
            ]
        )
    ]
)
