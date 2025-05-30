import Foundation

internal enum MessageKind: Codable {
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

internal func createMessage(route: String, kind: MessageKind) -> Message<EmptyContent> {
	return Message(id: NSUUID().uuidString, route: route, kind: kind, content: EmptyContent())
}

internal func createMessage<T: Sendable>(route: String, kind: MessageKind, content: T) -> Message<T>
{
	return Message(id: NSUUID().uuidString, route: route, kind: kind, content: content)
}

internal protocol MessageBase: SendableCodable, Decodable {
	var id: String { get }
	var route: String { get }
	var kind: MessageKind { get }
}

internal struct Message<T: SendableCodable>: MessageBase, SendableCodable {
	public func toJsonString() throws -> String {
		let encoder = JSONEncoder()
		let data = try encoder.encode(self)
		return String(data: data, encoding: String.Encoding.utf8)!
	}

	var id: String
	var route: String
	var kind: MessageKind
	var content: T
}
