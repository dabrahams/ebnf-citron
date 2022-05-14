// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let CitronParser
  = Target.Dependency.product(name: "CitronParserModule", package: "citron")
let CitronLexer
  = Target.Dependency.product(  name: "CitronLexerModule", package: "citron")

let package = Package(
    name: "ebnf-citron",
    products: [
      .executable(name: "ebnf-citron", targets: ["ebnf-citron"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
      .package(url: "https://github.com/dabrahams/citron.git", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "ebnf-citron",
            dependencies: [CitronParser, CitronLexer],
            plugins: [ .plugin(name: "CitronParserGenerator", package: "citron") ]
        ),
        .testTarget(
            name: "ebnf-citronTests",
            dependencies: ["ebnf-citron", CitronParser, CitronLexer]),
    ]
)
