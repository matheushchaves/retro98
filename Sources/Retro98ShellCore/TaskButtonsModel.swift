/// The taskbar's window buttons: a stable ordering of the source's windows, and clicks turned
/// into window commands. Any command is followed by a refresh, so a vanished window simply drops out.
@MainActor
public final class TaskButtonsModel<Source: WindowSource, Commands: WindowCommands> where Source.ID == Commands.ID {
    public typealias ID = Source.ID

    private let source: Source
    private let commands: Commands
    public private(set) var windows: [WindowSnapshot<ID>] = []
    public var onChange: (() -> Void)?

    public init(source: Source, commands: Commands) {
        self.source = source
        self.commands = commands
    }

    public func refresh() {
        let updated = TaskbarOrdering.order(previous: windows.map(\.id), current: source.snapshot())
        guard updated != windows else { return }
        windows = updated
        onChange?()
    }

    /// Activates the window, or minimizes it when it is the active one.
    public func click(_ id: ID) {
        guard let window = windows.first(where: { $0.id == id }) else {
            refresh()
            return
        }
        switch TaskButtonClick.action(isFocused: window.isFocused, isMinimized: window.isMinimized) {
        case .activate: _ = commands.activate(id)
        case .minimize: _ = commands.minimize(id)
        }
        refresh()
    }

    public func restore(_ id: ID) {
        _ = commands.activate(id)
        refresh()
    }

    public func minimize(_ id: ID) {
        _ = commands.minimize(id)
        refresh()
    }

    public func close(_ id: ID) {
        _ = commands.close(id)
        refresh()
    }
}
