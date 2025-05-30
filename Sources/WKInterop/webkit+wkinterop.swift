import Foundation
import WebKit

func convertContentToData(_ maybeContent: Any?) throws -> Data? {
	guard let content = maybeContent else {
		return nil
	}

	if content is NSNull {
		return nil
	} else if let data = content as? Data {
		return data
	} else if let jsonString = content as? String {
		return jsonString.data(using: .utf8)
	} else {
		return try JSONSerialization.data(withJSONObject: content, options: [])
	}
}

internal func parseWKMessage(_ dictionary: NSDictionary) throws -> Message<Data?> {
	guard let id = dictionary["id"] as? String else {
		throw WKInteropError.invalidMessage
	}

	guard let route = dictionary["route"] as? String else {
		throw WKInteropError.invalidMessage
	}

	guard let kindDictionary = dictionary["kind"] as? [String: Any] else {
		throw WKInteropError.invalidMessage
	}

	guard kindDictionary.keys.count == 1 else {
		throw WKInteropError.invalidMessage
	}

	guard let kindString = kindDictionary.keys.first else {
		throw WKInteropError.invalidMessage
	}

	let kind = try MessageKind.fromString(kindString)

	let content = dictionary["content"]
	let contentData = try convertContentToData(content)
	return Message(id: id, route: route, kind: kind, content: contentData)
}

extension WKScriptMessage {
	func parse() throws -> Message<Data?> {
		let dict = self.body as? NSDictionary
		if dict == nil {
			throw WKInteropError.invalidMessage
		}

		return try parseWKMessage(dict!)
	}
}
