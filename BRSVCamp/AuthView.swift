import SwiftUI

struct AuthView: View {
    @Environment(AuthService.self) private var auth
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var confirmPassword = ""

    private enum Mode { case login, register }

    private var isFormValid: Bool {
        switch mode {
        case .login:
            return !email.isEmpty && password.count >= 6
        case .register:
            return !displayName.isEmpty && !email.isEmpty
                && password.count >= 6 && password == confirmPassword
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo / titlu
                    VStack(spacing: 8) {
                        Image(systemName: "tent.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.blue.gradient)
                        Text("BRSVCamp")
                            .font(.largeTitle.bold())
                        Text("Grupul tău de aventuri")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 48)

                    // Selector mod
                    Picker("", selection: $mode) {
                        Text("Intră în cont").tag(Mode.login)
                        Text("Cont nou").tag(Mode.register)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Câmpuri formular
                    VStack(spacing: 14) {
                        if mode == .register {
                            AuthField("Nume afișat", text: $displayName,
                                      icon: "person.fill")
                        }

                        AuthField("Email", text: $email,
                                  icon: "envelope.fill",
                                  keyboard: .emailAddress)

                        AuthField("Parolă", text: $password,
                                  icon: "lock.fill",
                                  isSecure: true)

                        if mode == .register {
                            AuthField("Confirmă parola", text: $confirmPassword,
                                      icon: "lock.fill",
                                      isSecure: true)
                        }
                    }
                    .padding(.horizontal)

                    // Eroare
                    if let error = auth.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Buton principal
                    Button {
                        Task { await submit() }
                    } label: {
                        Group {
                            if auth.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(mode == .login ? "Intră" : "Creează cont")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid ? Color.blue : Color.gray.opacity(0.4),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                    .disabled(!isFormValid || auth.isLoading)
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationBarHidden(true)
        }
    }

    private func submit() async {
        switch mode {
        case .login:
            await auth.signIn(email: email, password: password)
        case .register:
            await auth.signUp(email: email, password: password, displayName: displayName)
        }
    }
}

// MARK: - AuthField

struct AuthField: View {
    let title: String
    @Binding var text: String
    let icon: String
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false

    init(_ title: String, text: Binding<String>, icon: String,
         keyboard: UIKeyboardType = .default, isSecure: Bool = false) {
        self.title = title
        self._text = text
        self.icon = icon
        self.keyboard = keyboard
        self.isSecure = isSecure
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            if isSecure {
                SecureField(title, text: $text)
            } else {
                TextField(title, text: $text)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
