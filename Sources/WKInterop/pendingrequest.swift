import Cancellation
import Foundation

internal class PendingRequest {
	init(
		_ message: MessageBase, _ token: CancellationToken,
		_ onResponse: @escaping (Data?) -> Void
	) {
		_token = token
		_onResponse = onResponse
		_message = message
	}

	public func onResponse(_ obj: Data?) {
		_onResponse(obj)
	}

	public var message: MessageBase { return _message }
	public var token: CancellationToken { return _token }

	private var _message: MessageBase
	private var _token: CancellationToken
	private var _onResponse: (Data?) -> Void
}
