import XCTest

@testable import WKInterop

struct TestContent: Codable {
	let key: String
	let value: Int
}

class WKInteropTests: XCTestCase {
	func testMessageSerialization() throws {
		// Create a message
		let route = "test/route"
		let kind = MessageKind.request
		let message = createMessage(route: route, kind: kind)

		// Serialize the message to JSON string
		let jsonString = try message.toJsonString()
		let jsonData = jsonString.data(using: .utf8)!

		// Test deserialize method
		let m1: Message<EmptyContent> = try Message<EmptyContent>.fromJsonData(jsonData)

		XCTAssertEqual(m1.route, route)
		XCTAssertEqual(m1.kind, kind)
		XCTAssertEqual(m1.id, message.id)

		// Simulate value from webview
		guard
			let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
				as? NSDictionary
		else {
			XCTFail("Failed to deserialize JSON string")
			return
		}

		let m2 = try parseWKMessage(jsonObject)

		XCTAssertEqual(m2.id, message.id)
		XCTAssertEqual(m2.kind, kind)
		XCTAssertEqual(m2.route, route)
	}

	func testMessageSerializationWithEncodableContent() throws {
		let content = TestContent(key: "testKey", value: 42)

		// Create a message with encodable content
		let route = "test/route"
		let kind = MessageKind.request
		let message = createMessage(route: route, kind: kind, content: content)

		// Serialize the message to JSON string
		let jsonString = try message.toJsonString()
		let jsonData = jsonString.data(using: .utf8)!

		// Simulate value from webview
		guard
			let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
				as? NSDictionary
		else {
			XCTFail("Failed to deserialize JSON string")
			return
		}

		let parsed = try parseWKMessage(jsonObject as NSDictionary)

		// Assert the values
		XCTAssertEqual(parsed.route, route)
		XCTAssertEqual(parsed.kind, kind)
		XCTAssertEqual(parsed.id, message.id)

		guard let contentData = parsed.content else {
			XCTFail("Content should not be nil")
			return
		}

		let decodedContent = try JSONDecoder().decode(TestContent.self, from: contentData)
		XCTAssertEqual(decodedContent.key, content.key)
		XCTAssertEqual(decodedContent.value, content.value)
	}
}
