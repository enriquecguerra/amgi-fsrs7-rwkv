//
//  DeckListModel.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 13.06.2026.
//

import OSLog
import UI
import AppCore
import AppShared
import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Data state + load/mutation logic for the Library screen. Mirrors
/// `DeckDetailModel`: the View owns navigation, sheets, and the toolbar,
/// while the model owns I/O and the engine → view-data assembly so that
/// assembly is testable in isolation and the View stays a thin
/// presentation wiring layer.
@Observable
@MainActor
final class DeckListModel {
    var state: LibraryListContent.State = .loading

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient
    @ObservationIgnored @Dependency(\.statsClient) private var statsClient
    @ObservationIgnored @Dependency(\.collectionStore) private var store

    /// Publish deck rows first, then fill in the sparkline and the heatmap.
    func load() async {
        await AppSignpost.measure("DeckListLoad") { await loadBody() }
    }

    private func loadBody() async {
        // Carry the previous activity data through a refresh rather than
        // flashing placeholders over numbers that are still on screen.
        let previousActivity: [Int]?
        let previousHeatmap: HeatmapCardData?
        if case .loaded(_, let hero, let heatmap) = state {
            previousActivity = hero.last14Days
            previousHeatmap = heatmap
        } else {
            previousActivity = nil
            previousHeatmap = nil
        }

        do {
            // Separates engine wait from Swift assembly. Phase one measured
            // 145 ms in-app but only 0.44 ms against stubbed clients
            // (DeckListLoadPerformanceTests), so the cost has to be in here —
            // and it is I/O-bound, which is why the CPU profile barely sees it.
            let tree = try await AppSignpost.measure("DeckTreeFetch") {
                try await store.tree()
            }
            if tree.isEmpty {
                state = .empty
                return
            }
            let rows = tree.map(DeckListRow.init(node:))
            let viewRows = rows.map(\.viewData)
            let totalDue = rows.reduce(0) { $0 + $1.counts.total }

            state = .loaded(
                rows: viewRows,
                hero: HeroData(
                    totalDue: totalDue,
                    deckCount: rows.count,
                    last14Days: previousActivity
                ),
                heatmap: previousHeatmap
            )

            let historyDays = 365
            let reviews = await AppSignpost.measure("DeckListActivity") {
                let graphs = try? await statsClient.fetchGraphs("", historyDays)
                return graphs?.reviews.count
            }
            guard !Task.isCancelled else { return }
            let last14Days = reviews.map { StreakCalculator.lastNDaysTotals(reviews: $0, days: 14) }
            state = .loaded(
                rows: viewRows,
                hero: HeroData(totalDue: totalDue, deckCount: rows.count, last14Days: last14Days ?? previousActivity),
                heatmap: reviews.map { Self.buildHeatmap(reviews: $0, days: historyDays) } ?? previousHeatmap ?? .empty
            )
        } catch {
            Log.decks.error("Error loading decks: \(error)")
            // NOT .empty — that is the genuine no-decks state, and rendering a
            // failure as it told users with a full collection they had none.
            state = .failed(error.localizedDescription)
        }
    }

    func delete(_ id: DeckID) async {
        do {
            let changes = try await deckClient.delete(id)
            store.apply(changes)   // generation bump → the view's .task(id:) reloads
        } catch {
            Log.decks.error("Delete failed: \(error)")
            await load()           // error path: no invalidation happened, reload manually
        }
    }

    /// First loaded deck that has cards waiting, projected to a `DeckInfo`
    /// for navigation. Nil while loading/empty or when nothing is due.
    func firstReviewableDeck() -> DeckInfo? {
        guard case .loaded(let rows, _, _) = state else { return nil }
        return rows.first(where: { $0.totalCount > 0 })?.asDeckInfo
    }

    private static func buildHeatmap(
        reviews: [Int: ReviewCountsAndTimes.Reviews],
        days: Int
    ) -> HeatmapCardData {
        let totals = StreakCalculator.lastNDaysTotals(reviews: reviews, days: days)
        let counts = Dictionary(uniqueKeysWithValues: totals.enumerated().compactMap { index, count in
            count > 0 ? (index - days + 1, count) : nil
        })
        return HeatmapCardData(counts: counts, maxCount: totals.max() ?? 1)
    }
}
