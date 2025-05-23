import Foundation
import IDisposable
import WebKit

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
@MainActor
internal class GenericMessageHandler: WKUserContentController, WKScriptMessageHandler,
	IAsyncDisposable
{
	required override init() {
		super.init()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}

	func dispose() async {
		self.removeAllUserScripts()
	}

	func attach(name: String, handler: @escaping (_: Message) -> Void) {
		if _onMessage != nil { return }
		_onMessage = handler
		self.add(self, name: name)
	}

	func userContentController(
		_ userContentController: WKUserContentController, didReceive message: WKScriptMessage
	) {
		do {
			let parsed = try message.parse()
			_onMessage!(parsed)
		} catch {
			print("Error handling message: \(error)")
		}
	}

	private var _onMessage: ((_: Message) -> Void)?
}
