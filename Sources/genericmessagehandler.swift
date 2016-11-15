import Foundation
import WebKit
import IDisposable

internal class GenericMessageHandler : WKUserContentController, WKScriptMessageHandler, IDisposable
{
	required override init() {
		super.init()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}

	func dispose() {
		self.removeAllUserScripts()
	}

	func attach(name: String, handler: @escaping (_: Message) -> ()) {
		if (_onMessage != nil) { return }
		_onMessage = handler
		self.add(self, name: name)
	}

	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage)
	{
		_onMessage!(try! message.parse())
	}

	private var _onMessage: ((_: Message) -> ())?
}
