import Foundation

enum AdmitOutcome: Sendable, Equatable {
    case admitted(bed: String)
    case preparing
}
