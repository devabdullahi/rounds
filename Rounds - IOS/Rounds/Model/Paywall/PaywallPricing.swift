import Foundation

/// The paywall's wording and arithmetic: per-week prices, the saving against the weekly plan, the
/// timeline and the button. Pure, so every line the student reads about money is tested.
enum PaywallPricing {
    private static let weeksPerYear: Decimal = 52
    private static let monthsPerYear: Decimal = 12

    /// What the plan costs per week.
    static func perWeek(_ plan: SubscriptionPlan) -> Decimal {
        switch plan.period {
        case .week: plan.price
        case .month: plan.price * monthsPerYear / weeksPerYear
        case .year: plan.price / weeksPerYear
        }
    }

    /// "$1.54/wk", in the plan's currency.
    static func perWeekLabel(_ plan: SubscriptionPlan, locale: Locale = .current) -> String {
        perWeek(plan).formatted(.currency(code: plan.currencyCode).locale(locale).precision(.fractionLength(2))) + "/wk"
    }

    /// Whole percent saved against paying weekly for the same time, rounded down so the badge never
    /// overstates; nil for the weekly plan itself, without a weekly plan, or under 5%.
    static func saving(_ plan: SubscriptionPlan, in plans: [SubscriptionPlan]) -> Int? {
        guard plan.period != .week, let weekly = plans.first(where: { $0.period == .week }), weekly.price > 0 else { return nil }
        // Decimal division leaves a long mantissa that NSDecimalNumber.intValue misreads; round it first.
        var exact = (1 - perWeek(plan) / weekly.price) * 100, whole = Decimal()
        NSDecimalRound(&whole, &exact, 0, .down)
        let percent = Int(truncating: whole as NSDecimalNumber)
        return percent >= 5 ? percent : nil
    }

    /// The line under the plan's name.
    static func detail(_ plan: SubscriptionPlan) -> String {
        if let days = plan.trialDays { return "\(days) days free, then \(plan.displayPrice)/\(plan.period.short)" }
        return "\(plan.displayPrice) billed \(plan.period == .week ? "weekly" : plan.period == .month ? "monthly" : "yearly")"
    }

    /// The day the trial reminder fires: the day before billing (Day 2 of a 3-day trial).
    static func reminderDay(trialDays: Int) -> Int { max(1, trialDays - 1) }

    /// What happens after tapping the button, so nobody is surprised by a charge.
    static func steps(_ plan: SubscriptionPlan) -> [TrialStep] {
        let access = TrialStep(kind: .access, when: "Today", what: "Every patient, voice interviews and full debriefs.")
        guard let days = plan.trialDays else {
            return [access, TrialStep(kind: .renewal, when: "Every \(plan.period.unit)",
                                      what: "Renews automatically. Cancel any time in Settings.")]
        }
        return [
            access,
            TrialStep(kind: .reminder, when: "Day \(reminderDay(trialDays: days))", what: "We remind you before the trial ends."),
            TrialStep(kind: .billing, when: "Day \(days)",
                      what: "Your \(plan.period.unit) starts at \(plan.displayPrice). Cancel before to pay nothing."),
        ]
    }

    static func buttonTitle(_ plan: SubscriptionPlan) -> String {
        if let days = plan.trialDays { return "Start \(days)-day free trial" }
        return "Continue for \(plan.displayPrice)/\(plan.period.short)"
    }

    /// The terms under the button, as Apple asks: price, period, renewal and how to cancel.
    static func finePrint(_ plan: SubscriptionPlan) -> String {
        if let days = plan.trialDays {
            return "Free for \(days) days, then \(plan.displayPrice)/\(plan.period.unit). Renews automatically. Cancel anytime."
        }
        return "\(plan.displayPrice) every \(plan.period.unit). Renews automatically. Cancel anytime."
    }

    /// The headline, from the goal picked in onboarding.
    static func headline(for goal: StudyGoal?) -> String {
        switch goal {
        case let exam? where [.step1, .step2CK, .osce].contains(exam): "Your \(exam.label) plan is ready"
        case .shelf: "Your shelf exam plan is ready"
        default: "Your practice plan is ready"
        }
    }
}
