// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MarkdownReader",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MarkdownReader", targets: ["MarkdownReaderApp"])
    ],
    targets: [
        .executableTarget(
            name: "MarkdownReaderApp",
            path: "Sources/MarkdownReaderApp"
        ),
        .testTarget(
            name: "MarkdownReaderAppTests",
            dependencies: ["MarkdownReaderApp"],
            path: "Tests/MarkdownReaderAppTests"
        )
    ]
)
