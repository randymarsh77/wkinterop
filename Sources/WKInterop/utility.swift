import Foundation

internal func wrapJObject(_ obj: Any?) -> WebKitJObject {
	if obj == nil {
		return .null
	}

	if let dictionary = obj as? NSDictionary {
		return .dictionary(dictionary)
	} else if let array = obj as? NSArray {
		return .array(array)
	} else if let number = obj as? NSNumber {
		return .number(number)
	} else if let string = obj as? NSString {
		return .string(string)
	} else if let date = obj as? NSDate {
		return .date(date)
	} else {
		return .null
	}
}

internal func unwrapJObject(_ obj: WebKitJObject?) -> Any {
	if obj == nil {
		return NSNull()
	}

	switch obj!
	{
	case .array(let array):
		return array
	case .date(let date):
		return date
	case .dictionary(let dictionary):
		return dictionary
	case .number(let number):
		return number
	case .string(let string):
		return string
	case .null:
		return NSNull()
	}
}
