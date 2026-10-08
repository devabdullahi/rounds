import AppIntents

/// The deck sizes the server accepts, as a choice Shortcuts can offer.
enum CardCountOption: Int, AppEnum {
    case ten = 10, twenty = 20, thirty = 30, fifty = 50

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Number of cards"
    static let caseDisplayRepresentations: [CardCountOption: DisplayRepresentation] = [
        .ten: "10", .twenty: "20", .thirty: "30", .fifty: "50",
    ]
}
