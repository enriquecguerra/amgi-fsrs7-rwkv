//
//  StudyLandingView.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 15.05.2026.
//

package import SwiftUI
import AppShared
import UI
import Reader
package import AnkiKit
import Dependencies

/// Study tab container. Holds a `StudyLandingModel` that loads the deck tree
/// + reader books and maps to `StudyLandingContent.State`; forwards
/// navigation callbacks to the parent (`RootView`).
package struct StudyLandingView: View {
    /// Called when the user taps a deck row or "Begin Session".
    /// Sets `pendingReviewDeckId` on RootView to trigger the
    /// existing fullscreen cover.
    let onSelectDeck: (DeckID) -> Void

    package init(onSelectDeck: @escaping (DeckID) -> Void) {
        self.onSelectDeck = onSelectDeck
    }

    @Dependency(\.collectionStore) private var store
    @State private var model = StudyLandingModel()

    package var body: some View {
        StudyLandingContent(
            state: model.contentState,
            onBeginSession: beginSession,
            onSelectDeck: { id in onSelectDeck(DeckID(id)) },
            onSelectBook: { bookID in model.selectBook(bookID) },
            onRefresh: { await model.load() }
        )
        .navigationTitle("Today")
        .sheet(item: $model.selectedBook) { book in
            NavigationStack {
                ChapterListView(book: book, progress: model.progressCoordinator)
            }
        }
        // Keyed on the store's generation: any Invalidation re-runs the
        // load; `.task` cancels itself on disappear.
        .task(id: store.generation) { await model.load() }
    }

    private func beginSession() {
        guard case .loaded(_, let decks, _) = model.contentState else { return }
        var first: StudyDeckRowData?
        func consider(_ decks: [StudyDeckRowData]) {
            for deck in decks {
                if deck.totalDue > (first?.totalDue ?? 0) {
                    first = deck
                }
                consider(deck.children)
            }
        }
        consider(decks)
        if let first { onSelectDeck(DeckID(first.id)) }
    }
}
