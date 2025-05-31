import Foundation

internal func serialize<T>(_ obj: T) throws -> Data where T: Encodable {
	return try JSONSerialization.data(
		withJSONObject: obj, options: JSONSerialization.WritingOptions(rawValue: 0))
}

internal func deserialize<T>(_ obj: Data) throws -> T where T: Decodable {
	let decoder = JSONDecoder()

	guard let result = try? decoder.decode(T.self, from: obj) else {

		if let raw = String(data: obj, encoding: .utf8) {
			throw WKInteropError.unsupportedDeserialization("Could not deserialize \(T.self) from:\n\(raw)")
		}
		throw WKInteropError.unsupportedDeserialization("Could not deserialize \(T.self) from: ???")
	}

	return result
}
