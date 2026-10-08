import Foundation

/// Turns a free-form request into a `RoundsCommand`.
protocol CommandInterpreter: Sendable {
    func interpret(_ request: String) async -> RoundsCommand
}
