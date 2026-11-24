//
//  DeckListView.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

package import SwiftUI
import AppShared
import UI
import AnkiKit
import Dependencies

package struct DeckListView: View {
    @Dependency(\.collectionStore) private var store
    @State private var model: DeckListModel
    @State private var showCreateSheet = false
    @State private var renameTarget: DeckRowViewData?
    @State private var pendingDeck: DeckInfo?

    package init() {
        _model = State(initialValue: DeckListModel())
    }

    /// Preview / test seam — internal so the model stays module-private.
    init(model: DeckListModel) {
        _model = State(initialValue: model)
    }

    package var body: some View {
        LibraryListContent(
            state: model.state,
            selectedDeckID: pendingDeck?.id.rawValue,
            onRefresh: { await model.load() },
            onStartReview: { pendingDeck = model.firstReviewableDeck() },
            onTapDeck: { row in pendingDeck = row.asDeckInfo },
            onDeleteDeck: { rawID in await model.delete(DeckID(rawID)) },
            onRenameDeck: { row in renameTarget = row },
            onCreateDeck: { showCreateSheet = true }
        )
        .equatable()
        .navigationTitle("Library")
        .navigationDestination(item: $pendingDeck) { deck in
            DeckDetailView(deck: deck)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateDeckSheet {
                showCreateSheet = false
            }
        }
        .sheet(item: $renameTarget) { row in
            RenameDeckSheet(deckId: DeckID(row.id), currentName: row.fullName) {
                renameTarget = nil
            }
        }
        .task(id: store.generation) { await model.load() }
    }
}
