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
        // A badge earned by this case unlocks on the debrief, once the grade has landed.
        .overlay {
            if app.debriefSettled, router.path.last == .debrief, let unlock = app.pendingUnlocks.first {
                if app.showingAllUnlocks {
                    BadgeHaulView(statuses: app.pendingUnlocks) { withAnimation(.easeOut(duration: 0.25)) { app.celebratedAll() } }
                        .transition(.opacity)
                } else {
                    BadgeUnlockView(status: unlock, waiting: app.pendingUnlocks.count - 1,
                                    onCollect: { withAnimation(.easeOut(duration: 0.25)) { app.celebrated(unlock) } },
                                    onAcceptAll: { withAnimation(.easeOut(duration: 0.25)) { app.showingAllUnlocks = true } })
                        .id(unlock.id)
                        .transition(.opacity)
                }
            }
        }
        // Once the diagnosis is submitted (handoff onward), there's no going back to change it.
        .onChange(of: router.path) { _, path in NavLock.isLocked = path.contains(.handoff) || path.contains(.debrief) }
        .onDisappear { NavLock.isLocked = false }
        .onAppear {
            // A case the student left goes straight back to the interview, not the door note.
            if session.resumed, router.path.isEmpty {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { router.path = [.interview] }
            }
            if !app.debugInitialPath.isEmpty {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { router.path = app.debugInitialPath }
                app.debugInitialPath = []
            }
        }
    }
}
