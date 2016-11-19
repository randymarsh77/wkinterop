import Foundation
import WebKit

internal extension WKScriptMessage
{
	func parse() throws -> Message {
		let dict = self.body as? NSDictionary
		if (dict == nil) {
			throw WKInteropError.InvalidMessage
		}

		let id = dict!["id"] as! String
		let route = dict!["route"] as! String
		let content = dict!["content"]
		let kind = try MessageKind.FromString(dict!["kind"] as! String)
		return Message(id: id, route: route, kind: kind, content: WrapJObject(content))
	}
}
