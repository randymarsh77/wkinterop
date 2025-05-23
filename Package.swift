// swift-tools-version:6.0
import PackageDescription

let package = Package(
	name: "WKInterop",
	products: [
		.library(
			name: "WKInterop",
			targets: ["WKInterop"]
		)
	],
	dependencies: [
		.package(url: "https://github.com/randymarsh77/cancellation", branch: "master"),
		.package(url: "https://github.com/randymarsh77/idisposable", branch: "master"),
		.package(url: "https://github.com/randymarsh77/scope", branch: "master"),
	],
	targets: [
		.target(
			name: "WKInterop",
			dependencies: [
				.product(name: "Cancellation", package: "Cancellation"),
				.product(name: "IDisposable", package: "IDisposable"),
				.product(name: "Scope", package: "Scope"),
			]
		)
	]
)
