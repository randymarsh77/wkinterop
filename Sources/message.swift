import Foundation

internal enum MessageKind
{
	case Request
	case Response
	case Event

	public static func FromString(_ string: String) throws -> MessageKind {
		switch string {
		case "event":
			return .Event
		case "request":
			return .Request
		case "response":
			return .Response
		default:
			throw WKInteropError.InvalidMessageKindString
		}
	}

	public func ToString() -> String {
		switch self {
		case .Event:
			return "event"
		case .Request:
			return "request"
		case .Response:
			return "response"
		}
	}
}

internal struct Message
{
	public static func From(route: String, kind: MessageKind) -> Message {
		return Message(id: NSUUID().uuidString, route: route, kind: kind, content: nil)
	}

	public static func From(route: String, kind: MessageKind, content: WebKitJObject?) -> Message {
		return Message(id: NSUUID().uuidString, route: route, kind: kind, content: content)
	}

	public func toJsonString() -> String
	{
		let dictionary = [
			"id": id,
			"route": route,
			"kind": "event",
			"content" : CastJObject(content),
			] as [String : Any]
		let data = try! JSONSerialization.data(withJSONObject: dictionary, options: JSONSerialization.WritingOptions(rawValue: 0))
		return String(data: data, encoding: String.Encoding.utf8)!
	}

	var id: String
	var route: String
	var kind: MessageKind
	var content: WebKitJObject?
}
