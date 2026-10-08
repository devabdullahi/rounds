import Foundation
@testable import Rounds

/// Profile edits saved "on the server", so each update returns everything saved so far, as the real one does.
actor SavedProfile {
    private var name: String?
    private var specialty: Specialty?
    private var hasName = false
    func set(name: String) { self.name = name; hasName = true }
    func set(specialty: Specialty?) { self.specialty = specialty }
    func applied(to account: Account) -> Account {
        Account(id: account.id, email: account.email, name: hasName ? name : account.name, provider: account.provider,
                createdAt: account.createdAt, specialty: specialty)
    }
}
