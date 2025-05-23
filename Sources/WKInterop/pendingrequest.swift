import Cancellation
import Foundation

internal class PendingRequest {
	init(
		_ message: Message, _ token: CancellationToken,
		_ onResponse: @escaping (WebKitJObject?) -> Void
	) {
		_token = token
		_onResponse = onResponse
		_message = message
	}

	public func onResponse(_ obj: WebKitJObject?) {
		_onResponse(obj)
	}

	public var message: Message { return _message }
	public var token: CancellationToken { return _token }

	private var _message: Message
	private var _token: CancellationToken
	private var _onResponse: (WebKitJObject?) -> Void
}
