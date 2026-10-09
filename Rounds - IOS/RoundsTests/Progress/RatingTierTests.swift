import Testing
@testable import Rounds

@Suite("Rating tiers")
struct RatingTierTests {
    @Test(arguments: [(1100, "Unranked", "200 to Silver"), (1200, "Unranked", "100 to Silver"),
                      (1300, "Silver tier", "300 to Gold"), (1599, "Silver tier", "1 to Gold"),
                      (1600, "Gold tier", "400 to Platinum"), (2400, "Platinum tier", "Top tier")])
    func tierAndNextStep(rating: Int, label: String, next: String) {
        let tier = RatingTier.of(rating)
        #expect(tier.label == label)
        #expect(tier.toNextLabel(rating) == next)
    }

    @Test func progressFillsWithinTheBand() {
        #expect(RatingTier.of(1450).progress(1450) == 0.5)
        #expect(RatingTier.of(1100).progress(1100) == 0)
        #expect(RatingTier.of(2400).progress(2400) == 1)
    }

    @Test func tiersStartWhereTheBadgesDo() {
        #expect(RatingTier.of(BadgeCatalog.silverRating).name == "Silver")
        #expect(RatingTier.of(BadgeCatalog.goldRating).name == "Gold")
        #expect(RatingTier.of(BadgeCatalog.platinumRating).name == "Platinum")
    }
}
