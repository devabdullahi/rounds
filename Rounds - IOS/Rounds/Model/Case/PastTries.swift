import Foundation
import Observation

/// The "Previous tries" sheet's state: loads one patient's graded attempts once, newest first.
@MainActor
@Observable
final class PastTries: Identifiable {
    enum Phase { case loading, loaded([PastTry]), failed(String) }

    let bed: String
    private(set) var phase: Phase = .loading
    private let service: (any CaseService)?

    init(bed: String, service: (any CaseService)?) {
        self.bed = bed
        self.service = service
    }

    #if DEBUG
    /// Already loaded, for debug screens.
    init(bed: String, tries: [PastTry]) {
        self.bed = bed
        self.service = nil
        phase = .loaded(tries)
    }
    #endif

    func load() async {
        guard case .loading = phase else { return }
        guard let service else { phase = .failed("Rounds isn't connected to its server."); return }
        do {
            phase = .loaded(try await service.pastTries(bed: bed))
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func retry() async {
        phase = .loading
        await load()
    }
}
