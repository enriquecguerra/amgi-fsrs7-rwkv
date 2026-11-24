//
//  StudyLandingModel.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 15.05.2026.
//

import OSLog
import AppCore
import AppShared
import Reader
import UI
import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Data loading for the study landing screen. Owns the deck + reader-book
/// clients, the progress coordinator, the mapped `StudyLandingContent.State`,
/// and the book-sheet selection so the Container carries no `@Dependency`;
/// the Container keeps only its navigation callback and load-task lifecycle.
@Observable
@MainActor
final class StudyLandingModel {
    var contentState: StudyLandingContent.State = .loading
    var selectedBook: ReaderBook?

    let progressCoordinator = ReaderProgressCoordinator()

    @ObservationIgnored @Dependency(\.readerBookClient) private var readerBookClient
    @ObservationIgnored @Dependency(\.collectionStore) private var store

    func load() async {
        do {
            let tree = try await store.tree()
            guard !tree.isEmpty else {
                contentState = .empty
                return
            }

            let deckRows = Self.dueBranches(tree)

            // Parent counts already include their subdecks and apply the
            // parent's limits. Use top-level counts for the Today summary.
            let dueTopLevelDecks = tree.filter { $0.counts.total > 0 }
            let counts = dueTopLevelDecks.reduce(into: DeckCounts.zero) { total, deck in
                total.newCount += deck.counts.newCount
                total.learnCount += deck.counts.learnCount
                total.reviewCount += deck.counts.reviewCount
            }
            let deckCount = dueTopLevelDecks.count

            // Build the subtitle from the weekday and the top-level deck count.
            let weekday = Date().formatted(.dateTime.weekday(.wide))
            let subtitleLabel: String
            if deckCount == 0 {
                subtitleLabel = weekday
            } else {
                subtitleLabel = "\(weekday) · \(deckCount) deck\(deckCount == 1 ? "" : "s") due"
            }

            let summary = StudySummaryData(
                totalDue: counts.total,
                newCount: counts.newCount,
                learnCount: counts.learnCount,
                reviewCount: counts.reviewCount,
                subtitleLabel: subtitleLabel,
                deckCount: deckCount
            )

            let readingRecs = await loadReadingRecs()

            contentState = .loaded(summary: summary, decks: deckRows, readingRecs: readingRecs)
        } catch {
            Log.reader.error("Error loading: \(error)")
            contentState = .empty
        }
    }

    private static func dueBranches(_ decks: [DeckTreeNode]) -> [StudyDeckRowData] {
        decks.compactMap { deck in
            let children = dueBranches(deck.children)
            guard deck.counts.total > 0 || !children.isEmpty else { return nil }
            return StudyDeckRowData(
                id: deck.id.rawValue,
                name: deck.name,
                totalDue: deck.counts.total,
                newCount: deck.counts.newCount,
                learnCount: deck.counts.learnCount,
                reviewCount: deck.counts.reviewCount,
                isFiltered: deck.isFiltered,
                children: children
            )
        }
        .sorted { $0.totalDue > $1.totalDue }
    }

    func selectBook(_ bookID: String) {
        guard let configuration = ReaderConfigurationLoader.loadConfiguration() else { return }
        Task {
            if let book = try? await readerBookClient.loadBook(bookID, configuration) {
                selectedBook = book
            }
        }
    }

    private func loadReadingRecs() async -> [StudyReadingRecData] {
        guard let configuration = ReaderConfigurationLoader.loadConfiguration(),
              let books = try? await readerBookClient.loadBooks(configuration) else {
            return []
        }

        var lastRead = [String: Date](minimumCapacity: books.count)
        for book in books {
            lastRead[book.id] = await progressCoordinator.resolved(bookID: book.id)?.updatedAt
        }

        return books
            .sorted { lhs, rhs in
                (lastRead[lhs.id] ?? .distantPast) > (lastRead[rhs.id] ?? .distantPast)
            }
            .prefix(8)
            .map { book in
                StudyReadingRecData(
                    id: book.id,
                    title: book.title,
                    coverImagePath: book.coverImagePath,
                    authorLabel: ""
                )
            }
    }
}
