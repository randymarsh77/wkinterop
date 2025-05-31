import Cancellation
import IDisposable
import Scope
import WebKit

public enum WKInteropError: Error {
	case invalidMessage(String)
	case invalidMessageKindString(String)
	case unsupportedDeserialization
	case unsupportedSerialization
}

public typealias SendableCodable = Sendable & Codable

internal final class EmptyContent: SendableCodable {
	public static let instance = EmptyContent()
}

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
@MainActor
public class WKInterop: IAsyncDisposable {
	public var view: WKWebView { return _view }

	public init(
		viewFactory: (_: WKWebViewConfiguration) -> WKWebView
	) {
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

	public func request<TResponse: SendableCodable>(route: String, token: CancellationToken)
		async throws -> TResponse
	{
		return try await makeRequest(route: route, content: EmptyContent(), token: token)
	}

	public func request<TRequest: SendableCodable, TResponse: SendableCodable>(
		route: String, content: TRequest, token: CancellationToken
	) async throws -> TResponse {
		return try await makeRequest(route: route, content: content, token: token)
	}

	public func publish(route: String) throws {
		try send(createMessage(route: route, kind: .event))
	}

	public func publish<T: Encodable>(route: String, content: T) throws {
		try send(createMessage(route: route, kind: .event, content: serialize(content)))
	}

	public func registerEventHandler(route: String, handler: @Sendable @escaping () -> Void)
		-> Scope
	{
		return registerHandler(Handler(route: route, onMessage: { _ in handler() }))
	}

	public func registerEventHandler(route: String, handler: @Sendable @escaping () async -> Void)
		-> Scope
	{
		return registerHandler(Handler(route: route, onMessage: { _ in await handler() }))
	}

	public func registerEventHandler<T: SendableCodable>(
		route: String, handler: @Sendable @escaping (T) -> Void
	) -> Scope {
		return registerHandler(
			Handler(
				route: route,
				onMessage: { m in
					guard let data = m.content as? T else {
						throw WKInteropError.unsupportedDeserialization
					}
					handler(data)
				}))
	}

	public func registerEventHandler<T: SendableCodable>(
		route: String, handler: @Sendable @escaping (T) async -> Void
	) -> Scope {
		return registerHandler(
			Handler(
				route: route,
				onMessage: { m in
					guard let data = m.content as? T else {
						throw WKInteropError.unsupportedDeserialization
					}
					await handler(data)
				}))
	}

	public func registerRequestHandler<T: SendableCodable>(
		route: String, handler: @Sendable @escaping () async -> T
	)
		-> Scope
	{
		return registerHandler(
			Handler(route: route) { message in
				let result = await handler()
				let message = Message(
					id: message.id, route: route, kind: .response,
					content: result)
				try await self.send(message)
			})
	}

	public func registerRequestHandler<S: SendableCodable, T: SendableCodable>(
		route: String, handler: @Sendable @escaping (S) async -> T
	)
		-> Scope
	{
		return registerHandler(
			Handler(route: route) { m in
				guard let arg = m.content as? S else {
					throw WKInteropError.unsupportedDeserialization
				}
				let result = await handler(arg)
				let message = Message(
					id: m.id, route: route, kind: .response,
					content: result)
				try await self.send(message)
			})
	}

	private func makeRequest<TRequest: SendableCodable, TResponse: SendableCodable>(
		route: String, content: TRequest, token: CancellationToken
	)
		async throws -> TResponse
	{
		let message = createMessage(
			route: route, kind: .request, content: content)
		let response = try await withCheckedThrowingContinuation { continuation in
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

		let deserialized: TResponse = try deserialize(response!)
		return deserialized
	}

	private func registerHandler(_ handler: Handler<Data?>) -> Scope {
		synced(self) {
			_handlers.append(handler)
		}
		return Scope {
			await self.removeHandler(handler)
		}
	}

	private func removeHandler(_ handler: Handler<Data?>) {
		let i = self._handlers.firstIndex { h in handler === h }
		if i != nil {
			self._handlers.remove(at: i!)
		}
	}

	private func send<T>(_ message: Message<T>) throws {
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

	private func handle(message: Message<Data?>) async throws {
		switch message.kind {
		case .request:
			handleIncoming(request: message)
		case .response:
			handleIncoming(response: message)
		case .event:
			try await handleIncoming(event: message)
		}
	}

	private func handleIncoming(request: Message<Data?>) {
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

	private func handleIncoming(response: Message<Data?>) {
		let pending = _requests.filter({ $0.message.id == response.id }).first
		if pending != nil {
			pending!.onResponse(response.content)
			_requests = _requests.filter({ $0.message.id != response.id })
		}
	}

	private func handleIncoming(event: Message<Data?>) async throws {
		for handler in _handlers.filter({ $0.route == event.route }) {
			try await handler.onMessage(event)
		}
	}

	private var _requests = [PendingRequest]()
	private var _handlers = [Handler<Data?>]()
	private var _view: WKWebView
	private var _messageHandler: GenericMessageHandler
}

private final class Handler<T: SendableCodable>: Sendable {
	init(route: String, onMessage: @Sendable @escaping (Message<T>) async throws -> Void) {
		self.route = route
		self.onMessage = onMessage
	}

	public let route: String
	public let onMessage: @Sendable (Message<T>) async throws -> Void
}

private func synced(_ lock: Any, _ closure: () -> Void) {
	defer { objc_sync_exit(lock) }
	objc_sync_enter(lock)
	closure()
}
