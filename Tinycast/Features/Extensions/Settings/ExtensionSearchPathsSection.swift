import SwiftUI

struct ExtensionSearchPathsSection: View {
    @Environment(AppCore.self) private var core
    /// Written back only on a real edit, so a round trip cannot strip the separator.
    @State private var searchPathsText = ""

    var body: some View {
        @Bindable var settings = core.settings
        return Section {
            LabeledContent {
                TextField(
                    "Custom search paths", text: $searchPathsText,
                    prompt: Text(verbatim: "~/.local/share/mise/shims")
                )
                .labelsHidden()
                .font(.callout.monospaced())
                .autocorrectionDisabled()
                .pointerStyle(.horizontalText)
                .onChange(of: searchPathsText) { _, value in
                    settings.extensionCustomSearchPaths = Self.parseSearchPaths(value)
                }
            } label: {
                Text("Custom search paths")
                Text(
                    """
                    Colon-separated, like PATH — checked before Homebrew and the rest. For mise: \
                    ~/.local/share/mise/shims. For Nix (Home Manager): \
                    /etc/profiles/per-user/<you>/home-path/bin.
                    """
                )
            }
        } header: {
            SettingsSectionHeader(.extensionsSearchPaths)
        }
        .onAppear { searchPathsText = core.settings.extensionCustomSearchPaths.joined(separator: ":") }
    }

    private static func parseSearchPaths(_ text: String) -> [String] {
        text.split(separator: ":", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
