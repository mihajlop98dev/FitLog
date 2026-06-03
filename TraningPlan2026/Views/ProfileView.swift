import SwiftUI
import LocalAuthentication

struct ProfileView: View {
    let authService: AuthService
    let featureGate: FeatureGateService
    @StateObject private var profileVM: ProfileViewModel
    @State private var showingSignOutAlert = false
    @State private var faceIDEnabled: Bool
    @State private var showingUpgradeAlert = false
    @State private var upgradeMessage = ""
    
    init(authService: AuthService, featureGate: FeatureGateService) {
        self.authService = authService
        self.featureGate = featureGate
        _profileVM = StateObject(wrappedValue: ProfileViewModel(userId: authService.userId ?? ""))
        faceIDEnabled = UserDefaults.standard.bool(forKey: "faceIDEnabled")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        profileHeader
                        statsSection
                        settingsSection
                        upgradeSection
                        signOutSection
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profil")
            .task { await profileVM.loadStats() }
        }
        .alert("Nadogradnja", isPresented: $showingUpgradeAlert) {
            Button("OK") {}
        } message: {
            Text(upgradeMessage)
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(LinearGradient(colors: [AppDesign.accent, AppDesign.accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            if let name = featureGate.profile?.name {
                Text(name)
                    .font(.title2.bold())
                    .foregroundStyle(AppDesign.textPrimary)
            }
            
            Text(authService.userId ?? "")
                .font(.caption)
                .foregroundStyle(AppDesign.textSecondary)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(featureGate.isTrialValid ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(featureGate.isTrialValid ? "Aktivna proba" : "Probni period istekao")
                    .font(.caption)
                    .foregroundStyle(AppDesign.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    
    private var statsSection: some View {
        VStack(spacing: 12) {
            Text("Statistika")
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(value: "\(profileVM.totalWorkouts)", label: "Treninga")
                statCard(value: "\(profileVM.streakDays)", label: "Niz (dana)")
                statCard(value: "\(profileVM.daysActive)", label: "Aktivnih dana")
                if featureGate.hasNutrition {
                    statCard(value: "\(profileVM.totalMeals)", label: "Obroka")
                }
            }
        }
        .padding()
        .background(AppDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    
    private var settingsSection: some View {
        VStack(spacing: 12) {
            Text("Podešavanja")
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Toggle("FaceID / TouchID prijava", isOn: $faceIDEnabled)
                .tint(AppDesign.accent)
                .onChange(of: faceIDEnabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "faceIDEnabled")
                }
        }
        .padding()
        .background(AppDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    
    private var upgradeSection: some View {
        VStack(spacing: 12) {
            Text("Funkcije")
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !featureGate.hasNutrition {
                Button {
                    Task {
                        await featureGate.updateFeatureTier(featureGate.featureTier, hasNutrition: true)
                        upgradeMessage = "Ishrana je aktivirana! Sada imaš pristup planu ishrane."
                        showingUpgradeAlert = true
                    }
                } label: {
                    upgradeButton(title: "Nadogradi na Ishranu", subtitle: "Plan ishrane + praćenje obroka")
                }
            }
            
            if !featureGate.isPro {
                Button {
                    Task {
                        await featureGate.updateFeatureTier("pro", hasNutrition: true)
                        upgradeMessage = "Pro je aktiviran! Sada imaš AI trener chat."
                        showingUpgradeAlert = true
                    }
                } label: {
                    upgradeButton(title: "Nadogradi na Pro", subtitle: "Sve + AI trener chat")
                }
            }
            
            if featureGate.isPro && featureGate.hasNutrition {
                Text("Sve funkcije su aktivirane ✓")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(AppDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    
    private var signOutSection: some View {
        Button(role: .destructive) {
            showingSignOutAlert = true
        } label: {
            HStack {
                Spacer()
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Odjavi se")
                Spacer()
            }
            .padding()
            .background(AppDesign.card.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.3), lineWidth: 1))
        }
        .alert("Odjava", isPresented: $showingSignOutAlert) {
            Button("Odjavi se", role: .destructive) {
                Task { await authService.signOut() }
            }
            Button("Otkaži", role: .cancel) {}
        } message: {
            Text("Da li si siguran?")
        }
    }
    
    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
                .foregroundStyle(AppDesign.accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppDesign.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(AppDesign.cardSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func upgradeButton(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppDesign.accent)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppDesign.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppDesign.textSecondary)
        }
        .padding()
        .background(AppDesign.cardSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
