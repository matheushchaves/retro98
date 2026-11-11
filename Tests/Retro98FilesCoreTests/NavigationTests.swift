import Foundation
import Testing
@testable import Retro98FilesCore

private let a = Location.folder(URL(filePath: "/A")), b = Location.folder(URL(filePath: "/B"))
private let c = Location.folder(URL(filePath: "/C")), d = Location.folder(URL(filePath: "/D"))

@Test func historyBackForward() {
    var history = NavigationHistory(start: a)
    history.go(to: b); history.go(to: c)
    history.back(); history.back()
    #expect(history.current == a && !history.canGoBack && history.canGoForward)
    history.forward()
    #expect(history.current == b)
    history.go(to: d)
    #expect(!history.canGoForward)
    history.back()
    #expect(history.current == b)
}

@Test func goingToTheSamePlaceDoesNotStack() {
    var history = NavigationHistory(start: a)
    history.go(to: a)
    #expect(!history.canGoBack)
}

@Test func parents() {
    let volumes = [URL(filePath: "/"), URL(filePath: "/Volumes/PEN")]
    #expect(NavigationHistory.parent(of: .folder(URL(filePath: "/Users/t/Docs")), volumes: volumes) == .folder(URL(filePath: "/Users/t")))
    #expect(NavigationHistory.parent(of: .folder(URL(filePath: "/Volumes/PEN")), volumes: volumes) == .myComputer)
    #expect(NavigationHistory.parent(of: .folder(URL(filePath: "/")), volumes: volumes) == .myComputer)
    #expect(NavigationHistory.parent(of: .myComputer, volumes: volumes) == .desktop)
    #expect(NavigationHistory.parent(of: .trash, volumes: volumes) == .desktop)
    #expect(NavigationHistory.parent(of: .desktop, volumes: volumes) == nil)
}

@Test func recoverWalksUpToAnExistingPlace() {
    let volumes = [URL(filePath: "/")]
    #expect(NavigationHistory.recover(.folder(URL(filePath: "/Volumes/PEN/a/b")), exists: { _ in false }, volumes: volumes) == .myComputer)
    #expect(NavigationHistory.recover(.folder(URL(filePath: "/Users/t/x/y")), exists: { $0.path == "/Users/t" }, volumes: volumes)
            == .folder(URL(filePath: "/Users/t")))
    #expect(NavigationHistory.recover(.desktop, exists: { _ in false }, volumes: volumes) == .desktop)
}

@Test func addressAcceptsNamesAndPaths() {
    let home = URL(filePath: "/Users/t")
    let dirs: Set<String> = ["/Users/t", "/Users/t/Downloads", "/Volumes/X"]
    let parse = { (text: String) in AddressParser.location(for: text, home: home, languages: ["pt-BR"], isDirectory: { dirs.contains($0) }) }
    #expect(parse("área de trabalho") == .desktop)
    #expect(parse("Desktop") == .desktop)
    #expect(parse("MEU COMPUTADOR") == .myComputer)
    #expect(parse("lixeira") == .trash)
    #expect(parse("~") == .folder(home))
    #expect(parse("~/Downloads/") == .folder(URL(filePath: "/Users/t/Downloads")))
    #expect(parse("/Volumes/X") == .folder(URL(filePath: "/Volumes/X")))
    #expect(parse("nada") == nil)
    #expect(parse("   ") == nil)
}

@Test func addressTextRoundTrips() {
    #expect(AddressParser.text(for: .desktop, languages: ["pt-BR"]) == "Área de Trabalho")
    #expect(AddressParser.text(for: .myComputer, languages: ["en"]) == "My Computer")
    #expect(AddressParser.text(for: .folder(URL(filePath: "/Users/t/Docs")), languages: ["pt-BR"]) == "/Users/t/Docs")
}

@Test func statusTexts() {
    let br = Locale(identifier: "pt_BR")
    let size = StatusText.bytes(1_200_000, locale: br)
    #expect(size.contains("1,2") && size.contains("MB"))
    #expect(StatusText.objects(count: 7, selected: 0, languages: ["pt-BR"]) == "7 objeto(s)")
    #expect(StatusText.objects(count: 7, selected: 2, languages: ["pt-BR"]) == "2 objeto(s) selecionado(s)")
    #expect(StatusText.objects(count: 1, selected: 0, languages: ["en"]) == "1 object(s)")
    #expect(StatusText.free(190_000_000_000, locale: br, languages: ["pt-BR"]).hasPrefix("Livre: "))
}

@Test func explorerURLsRoundTrip() {
    for location in [Location.desktop, .myComputer, .trash, .folder(URL(filePath: "/Users/t/Meus Projetos/Ação"))] {
        #expect(ExplorerURL.location(from: ExplorerURL.url(for: location)) == location)
    }
    #expect(ExplorerURL.url(for: .desktop).absoluteString == "retro98-explorer://desktop")
    #expect(ExplorerURL.location(from: URL(string: "https://example.com")!) == nil)
}

@Test func ancestorsRunFromHereToTheDesktop() {
    let volumes = [URL(filePath: "/"), URL(filePath: "/Volumes/PEN")]
    #expect(NavigationHistory.ancestors(of: .folder(URL(filePath: "/Volumes/PEN/fotos")), volumes: volumes)
            == [.folder(URL(filePath: "/Volumes/PEN/fotos")), .folder(URL(filePath: "/Volumes/PEN")), .myComputer, .desktop])
    #expect(NavigationHistory.ancestors(of: .desktop, volumes: volumes) == [.desktop])
    #expect(NavigationHistory.ancestors(of: .trash, volumes: volumes) == [.trash, .desktop])
}
