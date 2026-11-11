import Foundation
import Testing
@testable import Retro98Settings

@Test func systemEngineUsesSupportOverrideAndFullCatalog() {
    let system = SystemEngine.make(home: URL(filePath: "/Users/t"), environment: ["RETRO98_SUPPORT_DIR": "/tmp/r98"],
                                   osMajorVersion: 27)
    #expect(system.paths.backupFile.path == "/tmp/r98/backup.plist")
    #expect(system.catalog.map(\.id) == TweakID.allCases)
}
