import XCTest

@testable import WKInterop

class WKInteropTests: XCTestCase {
	func testMessageSerialization() throws {
		// Create a message
		let route = "test/route"
		let kind = MessageKind.request
		let content: WebKitJObject? = nil  // Assuming WebKitJObject is optional
		let message = Message.from(route: route, kind: kind, content: content)

		// Serialize the message to JSON string
		let jsonString = try message.toJsonString()

		// Deserialize the JSON string back to a dictionary
		let data = jsonString.data(using: .utf8)!
		guard
			let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
				as? [String: Any]
		else {
			XCTFail("Failed to deserialize JSON string")
			return
		}

		// Assert the values
		XCTAssertEqual(jsonObject["route"] as? String, route)
		XCTAssertEqual(jsonObject["kind"] as? String, kind.toString())
		XCTAssertEqual(jsonObject["content"] as? NSNull, NSNull())  // Assuming content is nil
		XCTAssertNotNil(jsonObject["id"] as? String)  // ID should be a non-nil string
	}
}
