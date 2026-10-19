import SwiftUI

/// Composition root for reference data. Screens read `@Environment(\.reference)`, which is live
/// everywhere, so no screen can fall back to sample data; a preview or test that must stay offline
/// passes `.mock` itself.
extension EnvironmentValues {
    @Entry var reference: ReferenceServices = .live
}
