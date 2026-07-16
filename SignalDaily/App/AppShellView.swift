import SwiftUI

struct AppShellView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var todayViewModel: TodayViewModel
    @State private var preferencesStore: PreferencesStore
    @State private var subscriptionStore: SubscriptionStore
    @State private var authStore: AuthStore
    @State private var savedStoriesStore = SavedStoriesStore()
    @State private var readingLedger = ReadingLedger()
    @State private var selectedTab: AppTab = .today
    @State private var todayPath: [AppRoute] = []
    @State private var donePath: [AppRoute] = []
    @State private var savedPath: [AppRoute] = []
    @State private var settingsPath: [AppRoute] = []

    init(environment: AppEnvironment = .current) {
        let service = environment.briefingService
        _todayViewModel = State(initialValue: TodayViewModel(service: service))
        _preferencesStore = State(initialValue: PreferencesStore(service: service))
        _subscriptionStore = State(initialValue: SubscriptionStore(service: environment.subscriptionService))
        _authStore = State(initialValue: AuthStore(service: environment.authService))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            navigationStack(path: $todayPath) {
                TodayBriefingView(viewModel: todayViewModel) {
                    selectedTab = .settings
                }
            }
            .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.systemImage) }
            .tag(AppTab.today)

            navigationStack(path: $donePath) {
                LibraryView()
            }
            .tabItem { Label(AppTab.done.title, systemImage: AppTab.done.systemImage) }
            .tag(AppTab.done)

            navigationStack(path: $savedPath) {
                SavedStoriesView()
            }
            .tabItem { Label(AppTab.saved.title, systemImage: AppTab.saved.systemImage) }
            .tag(AppTab.saved)

            navigationStack(path: $settingsPath) {
                SettingsView(preferencesStore: preferencesStore)
            }
            .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage) }
            .tag(AppTab.settings)
        }
        .tint(.signalInk)
        .environment(todayViewModel)
        .environment(preferencesStore)
        .environment(subscriptionStore)
        .environment(authStore)
        .environment(savedStoriesStore)
        .environment(readingLedger)
        .fullScreenCover(isPresented: Binding(
            get: { !authStore.isSignedIn || !hasCompletedOnboarding },
            set: { _ in }
        )) {
            if authStore.isSignedIn {
                NavigationStack {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                    .navigationDestination(for: AppRoute.self) { route in
                        DestinationView(route: route)
                    }
                }
                .environment(todayViewModel)
                .environment(preferencesStore)
                .environment(subscriptionStore)
                .environment(authStore)
                .environment(savedStoriesStore)
                .environment(readingLedger)
                .interactiveDismissDisabled(true)
            } else {
                AuthView(authStore: authStore)
                    .interactiveDismissDisabled(true)
            }
        }
        .task {
            await authStore.restoreSession()
        }
    }

    private func navigationStack<Content: View>(
        path: Binding<[AppRoute]>,
        @ViewBuilder root: () -> Content
    ) -> some View {
        NavigationStack(path: path) {
            root()
                .navigationDestination(for: AppRoute.self) { route in
                    DestinationView(route: route)
                }
        }
    }
}

private struct DestinationView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(TodayViewModel.self) private var todayViewModel
    @Environment(PreferencesStore.self) private var preferencesStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    let route: AppRoute

    var body: some View {
        switch route {
        case .onboarding:
            OnboardingView()
        case .preferencesSetup:
            PreferencesSetupView(preferencesStore: preferencesStore) {
                hasCompletedOnboarding = true
            }
        case .section(let sectionID):
            SectionDetailView(section: todayViewModel.section(id: sectionID))
        case .story(let storyID):
            StoryDetailView(storyID: storyID)
        case .evidenceCheck(let storyID):
            EvidenceCheckView(storyID: storyID)
        case .depthAnalysis(let storyID):
            DepthAnalysisView(storyID: storyID)
        case .sources(let storyID):
            SourceTransparencyView(storyID: storyID)
        case .biasExplanation(let storyID):
            BiasFramingExplanationView(storyID: storyID)
        case .subscription:
            SubscriptionView(subscriptionStore: subscriptionStore)
        }
    }
}
