import SwiftUI

extension View {
    /// The shared "Something went wrong" alert, shown while `problem` holds a message and cleared
    /// when dismissed. `actions` go before the OK button (e.g. a retry).
    func problemAlert<Actions: View>(_ problem: Binding<String?>, @ViewBuilder actions: () -> Actions) -> some View {
        alert("Something went wrong", isPresented: Binding(get: { problem.wrappedValue != nil },
                                                           set: { if !$0 { problem.wrappedValue = nil } })) {
            actions()
            Button("OK", role: .cancel) {}
        } message: {
            Text(problem.wrappedValue ?? "")
        }
    }

    func problemAlert(_ problem: Binding<String?>) -> some View {
        problemAlert(problem) { EmptyView() }
    }
}
