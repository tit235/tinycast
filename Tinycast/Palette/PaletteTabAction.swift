import Foundation

/// Tab rings the launcher and clipboard; a sub-screen exits to the launcher.
enum PaletteTabAction: Equatable {
    /// The typed text rides along, because both ends narrow their own list by the same query.
    case carryQuery(PaletteMode)
    /// A fresh screen: chat's field holds a half-written message, which is nobody else's search.
    case freshScreen(PaletteMode)
    static func resolve(mode: PaletteMode, aiEnabled: Bool, clipboardEnabled: Bool) -> Self {
        switch mode {
        // A stop that is off leaves the ring, so Tab skips it rather than opening nothing.
        case .launcher:
            return clipboardEnabled ? .carryQuery(.clipboard) : .carryQuery(.launcher)
        case .ai:
            return clipboardEnabled ? .freshScreen(.clipboard) : .carryQuery(.launcher)
        case .clipboard: return .carryQuery(.launcher)
        default: return .carryQuery(.launcher)
        }
    }
}
