import Foundation
import WebKit

extension WKScriptMessage {
	func parse() throws -> Message {
		let dict = self.body as? NSDictionary
		if dict == nil {
			throw WKInteropError.invalidMessage
		}

		guard let id = dict!["id"] as? String else {
			throw WKInteropError.invalidMessage
		}

		guard let route = dict!["route"] as? String else {
			throw WKInteropError.invalidMessage
		}

		guard let kindString = dict!["kind"] as? String else {
			throw WKInteropError.invalidMessage
		}

		let kind = try MessageKind.fromString(kindString)

		let content = dict!["content"]
		return Message(id: id, route: route, kind: kind, content: wrapJObject(content))
	}
}
