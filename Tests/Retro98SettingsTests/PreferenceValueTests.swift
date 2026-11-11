import Foundation
import Testing
@testable import Retro98Settings

@Test func roundTripsScalarsKeepingTypes() {
    let values: [PreferenceValue] = [
        .bool(true), .int(1), .int(-1), .double(1.0), .string("Always"),
        .data(Data([1, 2])), .date(Date(timeIntervalSince1970: 0)),
    ]
    for value in values {
        #expect(PreferenceValue(propertyList: value.propertyList) == value)
    }
}

@Test func distinguishesBoolIntAndDouble() {
    #expect(PreferenceValue(propertyList: kCFBooleanTrue as Any) == .bool(true))
    #expect(PreferenceValue(propertyList: NSNumber(value: 1)) == .int(1))
    #expect(PreferenceValue(propertyList: NSNumber(value: 0.5)) == .double(0.5))
    #expect(PreferenceValue(propertyList: PreferenceValue.bool(true).propertyList) != .int(1))
}

@Test func roundTripsNestedCollections() {
    let value = PreferenceValue.dictionary([
        "alpha": .double(1), "red": .int(0), "list": .array([.string("a")]),
    ])
    #expect(PreferenceValue(propertyList: value.propertyList) == value)
}

@Test func rejectsUnsupportedObjects() {
    #expect(PreferenceValue(propertyList: NSObject()) == nil)
}
