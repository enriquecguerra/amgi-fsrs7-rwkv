//
//  LibraryHeroCard.swift
//  UI
//
//  Created by Vladimir Gusev on 14.05.2026.
//

public import SwiftUI
import Theme

/// Library summary with a review button and a 14-day activity sparkline.
public struct LibraryHeroCard: View {
    let data: HeroData
    let onStartReview: () -> Void

    @Environment(\.palette) private var palette

    public init(
        data: HeroData,
        onStartReview: @escaping () -> Void
    ) {
        self.data = data
        self.onStartReview = onStartReview
    }

    public var body: some View {
        AmgiHeroSummary(
            eyebrow: "Due today",
            bigNumber: "\(data.totalDue)",
            subtitle: subtitleText,
            background: heroGradient,
            decoration: { EmptyView() },
            footer: {
                VStack(spacing: 12) {
                    Button(action: onStartReview) {
                        Label("Start today's review", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .amgiFont(size: 16, weight: .semibold, relativeTo: .body)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.white.opacity(0.22))
                    .foregroundStyle(.white)
                    .disabled(data.totalDue == 0)

                    SparklineBars(values: data.last14Days ?? Array(repeating: 0, count: 14))
                        .frame(height: 28)
                        .redacted(reason: data.last14Days == nil ? .placeholder : [])
                }
            }
        )
    }

    private var subtitleText: String {
        "cards across \(data.deckCount) deck\(data.deckCount == 1 ? "" : "s")"
    }

    private var heroGradient: AmgiCardBackground {
        .gradient(
            start: palette.accent,
            end: Color(red: 0.37, green: 0.36, blue: 0.91), // #5E5CE6 Apple indigo
            angle: .degrees(155)
        )
    }
}

// MARK: - 14-day sparkline

private struct SparklineBars: View {
    let values: [Int]

    var body: some View {
        let maxValue = max(values.max() ?? 0, 1)
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    // A zero day is a faint baseline tick, not a short bar —
                    // the 4pt floor otherwise renders 0 and 1 identically, and
                    // an all-zero series as 14 stubs that read as real data.
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(.white.opacity(value == 0 ? 0.18 : 0.55))
                        .frame(height: value == 0
                               ? 2
                               : max(4, geo.size.height * CGFloat(value) / CGFloat(maxValue)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Populated") {
    LibraryHeroCard(
        data: HeroData(
            totalDue: 680,
            deckCount: 7,
            last14Days: [3, 5, 2, 7, 6, 9, 4, 8, 6, 5, 7, 3, 8, 5]
        ),
        onStartReview: {}
    )
    .padding(16)
    .background(Color.gray.opacity(0.12))
    .environment(\.palette, .vividLight)
}

#Preview("Zero due — CTA disabled") {
    LibraryHeroCard(
        data: HeroData(
            totalDue: 0,
            deckCount: 4,
            last14Days: [3, 5, 0, 0, 6, 9, 4, 8, 6, 0, 7, 3, 8, 0]
        ),
        onStartReview: {}
    )
    .padding(16)
    .background(Color.gray.opacity(0.12))
    .environment(\.palette, .vividLight)
}

#Preview("Activity loading") {
    LibraryHeroCard(
        data: HeroData(
            totalDue: 42,
            deckCount: 3,
            last14Days: nil
        ),
        onStartReview: {}
    )
    .padding(16)
    .background(Color.gray.opacity(0.12))
    .environment(\.palette, .vividLight)
}
#endif
