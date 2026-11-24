//
//  HeroData.swift
//  UI
//
//  Created by Vladimir Gusev on 15.05.2026.
//

import Foundation

/// Hero-card payload. Anki-agnostic — populated by the container by
/// aggregating from domain models.
public struct HeroData: Equatable, Hashable, Sendable {
    public let totalDue: Int
    public let deckCount: Int
    public let streak: Int
    /// Oldest to newest. Nil while the activity history is loading.
    public let last14Days: [Int]?

    public init(totalDue: Int, deckCount: Int, streak: Int = 0, last14Days: [Int]?) {
        self.totalDue = totalDue
        self.deckCount = deckCount
        self.streak = streak
        self.last14Days = last14Days
    }

    public static let zero = HeroData(
        totalDue: 0,
        deckCount: 0,
        last14Days: Array(repeating: 0, count: 14)
    )
}
