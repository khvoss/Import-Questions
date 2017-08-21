// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "Import-Questions",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/SwiftyJSON.git", majorVersion: 16),
        .Package(url: "https://github.com/IBM-Swift/Kitura-CouchDB", majorVersion: 1, minor: 7),
        .Package(url: "https://github.com/watson-developer-cloud/swift-sdk", majorVersion: 0)
    ]
)
