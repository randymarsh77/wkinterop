import Foundation

internal func WrapJObject(_ obj: Any?) -> WebKitJObject
{
	if (obj == nil) {
		return .Null
	}

	if (obj is NSDictionary) {
		return .Dictionary(obj as! NSDictionary)
	} else if (obj is NSArray) {
		return .Array(obj as! NSArray)
	} else if (obj is NSNumber) {
		return .Number(obj as! NSNumber)
	} else if (obj is NSString) {
		return .String(obj as! NSString)
	} else if (obj is NSDate) {
		return .Date(obj as! NSDate)
	} else {
		return .Null
	}
}

internal func UnwrapJObject(_ obj: WebKitJObject?) -> Any
{
	if (obj == nil) {
		return NSNull()
	}

	switch obj!
	{
	case .Array(let array):
		return array
	case .Date(let date):
		return date
	case .Dictionary(let dictionary):
		return dictionary
	case .Number(let number):
		return number
	case .String(let string):
		return string
	case .Null:
		return NSNull()
	}
}
