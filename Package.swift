// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BitcoinKit",
    products: [
        .library(name: "BitcoinKit", targets: ["BitcoinKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/zhangliugang/ripemd160", .branch("master")),
//        .package(url: "https://github.com/Boilertalk/secp256k1.swift", from: "0.1.0"),
        .package(url: "https://github.com/zhangliugang/secp256k1.swift", .branch("main")),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.5.1")
    ],
    targets: [
        .target(
            name: "BitcoinKit",
            dependencies: [.product(name: "secp256k1", package: "secp256k1.swift"), "ripemd160", "CryptoSwift"]
        ),
        .testTarget(
            name: "BitcoinKitTests",
            dependencies: ["BitcoinKit"],
            resources: [
                .copy("Resources/transaction.json")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
