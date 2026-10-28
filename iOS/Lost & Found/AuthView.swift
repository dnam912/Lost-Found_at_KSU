import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var session: AuthSession

    var body: some View {
        Group {
            if session.isRestoring {
                ProgressView("Checking your session…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KSU.background)
            } else if session.user != nil {
                ContentView()
            } else {
                AuthView()
            }
        }
        .task {
            await session.restore()
        }
    }
}

struct AuthView: View {
    @EnvironmentObject private var session: AuthSession
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                KSU.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(KSU.black)
                                .frame(width: 64, height: 64)
                                .background(KSU.gold)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            Text(isCreatingAccount ? "Create your account" : "Welcome back")
                                .font(.largeTitle.bold())
                            Text("Sign in with your @kent.edu email to use KSU Lost & Found.")
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 14) {
                            TextField("Email address", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(KSU.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            SecureField("Password (12+ characters)", text: $password)
                                .textContentType(isCreatingAccount ? .newPassword : .password)
                                .textInputAutocapitalization(.never)
                                .padding(14)
                                .background(KSU.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            if let message = errorMessage ?? session.startupError {
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button(action: submit) {
                                Group {
                                    if isWorking {
                                        ProgressView().tint(KSU.black)
                                    } else {
                                        Text(isCreatingAccount ? "Create account" : "Sign in")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(15)
                                .foregroundStyle(KSU.black)
                                .background(KSU.gold)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .disabled(isWorking || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                            Button(isCreatingAccount ? "Already have an account? Sign in" : "New here? Create an account") {
                                isCreatingAccount.toggle()
                                errorMessage = nil
                                password = ""
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(KSU.black)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .navigationTitle("KSU Lost & Found")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(KSU.gold)
    }

    private func submit() {
        errorMessage = nil
        isWorking = true
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                if isCreatingAccount {
                    try await session.signUp(email: cleanEmail, password: password)
                } else {
                    try await session.signIn(email: cleanEmail, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}