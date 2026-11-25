//
//  StudyLandingContent.swift
//  UI
//
//  Created by Vladimir Gusev on 15.05.2026.
//

public import SwiftUI
import Theme

/// Pure rendering surface for the Study landing screen. Owns no I/O.
/// The container in the app target loads data and maps it to the
/// single `State` value passed here.
public struct StudyLandingContent: View {
    public enum State: Equatable, Sendable {
        case loading
        case empty
        case loaded(
            summary: StudySummaryData,
            decks: [StudyDeckRowData],
            readingRecs: [StudyReadingRecData]
        )
    }

    let state: State
    let onBeginSession: () -> Void
    let onSelectDeck: (Int64) -> Void
    let onSelectBook: (String) -> Void
    let onRefresh: () async -> Void

    @Environment(\.palette) private var palette
    @SwiftUI.State private var expandedDeckIDs: Set<Int64> = []
    private let sessionButtonSpacing = AmgiSpacing.xl + AmgiSpacing.xs

    public init(
        state: State,
        onBeginSession: @escaping () -> Void,
        onSelectDeck: @escaping (Int64) -> Void,
        onSelectBook: @escaping (String) -> Void,
        onRefresh: @escaping () async -> Void
    ) {
        self.state = state
        self.onBeginSession = onBeginSession
        self.onSelectDeck = onSelectDeck
        self.onSelectBook = onSelectBook
        self.onRefresh = onRefresh
    }

    public var body: some View {
        switch state {
        case .loading:
            loadingView
        case .empty:
            emptyView
        case let .loaded(summary, decks, readingRecs):
            loadedScrollView(summary: summary, decks: decks, readingRecs: readingRecs)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty

    private var emptyView: some View {
        ContentUnavailableView(
            "No decks yet",
            systemImage: "graduationcap",
            description: Text("Add an Anki deck to get started.")
        )
    }

    // MARK: - Loaded scroll view (whole page scrolls, no pinned hero)

    private func loadedScrollView(
        summary: StudySummaryData,
        decks: [StudyDeckRowData],
        readingRecs: [StudyReadingRecData]
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(summary.subtitleLabel)
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.top, AmgiSpacing.xs)
                    .padding(.bottom, AmgiSpacing.lg)
                ringHero(summary: summary)
                beginButton(totalDue: summary.totalDue)
                    .padding(.top, sessionButtonSpacing)
                loadedBody(decks: decks, readingRecs: readingRecs)
                    .padding(.top, sessionButtonSpacing)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable { await onRefresh() }
    }

    // MARK: - Ring (scrolls with page)

    private func ringHero(summary: StudySummaryData) -> some View {
        StudyDueRing(summary: summary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Begin button

    private func beginButton(totalDue: Int) -> some View {
        Button(action: onBeginSession) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(totalDue > 0 ? "Begin session · \(totalDue) cards" : "Nothing due")
                    .amgiFont(.body)
                    .bold()
            }
            .foregroundStyle(totalDue > 0 ? .white : palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                totalDue > 0 ? palette.accent : palette.accentSoft,
                in: RoundedRectangle(cornerRadius: AmgiRadius.control, style: .continuous)
            )
        }
        .buttonStyle(.pressScale)
        .disabled(totalDue == 0)
        .animation(AmgiMotion.standard, value: totalDue)
    }

    // MARK: - Loaded content body

    @ViewBuilder
    private func loadedBody(
        decks: [StudyDeckRowData],
        readingRecs: [StudyReadingRecData]
    ) -> some View {
        upNextSection(decks: decks)
        if !readingRecs.isEmpty {
            readingRecsSection(readingRecs: readingRecs)
                .padding(.top, decks.isEmpty ? 0 : AmgiSpacing.xl)
        }
    }

    // MARK: - Up Next

    @ViewBuilder
    private func upNextSection(decks: [StudyDeckRowData]) -> some View {
        let rows = visibleRows(in: decks)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Up Next")
                    .padding(.bottom, 4)
                AmgiCard(
                    background: .surface,
                    cornerRadius: AmgiRadius.inset,
                    contentInsets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                ) {
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            deckRow(row)
                            if row.id != rows.last?.id {
                                Divider()
                                    .padding(.leading, AmgiSpacing.lg)
                            }
                        }
                    }
                }
            }
        }
    }

    private struct VisibleDeck: Identifiable {
        let deck: StudyDeckRowData
        let depth: Int
        var id: Int64 { deck.id }
    }

    private func visibleRows(in decks: [StudyDeckRowData], depth: Int = 0) -> [VisibleDeck] {
        decks.flatMap { deck in
            let row = VisibleDeck(deck: deck, depth: depth)
            guard expandedDeckIDs.contains(deck.id) else { return [row] }
            return [row] + visibleRows(in: deck.children, depth: depth + 1)
        }
    }

    private func deckRow(_ row: VisibleDeck) -> some View {
        let deck = row.deck
        let expanded = expandedDeckIDs.contains(deck.id)
        return HStack(spacing: 0) {
            if deck.children.isEmpty {
                Color.clear.frame(width: 44, height: 1)
                    .accessibilityHidden(true)
            } else {
                Button {
                    if expanded {
                        expandedDeckIDs.remove(deck.id)
                    } else {
                        expandedDeckIDs.insert(deck.id)
                    }
                } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.forward")
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Collapse \(deck.name)" : "Expand \(deck.name)")
            }
            StudyDeckRow(data: deck) { onSelectDeck(deck.id) }
                .disabled(deck.totalDue == 0)
        }
        .padding(.leading, CGFloat(min(row.depth, 4)) * AmgiSpacing.sm)
        .padding(.trailing, AmgiSpacing.md)
    }

    // MARK: - Reading recommendations

    @ViewBuilder
    private func readingRecsSection(readingRecs: [StudyReadingRecData]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Reading recommendations")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(readingRecs) { rec in
                        StudyReadingRec(data: rec) { onSelectBook(rec.id) }
                    }
                }
                .padding(.horizontal, 1)  // prevents clip at edge
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .amgiFont(.sectionHeading)
            .foregroundStyle(palette.textPrimary)
            .padding(.bottom, 8)
    }
}

// MARK: - Previews

#if DEBUG

private let busySummary = StudySummaryData(
    totalDue: 55,
    newCount: 25,
    learnCount: 17,
    reviewCount: 13,
    subtitleLabel: "Wednesday · 3 decks due",
    deckCount: 3
)

private let busyDecks: [StudyDeckRowData] = [
    StudyDeckRowData(id: 1, name: "한국어 · Vocab Typing", totalDue: 25,
                     newCount: 10, learnCount: 8, reviewCount: 7, isFiltered: false),
    StudyDeckRowData(id: 2, name: "ComputerScience", totalDue: 17,
                     newCount: 8, learnCount: 5, reviewCount: 4, isFiltered: false),
    StudyDeckRowData(id: 3, name: "Français", totalDue: 13,
                     newCount: 7, learnCount: 4, reviewCount: 2, isFiltered: false),
]

private let sampleRecs: [StudyReadingRecData] = [
    StudyReadingRecData(id: "lp", title: "어린 왕자",
                        coverImagePath: nil, authorLabel: "Antoine de Saint-Exupéry"),
    StudyReadingRecData(id: "nw", title: "Norwegian Wood",
                        coverImagePath: nil, authorLabel: "Haruki Murakami"),
    StudyReadingRecData(id: "dq", title: "Don Quijote",
                        coverImagePath: nil, authorLabel: "Miguel de Cervantes"),
]

#Preview("Busy day") {
    NavigationStack {
        StudyLandingContent(
            state: .loaded(summary: busySummary, decks: busyDecks, readingRecs: sampleRecs),
            onBeginSession: {},
            onSelectDeck: { _ in },
            onSelectBook: { _ in },
            onRefresh: {}
        )
    }
    .environment(\.palette, .vividLight)
}

#Preview("All done") {
    NavigationStack {
        StudyLandingContent(
            state: .loaded(
                summary: StudySummaryData(
                    totalDue: 0, newCount: 0, learnCount: 0, reviewCount: 0,
                    subtitleLabel: "Wednesday", deckCount: 0
                ),
                decks: [],
                readingRecs: sampleRecs
            ),
            onBeginSession: {},
            onSelectDeck: { _ in },
            onSelectBook: { _ in },
            onRefresh: {}
        )
    }
    .environment(\.palette, .vividLight)
}

#Preview("Loading") {
    NavigationStack {
        StudyLandingContent(
            state: .loading,
            onBeginSession: {},
            onSelectDeck: { _ in },
            onSelectBook: { _ in },
            onRefresh: {}
        )
    }
    .environment(\.palette, .vividLight)
}

#Preview("Empty") {
    NavigationStack {
        StudyLandingContent(
            state: .empty,
            onBeginSession: {},
            onSelectDeck: { _ in },
            onSelectBook: { _ in },
            onRefresh: {}
        )
    }
    .environment(\.palette, .vividLight)
}
#endif
