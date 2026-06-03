import SwiftUI

struct AuthView: View {
    @StateObject private var authService = AuthService()
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
    var body: some View {
        ZStack {
            AppDesign.background.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 52))
                        .foregroundStyle(
                            LinearGradient(colors: [AppDesign.accent, AppDesign.accent2],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing)
                        )
                    Text("FitLog")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppDesign.textPrimary)
                }
                
                Spacer().frame(height: 20)
                
                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AppDesign.cardSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(AppDesign.textPrimary)
                    
                    SecureField("Lozinka", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AppDesign.cardSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(AppDesign.textPrimary)
                }
                .padding(.horizontal, 24)
                
                Button {
                    Task {
                        if isSignUp {
                            await authService.signUp(email: email, password: password)
                        } else {
                            await authService.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    HStack {
                        if authService.isLoading {
                            ProgressView().tint(.black)
                        }
                        Text(isSignUp ? "Napravi nalog" : "Prijavi se")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(colors: [AppDesign.accent, AppDesign.accent2],
                                             startPoint: .leading,
                                             endPoint: .trailing)
                            )
                    )
                    .foregroundStyle(.black)
                }
                .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || authService.isLoading)
                .padding(.horizontal, 24)
                
                Button {
                    withAnimation { isSignUp.toggle() }
                } label: {
                    Text(isSignUp ? "Već imaš nalog? Prijavi se" : "Nemaš nalog? Napravi ga")
                        .font(.subheadline)
                        .foregroundStyle(AppDesign.accent)
                }
                
                if authService.errorMessage != nil {
                    Text(authService.errorMessage ?? "")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }
                
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $authService.isAuthenticated) {
            ContentView()
        }
    }
}
