// swift-tools-version:5.1
import PackageDescription

let package = Package(
	name: "WKInterop",
	products: [
		.library(
			name: "WKInterop",
			targets: ["WKInterop"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/randymarsh77/async", .branch("master")),
		.package(url: "https://github.com/randymarsh77/cancellation", .branch("master")),
		.package(url: "https://github.com/randymarsh77/idisposable", .branch("master")),
		.package(url: "https://github.com/randymarsh77/scope", .branch("master")),
	],
	targets: [
		.target(
			name: "WKInterop",
			dependencies: ["Async", "Cancellation", "IDisposable", "Scope"]
		),
	]
)
