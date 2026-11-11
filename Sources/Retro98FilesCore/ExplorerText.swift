import Foundation
import Retro98Settings

/// Explorer copy in Brazilian Portuguese and English.
public enum ExplorerText {
    private static func text(_ en: String, _ ptBR: String, _ languages: [String]) -> String {
        LocalizedText(en: en, ptBR: ptBR).resolve(for: languages)
    }

    public static func desktop(_ l: [String]) -> String { text("Desktop", "Área de Trabalho", l) }
    public static func myComputer(_ l: [String]) -> String { text("My Computer", "Meu Computador", l) }
    public static func myDocuments(_ l: [String]) -> String { text("My Documents", "Meus Documentos", l) }
    public static func recycleBin(_ l: [String]) -> String { text("Recycle Bin", "Lixeira", l) }
    public static func downloads(_ l: [String]) -> String { "Downloads" }
    public static func applications(_ l: [String]) -> String { text("Applications", "Aplicativos", l) }

    public static func menuFile(_ l: [String]) -> String { text("File", "Arquivo", l) }
    public static func menuEdit(_ l: [String]) -> String { text("Edit", "Editar", l) }
    public static func menuView(_ l: [String]) -> String { text("View", "Exibir", l) }
    public static func menuGo(_ l: [String]) -> String { text("Go", "Ir", l) }
    public static func menuFavorites(_ l: [String]) -> String { text("Favorites", "Favoritos", l) }
    public static func menuHelp(_ l: [String]) -> String { text("Help", "Ajuda", l) }

    public static func newWindow(_ l: [String]) -> String { text("New Window", "Nova janela", l) }
    public static func close(_ l: [String]) -> String { text("Close", "Fechar", l) }
    public static func selectAll(_ l: [String]) -> String { text("Select All", "Selecionar tudo", l) }
    public static func refresh(_ l: [String]) -> String { text("Refresh", "Atualizar", l) }
    public static func about(_ l: [String]) -> String { text("About Retro98 Explorer", "Sobre o Retro98 Explorer", l) }
    public static func hide(_ l: [String]) -> String { text("Hide Retro98 Explorer", "Ocultar Retro98 Explorer", l) }
    public static func hideOthers(_ l: [String]) -> String { text("Hide Others", "Ocultar Outros", l) }
    public static func showAll(_ l: [String]) -> String { text("Show All", "Mostrar Tudo", l) }
    public static func menuWindow(_ l: [String]) -> String { text("Window", "Janela", l) }
    public static func minimize(_ l: [String]) -> String { text("Minimize", "Minimizar", l) }
    public static func zoom(_ l: [String]) -> String { "Zoom" }
    public static func bringAllToFront(_ l: [String]) -> String { text("Bring All to Front", "Trazer Tudo para a Frente", l) }
    public static func redo(_ l: [String]) -> String { text("Redo", "Refazer", l) }
    public static func quit(_ l: [String]) -> String { text("Quit Retro98 Explorer", "Encerrar Retro98 Explorer", l) }
    public static func readme(_ l: [String]) -> String { text("Retro98 Help (README)", "Ajuda do Retro98 (README)", l) }

    public static func back(_ l: [String]) -> String { text("Back", "Voltar", l) }
    public static func forward(_ l: [String]) -> String { text("Forward", "Avançar", l) }
    public static func up(_ l: [String]) -> String { text("Up", "Acima", l) }
    public static func cut(_ l: [String]) -> String { text("Cut", "Recortar", l) }
    public static func copy(_ l: [String]) -> String { text("Copy", "Copiar", l) }
    public static func paste(_ l: [String]) -> String { text("Paste", "Colar", l) }
    public static func undo(_ l: [String]) -> String { text("Undo", "Desfazer", l) }
    public static func delete(_ l: [String]) -> String { text("Delete", "Excluir", l) }
    public static func properties(_ l: [String]) -> String { text("Properties", "Propriedades", l) }
    public static func views(_ l: [String]) -> String { text("Views", "Modos", l) }
    public static func address(_ l: [String]) -> String { text("Address", "Endereço", l) }

    public static func notFound(_ input: String, _ l: [String]) -> String {
        text("Cannot find '\(input)'.", "Não foi possível encontrar '\(input)'.", l)
    }
    public static func permissionDenied(_ l: [String]) -> String {
        text("You don't have permission to view this folder.", "Você não tem permissão para ver esta pasta.", l)
    }
    public static func trashNeedsAccess(_ l: [String]) -> String {
        text("To see the Recycle Bin here, give Retro98 Explorer Full Disk Access.",
             "Para ver a Lixeira aqui, dê Acesso Total ao Disco ao Retro98 Explorer.", l)
    }
    public static func openInFinder(_ l: [String]) -> String { text("Open in Finder", "Abrir no Finder", l) }
    public static func locationTitle(_ location: Location, _ l: [String]) -> String {
        guard case .folder(let url) = location else { return AddressParser.text(for: location, languages: l) }
        return FileManager.default.displayName(atPath: url.path)
    }
}
