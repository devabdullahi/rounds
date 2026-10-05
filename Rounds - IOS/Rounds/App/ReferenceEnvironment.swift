import SwiftUI

/// Composition root for reference data: the one place that decides mock vs live.
/// Screens read `@Environment(\.reference)`; swap `.mock` for a live bundle here when it exists.
extension EnvironmentValues {
    @Entry var reference: ReferenceServices = .mock
}
