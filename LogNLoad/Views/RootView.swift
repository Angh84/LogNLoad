import SwiftData
import SwiftUI

/// Onboarding until its Continue is tapped, then the tabs on every launch. Every launch and every return from
/// the background retries the Health-pending Workouts.
struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(HealthSync.self) private var health
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView(onContinue: continueFromOnboarding)
            }
        }
        .task { await health.sync(in: context) }
        .onChange(of: scenePhase) { oldPhase, _ in
            if oldPhase == .background { Task { await health.sync(in: context) } }
        }
    }

    /// Continue raises the system Health sheet, then shows the tabs whatever the answer.
    private func continueFromOnboarding() {
        Task {
            await health.requestAuthorization()
            hasCompletedOnboarding = true
            await health.sync(in: context)
        }
    }
}
