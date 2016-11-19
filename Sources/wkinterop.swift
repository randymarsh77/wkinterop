import WebKit
import Async
import Cancellation
import IDisposable
import Scope

public enum WKInteropError : Error
{
	case InvalidMessage
	case InvalidMessageKindString
	case UnsupportedDeserialization
	case UnsupportedSerialization
}

public enum WebKitJObject
{
	case Dictionary(NSDictionary)
	case Array(NSArray)
	case Number(NSNumber)
	case String(NSString)
	case Date(NSDate)
	case Null
}

public protocol WebKitJObjectSerializer
{
	func serialize<T>(_ obj: T) throws -> WebKitJObject
	func deserialize<T>(_ obj: WebKitJObject) throws -> T
}

public class WKInterop : IDisposable
{
	public var view: WKWebView { return _view }

	public init(serializer: WebKitJObjectSerializer, viewFactory: (_: WKWebViewConfiguration) -> WKWebView) {
		_serializer = serializer
		_messageHandler = GenericMessageHandler()
		let config = WKWebViewConfiguration()
		config.userContentController = _messageHandler

		_view = viewFactory(config)
		_messageHandler.attach(name: "wkinterop") { message in
			self.handle(message: message)
		}
	}

	public func dispose() {
		_messageHandler.dispose()
	}

	public func request<T>(route: String, token: CancellationToken) -> Task<T> {
		return makeRequest(route: route, content: nil, token: token)
	}

	public func request<S, T>(route: String, content: S, token: CancellationToken) -> Task<T> {
		return makeRequest(route: route, content: serialize(content), token: token)
	}

	public func publish(route: String) -> () {
		send(Message.From(route: route, kind: .Event))
	}

	public func publish<T>(route: String, content: T) -> () {
		send(Message.From(route: route, kind: .Event, content: serialize(content)))
	}

	public func registerEventHandler(route: String, handler: @escaping () -> ()) -> Scope {
		return registerHandler(Handler(route: route, onMessage: { _ in handler() }))
	}

	public func registerEventHandler<T>(route: String, handler: @escaping (T) -> ()) -> Scope {
		return registerHandler(Handler(route: route, onMessage: { m in
			handler(self.deserialize(m.content!))
		}))
	}

	public func registerRequestHandler<T>(route: String, handler: @escaping () -> (Task<T>)) -> Scope {
		return registerHandler(Handler(route: route) { message in
			let result = await (handler())
			DispatchQueue.main.async {
				self.send(Message(id: message.id, route: route, kind: .Response, content: self.serialize(result)))
			}
		})
	}

	public func registerRequestHandler<S, T>(route: String, handler: @escaping (S) -> (Task<T>)) -> Scope {
		return registerHandler(Handler(route: route) { message in
			let arg: S = self.deserialize(message.content!)
			let result = await (handler(arg))
			DispatchQueue.main.async {
				self.send(Message(id: message.id, route: route, kind: .Response, content: self.serialize(result)))
			}
		})
	}

	private func makeRequest<T>(route: String, content: WebKitJObject?, token: CancellationToken) -> Task<T> {
		return async { (task: Task<T>) in
			var message = Message.From(route: route, kind: .Request)
			message.content = content
			var result: T? = nil
			let pending = PendingRequest(message, token) { r in
				let deserialized: T = self.deserialize(r!)
				result = deserialized
				Async.Wake(task)
			}
			self._requests.append(pending)
			DispatchQueue.main.async {
				self.send(message)
			}
			Async.Suspend()
			return result!;
		}
	}

	private func registerHandler(_ handler: Handler) -> Scope {
		synced(self) {
			_handlers.append(handler)
		}
		return Scope {
			synced(self) {
				let i = self._handlers.index { h in handler === h }
				if (i != nil) {
					self._handlers.remove(at: i!)
				}
			}
		}
	}

	private func send(_ message: Message) {
		switch message.kind {
		case .Event:
			_view.evaluateJavaScript("window.wkinterop._handleEvent(\(message.toJsonString()));") { (result, error) in }
			break
		case .Request:
			_view.evaluateJavaScript("window.wkinterop._handleRequest(\(message.toJsonString()));") { (result, error) in }
			break
		case .Response:
			_view.evaluateJavaScript("window.wkinterop._handleResponse(\(message.toJsonString()));") { (result, error) in }
			break
		}
	}

	private func handle(message: Message) {
		switch message.kind {
		case .Request:
			handleIncoming(request: message)
			break
		case .Response:
			handleIncoming(response: message)
			break
		case .Event:
			handleIncoming(event: message)
			break
		}
	}

	private func handleIncoming(request: Message) {
		let handler = _handlers.filter({ $0.route == request.route }).first
		if (handler == nil) {
			return
		}

		DispatchQueue.global(qos: .default).async {
			handler!.onMessage(request)
		}
	}

	private func handleIncoming(response: Message) {
		let pending = _requests.filter({ $0.message.id == response.id }).first
		if (pending != nil) {
			pending!.onResponse(response.content)
			_requests = _requests.filter({ $0.message.id != response.id })
		}
	}

	private func handleIncoming(event: Message) {
		for handler in _handlers.filter({ $0.route == event.route }) {
			handler.onMessage(event)
		}
	}

	private func serialize<T>(_ obj: T) -> WebKitJObject? {
		if (T.self == NSDictionary.self ||
			T.self == NSArray.self ||
			T.self == NSDate.self ||
			T.self == NSString.self ||
			T.self == NSNumber.self) {
			return WrapJObject(obj)
		}

		return try! _serializer.serialize(obj)
	}

	private func deserialize<T>(_ obj: WebKitJObject) -> T {
		if (T.self == NSDictionary.self ||
			T.self == NSArray.self ||
			T.self == NSDate.self ||
			T.self == NSString.self ||
			T.self == NSNumber.self) {
			return UnwrapJObject(obj) as! T
		}
		
		return try! _serializer.deserialize(obj)
	}

	private var _requests = Array<PendingRequest>()
	private var _handlers = Array<Handler>()
	private var _view: WKWebView
	private var _serializer: WebKitJObjectSerializer
	private var _messageHandler: GenericMessageHandler
}

private class Handler
{
	init(route: String, onMessage: @escaping (Message) -> ()) {
		self.route = route
		self.onMessage = onMessage
	}

	public var route: String
	public var onMessage: (Message) -> ()
}

private func synced(_ lock: Any, _ closure: () -> ()) {
	defer { objc_sync_exit(lock) }
	objc_sync_enter(lock)
	closure()
}
