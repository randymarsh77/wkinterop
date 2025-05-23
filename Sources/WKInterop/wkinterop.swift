import Cancellation
import IDisposable
import Scope
import WebKit

public enum WKInteropError: Error {
	case invalidMessage
	case invalidMessageKindString
	case unsupportedDeserialization
	case unsupportedSerialization
}

public enum WebKitJObject: @unchecked Sendable {
	case dictionary(NSDictionary)
	case array(NSArray)
	case number(NSNumber)
	case string(NSString)
	case date(NSDate)
	case null
}

public protocol WebKitJObjectSerializer {
	func serialize<T>(_ obj: T) throws -> WebKitJObject
	func deserialize<T>(_ obj: WebKitJObject) throws -> T
}

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
@MainActor
public class WKInterop: IAsyncDisposable {
	public var view: WKWebView { return _view }

	public init(
		serializer: WebKitJObjectSerializer, viewFactory: (_: WKWebViewConfiguration) -> WKWebView
	) {
		_serializer = serializer
		_messageHandler = GenericMessageHandler()
		let config = WKWebViewConfiguration()
		config.userContentController = _messageHandler

		_view = viewFactory(config)
		_messageHandler.attach(name: "wkinterop") { message in
			Task {
				try await self.handle(message: message)
			}
		}
	}

	public func dispose() async {
		await _messageHandler.dispose()
	}

	public func request<T>(route: String, token: CancellationToken) async throws -> T {
		return try await makeRequest(route: route, content: nil, token: token)
	}

	public func request<S, T>(route: String, content: S, token: CancellationToken) async throws -> T
	{
		return try await makeRequest(route: route, content: try serialize(content), token: token)
	}

	public func publish(route: String) throws {
		try send(Message.from(route: route, kind: .event))
	}

	public func publish<T>(route: String, content: T) throws {
		try send(Message.from(route: route, kind: .event, content: serialize(content)))
	}

	public func registerEventHandler(route: String, handler: @Sendable @escaping () -> Void)
		-> Scope
	{
		return registerHandler(Handler(route: route, onMessage: { _ in handler() }))
	}

	public func registerEventHandler<T: Sendable>(
		route: String, handler: @Sendable @escaping (T) -> Void
	) -> Scope {
		return registerHandler(
			Handler(
				route: route,
				onMessage: { m in
					try await handler(self.deserialize(m.content!))
				}))
	}

	public func registerRequestHandler<T>(
		route: String, handler: @Sendable @escaping () async -> (T)
	)
		-> Scope
	{
		return registerHandler(
			Handler(route: route) { message in
				let result = await handler()
				let serializedResult = try await self.serialize(result)
				let message = Message(
					id: message.id, route: route, kind: .response,
					content: serializedResult)
				try await self.send(message)
			})
	}

	public func registerRequestHandler<S: Sendable, T>(
		route: String, handler: @Sendable @escaping (S) async -> (T)
	)
		-> Scope
	{
		return registerHandler(
			Handler(route: route) { message in
				let arg: S = try await self.deserialize(message.content!)
				let result = await handler(arg)
				let seriaizedResult = try await self.serialize(result)
				let message = Message(
					id: message.id, route: route, kind: .response,
					content: seriaizedResult)
				try await self.send(message)
			})
	}

	private func makeRequest<T>(route: String, content: WebKitJObject?, token: CancellationToken)
		async throws -> T
	{
		var message = Message.from(route: route, kind: .request)
		message.content = content

		let r = try await withCheckedThrowingContinuation { continuation in
			let pending = PendingRequest(message, token) { r in
				continuation.resume(returning: r)
			}
			self._requests.append(pending)
			do {
				try send(message)
			} catch {
				continuation.resume(throwing: error)
			}
		}

		let deserialized: T = try deserialize(r!)
		return deserialized
	}

	private func registerHandler(_ handler: Handler) -> Scope {
		synced(self) {
			_handlers.append(handler)
		}
		return Scope {
			await self.removeHandler(handler)
		}
	}

	private func removeHandler(_ handler: Handler) {
		let i = self._handlers.firstIndex { h in handler === h }
		if i != nil {
			self._handlers.remove(at: i!)
		}
	}

	private func send(_ message: Message) throws {
		let json = try message.toJsonString()
		let function =
			switch message.kind {
			case .event:
				"_handleEvent"
			case .request:
				"_handleRequest"
			case .response:
				"_handleResponse"
			}

		_view.evaluateJavaScript("window.wkinterop.\(function)(\(json));") { (_, _) in }
	}

	private func handle(message: Message) async throws {
		switch message.kind {
		case .request:
			handleIncoming(request: message)
		case .response:
			handleIncoming(response: message)
		case .event:
			try await handleIncoming(event: message)
		}
	}

	private func handleIncoming(request: Message) {
		let handler = _handlers.filter({ $0.route == request.route }).first
		if handler == nil {
			return
		}

		DispatchQueue.global(qos: .default).async {
			Task {
				try await handler!.onMessage(request)
			}
		}
	}

	private func handleIncoming(response: Message) {
		let pending = _requests.filter({ $0.message.id == response.id }).first
		if pending != nil {
			pending!.onResponse(response.content)
			_requests = _requests.filter({ $0.message.id != response.id })
		}
	}

	private func handleIncoming(event: Message) async throws {
		for handler in _handlers.filter({ $0.route == event.route }) {
			try await handler.onMessage(event)
		}
	}

	private func serialize<T>(_ obj: T) throws -> WebKitJObject? {
		if T.self == NSDictionary.self || T.self == NSArray.self || T.self == NSDate.self
			|| T.self == NSString.self || T.self == NSNumber.self
		{
			return wrapJObject(obj)
		}
		if T.self == String.self, let string = obj as? String {
			return wrapJObject(string)
		}

		return try _serializer.serialize(obj)
	}

	private func deserialize<T>(_ obj: WebKitJObject) throws -> T {
		if T.self == NSDictionary.self || T.self == NSArray.self || T.self == NSDate.self
			|| T.self == NSString.self || T.self == NSNumber.self
		{
			if let t = unwrapJObject(obj) as? T {
				return t
			}
		}

		return try _serializer.deserialize(obj)
	}

	private var _requests = [PendingRequest]()
	private var _handlers = [Handler]()
	private var _view: WKWebView
	private var _serializer: WebKitJObjectSerializer
	private var _messageHandler: GenericMessageHandler
}

private final class Handler: Sendable {
	init(route: String, onMessage: @Sendable @escaping (Message) async throws -> Void) {
		self.route = route
		self.onMessage = onMessage
	}

	public let route: String
	public let onMessage: @Sendable (Message) async throws -> Void
}

private func synced(_ lock: Any, _ closure: () -> Void) {
	defer { objc_sync_exit(lock) }
	objc_sync_enter(lock)
	closure()
}
