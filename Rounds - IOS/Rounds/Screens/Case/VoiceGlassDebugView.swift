#if DEBUG
import SwiftUI

/// `-screen voice-glass`: the voice orb in each turn and the mic button, without opening a case,
/// to check their Liquid Glass in light and dark mode.
struct VoiceGlassDebugView: View {
    var body: some View {
        VStack(spacing: 28) {
            Text("Voice glass").font(.system(size: 22, weight: .bold))
            HStack(spacing: 8) {
                orb(.listening, 0.6, "Your turn")
                orb(.patientSpeaking, 0.5, "Patient")
            }
            orb(.thinking, 0, "Thinking")
            HStack(spacing: 16) {
                AppIcon(.mic, size: 22)
                    .foregroundStyle(Theme.accentText)
                    .frame(width: 48, height: 48)
                    .glassFill(Theme.accent, in: Circle(), strength: 0.16)
                AppIcon(.arrowUp, size: 22)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .glassCircle(tint: Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Theme.bg, Theme.surface], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private func orb(_ phase: VoiceController.Phase, _ level: CGFloat, _ label: String) -> some View {
        VStack(spacing: 6) {
            VoiceOrb(phase: phase, level: level).frame(width: 170, height: 170)
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.muted)
        }
    }
}
#endif
