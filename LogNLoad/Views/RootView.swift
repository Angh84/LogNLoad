import SwiftUI

/// Onboarding until its Continue is tapped, then the tabs on every launch.
struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView { hasCompletedOnboarding = true }
        }
    }
}
