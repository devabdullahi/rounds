import SwiftUI

struct CaseFlowView: View {
    @Environment(AppState.self) private var app
    let session: CaseSession
    @State private var router = CaseRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            BriefView(session: session)
                .navigationDestination(for: CaseStep.self) { step in
                    Group {
                        switch step {
                        case .interview: InterviewView(session: session)
                        case .workup: WorkupView(session: session)
                        case .diagnosis: DiagnosisView(session: session)
                        case .handoff: HandoffView(session: session)
                        case .debrief: DebriefView(session: session)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .environment(router)
        // Once the diagnosis is submitted (handoff onward), there's no going back to change it.
        .onChange(of: router.path) { _, path in NavLock.isLocked = path.contains(.handoff) || path.contains(.debrief) }
        .onDisappear { NavLock.isLocked = false }
        .onAppear {
            if !app.debugInitialPath.isEmpty {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { router.path = app.debugInitialPath }
                app.debugInitialPath = []
            }
        }
    }
}
