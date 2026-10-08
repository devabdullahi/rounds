import SwiftUI
import PhotosUI

/// Edit profile: photo, name and the specialty the student is aiming for. Opened from the
/// identity card on Profile and from Settings. The photo saves as soon as it's picked; name and
/// specialty save together.
struct EditProfileView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var specialty: Specialty?
    @State private var photoItem: PhotosPickerItem?
    @State private var choosingSpecialty = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    photo
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel("Name")
                        TextField("Your name", text: $name)
                            .font(.system(size: 17))
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($nameFocused)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.ring))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel("Specialty")
                        Button { choosingSpecialty = true } label: {
                            HStack {
                                Text(specialty?.label ?? "Choose a specialty")
                                    .foregroundStyle(specialty == nil ? Theme.muted : Theme.text)
                                Spacer()
                                AppIcon(.chevronRight, size: 18).foregroundStyle(Theme.faint)
                            }
                            .font(.system(size: 17))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.ring))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Specialty, \(specialty?.label ?? "not chosen")")
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.bg)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $choosingSpecialty) {
                SpecialtyListView(selection: $specialty)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if auth.busy == .name {
                        ProgressView()
                    } else {
                        Button("Save", action: save)
                            .fontWeight(.semibold)
                            .disabled(ProfileName.clean(name) == nil || auth.busy != nil)
                    }
                }
            }
        }
        .tint(Theme.accent)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(auth.busy != nil)
        // Fills the fields once the account is known (it can still be loading when the sheet opens).
        .task(id: auth.account?.id) {
            name = auth.account?.name ?? ""
            specialty = auth.account?.specialty
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { _ = await auth.setPhoto(data) }
                photoItem = nil
            }
        }
        // The sheet covers the screen that opened it, whose own alert can't show until it closes.
        .alert("Something went wrong", isPresented: Binding(get: { auth.problem != nil }, set: { if !$0 { auth.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.problem ?? "")
        }
    }

    private var photo: some View {
        // PhotosPicker's label closure is Sendable, so it gets plain values, not the main-actor model.
        let initials = auth.account?.initials ?? "?"
        let imageURL = auth.account?.avatarURL
        let uploading = auth.busy == .photo
        return VStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Avatar(initials: initials, size: 96, fg: Theme.accentInk, bg: Theme.accent, imageURL: imageURL)
                    .overlay {
                        if uploading {
                            Circle().fill(.black.opacity(0.35))
                            ProgressView().tint(.white)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        AppIcon(.pencil, size: 15)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Theme.accent, in: Circle())
                            .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 3))
                    }
            }
            .buttonStyle(PressDownStyle())
            .disabled(auth.busy != nil)
            .accessibilityLabel("Change photo")

            PhotosPicker(selection: $photoItem, matching: .images) {
                Text("Change photo").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
                    .frame(minHeight: 44)
            }
            .disabled(auth.busy != nil)
            .accessibilityHidden(true)   // same action as the photo above
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func save() {
        nameFocused = false
        Task {
            if await auth.saveProfile(name: name, specialty: specialty) { dismiss() }
        }
    }
}
