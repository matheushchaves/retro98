import Foundation
import Testing
@testable import Retro98Settings

let testDomain = PreferenceDomain.app("io.github.matheushchaves.retro98.tests")

@Test func cfStoreWritesReadsAndRemoves() throws {
    let store = CFPreferenceStore()
    let key = PreferenceKey(domain: testDomain, name: "probe-\(UUID().uuidString)")
    try store.write(.dictionary(["alpha": .double(1), "red": .int(0)]), for: key)
    #expect(store.value(for: key) == .dictionary(["alpha": .double(1), "red": .int(0)]))
    try store.write(nil, for: key)
    #expect(store.value(for: key) == nil)
}

@Test func inMemoryStoreDeniesConfiguredKeysWithoutChangingThem() {
    let key = PreferenceKey(domain: .global, name: "X")
    let store = InMemoryPreferenceStore([key: .int(1)], deniedKeys: [key])
    #expect(throws: PreferenceError.writeDenied(key)) { try store.write(.int(2), for: key) }
    #expect(store.value(for: key) == .int(1))
}

@Test func inMemoryStoreWritesAndRemoves() throws {
    let key = PreferenceKey(domain: .global, name: "Y")
    let store = InMemoryPreferenceStore()
    try store.write(.string("Always"), for: key)
    #expect(store.snapshot == [key: .string("Always")])
    try store.write(nil, for: key)
    #expect(store.snapshot.isEmpty)
}
