import Foundation

/// A typed preference value that keeps the exact property-list type it was read with,
/// so a backed-up original can be written back unchanged (an `int 1` never becomes `true`).
public enum PreferenceValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case data(Data)
    case date(Date)
    case array([PreferenceValue])
    case dictionary([String: PreferenceValue])

    /// Converts a CoreFoundation property-list object. Returns nil for unsupported types.
    public init?(propertyList: Any) {
        let object = propertyList as AnyObject
        // CFBoolean must be checked before NSNumber: both bridge to NSNumber.
        if CFGetTypeID(object) == CFBooleanGetTypeID() {
            self = .bool(CFBooleanGetValue(unsafeDowncast(object, to: CFBoolean.self)))
        } else if let number = object as? NSNumber {
            self = CFNumberIsFloatType(number as CFNumber) ? .double(number.doubleValue) : .int(number.intValue)
        } else if let string = object as? String {
            self = .string(string)
        } else if let data = object as? Data {
            self = .data(data)
        } else if let date = object as? Date {
            self = .date(date)
        } else if let array = object as? [Any] {
            let values = array.compactMap(PreferenceValue.init(propertyList:))
            guard values.count == array.count else { return nil }
            self = .array(values)
        } else if let dictionary = object as? [String: Any] {
            let values = dictionary.compactMapValues(PreferenceValue.init(propertyList:))
            guard values.count == dictionary.count else { return nil }
            self = .dictionary(values)
        } else {
            return nil
        }
    }

    /// The CoreFoundation property-list object for this value.
    public var propertyList: Any {
        switch self {
        case .bool(let value): return (value ? kCFBooleanTrue : kCFBooleanFalse) as Any
        case .int(let value): return NSNumber(value: value)
        case .double(let value): return NSNumber(value: value)
        case .string(let value): return value as NSString
        case .data(let value): return value as NSData
        case .date(let value): return value as NSDate
        case .array(let values): return values.map(\.propertyList) as NSArray
        case .dictionary(let values): return values.mapValues(\.propertyList) as NSDictionary
        }
    }
}
