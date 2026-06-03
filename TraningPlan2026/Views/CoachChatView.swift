import SwiftUI

struct CoachChatView: View {
    @ObservedObject var viewModel: CoachChatViewModel
    let workouts: [Workout]
    let meals: [Meal]
    let progressEntries: [BodyProgressEntry]
    
    @State private var input = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 10) {
                                ForEach(viewModel.messages) { message in
                                    messageBubble(message)
                                        .id(message.id)
                                }
                                if viewModel.isSending {
                                    HStack {
                                        ProgressView()
                                            .tint(AppDesign.accent)
                                        Text("Trener piše...")
                                            .font(.caption)
                                            .foregroundStyle(AppDesign.textSecondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 10)
                        }
                        .onAppear {
                            scrollToBottom(proxy: proxy, animated: false)
                        }
                        .onChange(of: viewModel.messages.count) { _, _ in
                            scrollToBottom(proxy: proxy, animated: true)
                        }
                    }
                    
                    inputBar
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppDesign.card.opacity(0.95))
                }
            }
            .navigationTitle("Trener Chat")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.evaluateInactivityAndPromptIfNeeded(
                    workouts: workouts,
                    meals: meals,
                    progressEntries: progressEntries
                )
            }
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Napiši poruku treneru...", text: $input)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppDesign.cardSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(AppDesign.textPrimary)
            
            Button {
                Task {
                    let text = input
                    input = ""
                    await viewModel.sendUserMessage(
                        text,
                        workouts: workouts,
                        meals: meals,
                        progressEntries: progressEntries
                    )
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(10)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [AppDesign.accent, AppDesign.accent2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            .opacity((input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending) ? 0.5 : 1)
        }
    }
    
    private func messageBubble(_ message: CoachChatMessage) -> some View {
        let isCoach = message.sender == .coach
        return HStack {
            if !isCoach { Spacer(minLength: 36) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(isCoach ? AppDesign.textPrimary : Color.black)
                Text(formatted(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(isCoach ? AppDesign.textSecondary : Color.black.opacity(0.75))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isCoach
                        ? AnyShapeStyle(AppDesign.cardSecondary)
                        : AnyShapeStyle(
                            LinearGradient(colors: [AppDesign.accent, AppDesign.accent2], startPoint: .leading, endPoint: .trailing)
                        )
                    )
            )
            if isCoach { Spacer(minLength: 36) }
        }
    }
    
    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sr_RS")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let last = viewModel.messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last, anchor: .bottom)
        }
    }
}
