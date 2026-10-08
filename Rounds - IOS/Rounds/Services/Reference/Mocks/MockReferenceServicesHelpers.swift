import Foundation

func simulatedLatency() async throws {
    try await Task.sleep(for: .milliseconds(150))
}
