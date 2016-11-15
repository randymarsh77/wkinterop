import PackageDescription

let package = Package(
    name: "WKInterop",
    dependencies: [
		.Package(url: "https://github.com/randymarsh77/async", majorVersion: 1),
		.Package(url: "https://github.com/randymarsh77/cancellation", majorVersion: 1),
		.Package(url: "https://github.com/randymarsh77/idisposable", majorVersion: 1),
		.Package(url: "https://github.com/randymarsh77/scope", majorVersion: 1),
	]
)
