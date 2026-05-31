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
    targets: [
        .executableTarget(
            name: "EasyMeeting",
            path: "Sources/EasyMeeting"
        )
    ]
)
