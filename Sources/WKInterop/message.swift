import Foundation

internal enum MessageKind {
	case request
	case response
	case event

	public static func fromString(_ string: String) throws -> MessageKind {
		switch string {
		case "event":
			return .event
		case "request":
			return .request
		case "response":
			return .response
		default:
			throw WKInteropError.invalidMessageKindString
		}
	}

	public func toString() -> String {
		switch self {
		case .event:
			return "event"
		case .request:
			return "request"
		case .response:
			return "response"
		}
	}
}

internal struct Message: Sendable {
	public static func from(route: String, kind: MessageKind) -> Message {
		return Message(id: NSUUID().uuidString, route: route, kind: kind, content: nil)
	}

	public static func from(route: String, kind: MessageKind, content: WebKitJObject?) -> Message {
		return Message(id: NSUUID().uuidString, route: route, kind: kind, content: content)
	}

	public func toJsonString() throws -> String {
		let dictionary =
			[
				"id": id,
				"route": route,
				"kind": kind.toString(),
				"content": unwrapJObject(content),
			] as [String: Any]
		let data = try JSONSerialization.data(
			withJSONObject: dictionary, options: JSONSerialization.WritingOptions(rawValue: 0))
		return String(data: data, encoding: String.Encoding.utf8)!
	}

	var id: String
	var route: String
	var kind: MessageKind
	var content: WebKitJObject?
}
