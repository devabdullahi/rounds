import SwiftUI

/// Composition root for reference data: the one place that decides mock vs live.
/// Screens read `@Environment(\.reference)`. The default stays `.mock` so previews run offline;
/// RoundsApp injects `.live` for the running app.
extension EnvironmentValues {
    @Entry var reference: ReferenceServices = .mock
}
