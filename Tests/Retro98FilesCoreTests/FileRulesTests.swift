import Foundation
import Testing
@testable import Retro98FilesCore

private let pt = ["pt-BR"], en = ["en"]

@Test func copyNamesFollowFinder() {
    let photo = URL(filePath: "/T/foto.jpg")
    #expect(FileNames.copyName(for: photo, isFolder: false, existing: ["foto.jpg"], languages: pt) == "foto cópia.jpg")
    #expect(FileNames.copyName(for: photo, isFolder: false, existing: ["foto.jpg", "foto cópia.jpg"], languages: pt) == "foto cópia 2.jpg")
    #expect(FileNames.copyName(for: URL(filePath: "/T/v1.2"), isFolder: true, existing: ["v1.2"], languages: pt) == "v1.2 cópia")
    #expect(FileNames.copyName(for: URL(filePath: "/T/Leia-me"), isFolder: false, existing: ["Leia-me"], languages: pt) == "Leia-me cópia")
    #expect(FileNames.copyName(for: URL(filePath: "/T/Calc.app"), isFolder: false, existing: ["Calc.app"], languages: pt) == "Calc cópia.app")
    #expect(FileNames.copyName(for: URL(filePath: "/T/photo.jpg"), isFolder: false, existing: ["photo.jpg"], languages: en) == "photo copy.jpg")
}

@Test func newFolderNamesCount() {
    #expect(FileNames.newFolderName(existing: [], languages: pt) == "Nova pasta")
    #expect(FileNames.newFolderName(existing: ["Nova pasta"], languages: pt) == "Nova pasta (2)")
    #expect(FileNames.newFolderName(existing: ["Nova pasta", "Nova pasta (2)"], languages: pt) == "Nova pasta (3)")
    #expect(FileNames.newFolderName(existing: [], languages: en) == "New Folder")
}

@Test func availableNamesCountUp() {
    #expect(FileNames.available("a.txt", isFolder: false, existing: []) == "a.txt")
    #expect(FileNames.available("a.txt", isFolder: false, existing: ["a.txt"]) == "a 2.txt")
    #expect(FileNames.available("a.txt", isFolder: false, existing: ["a.txt", "a 2.txt"]) == "a 3.txt")
    #expect(FileNames.available("v1.2", isFolder: true, existing: ["v1.2"]) == "v1.2 2")
}

@Test func renameRules() {
    func check(_ original: String, _ typed: String, folder: Bool = false) -> RenameCheck {
        RenameRules.check(original: original, typed: typed, isFolder: folder, languages: pt)
    }
    #expect(check("a.txt", "a.txt") == .unchanged)
    #expect(check("a.txt", "   ") == .unchanged)
    #expect(check("a.txt", " b.txt ") == .accept("b.txt"))
    #expect(check("a.txt", "A.txt") == .accept("A.txt"))
    #expect(check("Relato\u{301}rio.txt", "Relat\u{F3}rio.txt") == .unchanged)
    #expect(check("a.txt", "b/c") == .invalid(ExplorerText.nameCantContainSeparators(pt)))
    #expect(check("a.txt", "b:c") == .invalid(ExplorerText.nameCantContainSeparators(pt)))
    #expect(check("a.txt", "..") == .invalid(ExplorerText.invalidName(pt)))
    #expect(check("a.txt", String(repeating: "a", count: 256)) == .invalid(ExplorerText.nameTooLong(pt)))
    #expect(check("a.txt", "a.md") == .confirmExtensionChange(from: ".txt", to: ".md"))
    #expect(check("a.txt", "a") == .confirmExtensionChange(from: ".txt", to: ""))
    #expect(check("a.txt", "a.TXT") == .accept("a.TXT"))
    #expect(check("Fotos", "Fotos.old", folder: true) == .accept("Fotos.old"))
    #expect(check("a.txt", ".a.txt") == .confirmHidden(".a.txt"))
}

@Test func dropRules() {
    let a = URL(filePath: "/A"), file = URL(filePath: "/A/x.txt"), sub = URL(filePath: "/A/Sub"), b = URL(filePath: "/B")
    func op(_ sources: [URL], _ destination: URL, same: Bool = true, copy: Bool = false, move: Bool = false) -> FileOperationKind? {
        DropRules.operation(sources: sources, destination: destination, sameVolume: same, forceCopy: copy, forceMove: move)
    }
    #expect(op([sub], sub) == nil)
    #expect(op([sub], URL(filePath: "/A/Sub/deep")) == nil)
    #expect(op([file], b) == .move)
    #expect(op([file], b, same: false) == .copy)
    #expect(op([file], b, copy: true) == .copy)
    #expect(op([file], b, same: false, move: true) == .move)
    #expect(op([file], a) == nil)
    #expect(op([file], a, copy: true) == .copy)
}

@Test func dropTargets() {
    let home = URL(filePath: "/Users/t"), trash = URL(filePath: "/Users/t/.Trash")
    func entry(_ path: String, _ kind: FileKind) -> FileEntry {
        FileEntry(url: URL(filePath: path), name: (path as NSString).lastPathComponent, kind: kind, size: nil, modified: nil, location: nil)
    }
    func target(_ entry: FileEntry?, _ location: Location) -> DropTarget? {
        DropRules.target(entry: entry, at: location, home: home, trash: trash)
    }
    let folder = URL(filePath: "/Users/t/Desktop/Pasta")
    #expect(target(entry(folder.path, .folder), .desktop) == .folder(folder))
    #expect(target(entry("/Users/t/Documents", .myDocuments), .desktop) == .folder(URL(filePath: "/Users/t/Documents")))
    #expect(target(entry(trash.path, .recycleBin(isFull: false)), .desktop) == .trash)
    #expect(target(entry("/Volumes/PEN", .volume(.removable)), .myComputer) == .folder(URL(filePath: "/Volumes/PEN")))
    #expect(target(entry("/Users/t/Desktop/a.txt", .text), .desktop) == nil)
    #expect(target(nil, .desktop) == .folder(home.appending(path: "Desktop")))
    #expect(target(nil, .myComputer) == nil)
    #expect(target(nil, .trash) == .trash)
    #expect(target(nil, .folder(folder)) == .folder(folder))
}

@Test func onlyRealFilesCanBeEdited() {
    let real: [FileKind] = [.folder, .application, .image, .audio, .video, .archive, .text, .document]
    let places: [FileKind] = [.myComputer, .myDocuments, .recycleBin(isFull: true), .volume(.internal)]
    func entry(_ kind: FileKind) -> FileEntry {
        FileEntry(url: URL(filePath: "/x"), name: "x", kind: kind, size: nil, modified: nil, location: nil)
    }
    #expect(real.allSatisfy { entry($0).isFileItem })
    #expect(places.allSatisfy { !entry($0).isFileItem })
}
