// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ChatGPTSwift",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8)],
    products: [
        .library(
            name: "ChatGPTSwift",
            targets: ["ChatGPTSwift"]),
        .executable(
            name: "SampleApp",
            targets: ["SampleApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/alfianlosari/GPTEncoder.git", exact: "1.0.4"),
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.10.2"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.8.2"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.1.0"),
        .package(url: "https://github.com/swift-server/swift-openapi-async-http-client", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "ChatGPTSwift",
            dependencies: [
                .product(name: "GPTEncoder", package: "GPTEncoder"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession",
                    condition: .when(platforms: [
                        .iOS, .macCatalyst, .macOS, .tvOS, .visionOS, .watchOS
                        ])),
                .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client",
                    condition: .when(platforms: [.linux])
                ),
            ]
            // plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]
            ),
        .executableTarget(
            name: "SampleApp",
            dependencies: [
                "ChatGPTSwift"
            ]
        ),
        .testTarget(
            name: "ChatGPTSwiftTests",
            dependencies: ["ChatGPTSwift"]),
    ]
)
