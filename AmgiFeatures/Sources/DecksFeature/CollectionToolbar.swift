package import AppCore
import BrowseFeature
import Sharing
package import SwiftUI

package struct CollectionToolbar: ViewModifier {
    private let onSwitchProfile: (AmgiAccount) async -> Void
    private let onSync: () -> Void
    private let onImport: () -> Void

    @State private var showCreateSheet = false
    @State private var showBrowse = false
    @State private var accounts = AccountStore.shared
    @Shared(.appStorage(AppearancePreferences.Keys.showProfileInToolbar))
    private var showProfileInToolbar = true

    package init(
        onSwitchProfile: @escaping (AmgiAccount) async -> Void,
        onSync: @escaping () -> Void,
        onImport: @escaping () -> Void
    ) {
        self.onSwitchProfile = onSwitchProfile
        self.onSync = onSync
        self.onImport = onImport
    }

    package func body(content: Content) -> some View {
        content
            .toolbar { toolbarContent }
            #if canImport(UIKit)
            .navigationDestination(isPresented: $showBrowse) {
                BrowseView()
            }
            #endif
            .sheet(isPresented: $showCreateSheet) {
                CreateDeckSheet {
                    showCreateSheet = false
                }
            }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if showProfileInToolbar && accounts.accounts.count > 1 {
            ToolbarItem(placement: .navigation) {
                ProfilePickerMenu(onSwitch: onSwitchProfile)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Sync", systemImage: "arrow.triangle.2.circlepath", action: onSync)
                .keyboardShortcut("r", modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Button("New Deck", systemImage: "plus") {
                showCreateSheet = true
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                #if canImport(UIKit)
                Button {
                    showBrowse = true
                } label: {
                    Label("Browse Notes", systemImage: "doc.text")
                }
                #endif
                Button(action: onImport) {
                    Label("Import Deck…", systemImage: "square.and.arrow.down")
                }
            } label: {
                Label("More", systemImage: "ellipsis")
            }
        }
    }
}
