import SwiftUI

struct GroupOnboardingView: View {
    @Environment(GroupService.self) private var groupService
    @State private var mode: Mode = .join
    @State private var groupName = ""
    @State private var inviteCode = ""

    private enum Mode { case create, join }

    private var isFormValid: Bool {
        switch mode {
        case .create: return !groupName.trimmingCharacters(in: .whitespaces).isEmpty
        case .join:   return inviteCode.count >= 4
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Image(systemName: "tent.2.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.green.gradient)
                        Text("Grupul tău")
                            .font(.largeTitle.bold())
                        Text("Creează un grup nou sau alătură-te unuia existent")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 48)

                    Picker("", selection: $mode) {
                        Text("Alătură-te").tag(Mode.join)
                        Text("Creează grup").tag(Mode.create)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    VStack(spacing: 14) {
                        if mode == .create {
                            AuthField("Numele grupului", text: $groupName, icon: "person.3.fill")
                        } else {
                            AuthField("Cod de invitație (ex: BRSV-4829)", text: $inviteCode,
                                      icon: "key.fill")
                            .onChange(of: inviteCode) { _, v in
                                inviteCode = v.uppercased()
                            }
                        }
                    }
                    .padding(.horizontal)

                    if let error = groupService.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Group {
                            if groupService.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(mode == .create ? "Creează grup" : "Alătură-te")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid ? Color.green : Color.gray.opacity(0.4),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                    .disabled(!isFormValid || groupService.isLoading)
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationBarHidden(true)
        }
    }

    private func submit() async {
        switch mode {
        case .create: await groupService.createGroup(name: groupName.trimmingCharacters(in: .whitespaces))
        case .join:   await groupService.joinGroup(code: inviteCode)
        }
    }
}
