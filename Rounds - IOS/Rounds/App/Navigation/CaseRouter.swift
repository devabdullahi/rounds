import SwiftUI

@Observable
final class CaseRouter {
    var path: [CaseStep] = []
    func go(_ step: CaseStep) { path.append(step) }
    func back() { if !path.isEmpty { path.removeLast() } }
    func restart() { path = [] }
}
