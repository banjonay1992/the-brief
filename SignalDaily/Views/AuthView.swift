import AuthenticationServices
import SwiftUI
import UIKit

struct AuthView: View {
    @Bindable var authStore: AuthStore
    @State private var appleWebSession: ASWebAuthenticationSession?
    @State private var appleWebPresentationContext = AppleWebAuthenticationPresentationContextProvider()

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)

            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Text("The Brief")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.signalInk)
                    Text(authStore.mode == .signUp ? "Create your calm account" : "Welcome back")
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundStyle(Color.signalInk)
                        .multilineTextAlignment(.center)
                    Text("One daily briefing, saved preferences, and a clean end point.")
                        .font(.subheadline)
                        .foregroundStyle(Color.signalMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 310)
                }

                Picker("Account mode", selection: Binding(
                    get: { authStore.mode },
                    set: { authStore.switchMode($0) }
                )) {
                    ForEach(AuthMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 12) {
                    if authStore.mode == .signUp {
                        CalmTextField(
                            title: "Name",
                            text: $authStore.name,
                            systemImage: "person"
                        )
                        .textContentType(.name)
                    }

                    CalmTextField(
                        title: "Email",
                        text: $authStore.email,
                        systemImage: "envelope"
                    )
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                    CalmSecureField(
                        title: "Password",
                        text: $authStore.password,
                        systemImage: "lock"
                    )
                    .textContentType(authStore.mode == .signUp ? .newPassword : .password)
                }

                if let errorMessage = authStore.errorMessage {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(errorMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.signalClay)
                        if let diagnostic = authStore.appleDiagnosticMessage {
                            Text(diagnostic)
                                .font(.caption2.monospaced())
                                .foregroundStyle(Color.signalMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("authErrorMessage")
                }

                Button {
                    Task { await authStore.submit() }
                } label: {
                    HStack {
                        if authStore.isWorking {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(authStore.mode == .signUp ? "Create account" : "Sign in")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.signalInk)
                .disabled(authStore.isWorking)

                AppleNativeSignInButton(authStore: authStore)
                    .frame(height: 50)
                    .disabled(authStore.isWorking)
                    .accessibilityIdentifier("primaryAppleNativeSignInButton")

                if AuthLayout.showsBrowserAppleFallback, authStore.shouldOfferAppleWebFallback {
                    AppleBrowserSignInButton(mode: authStore.mode) {
                        startAppleBrowserAuthorization()
                    }
                    .frame(height: 44)
                    .disabled(authStore.isWorking)
                    .opacity(0.72)
                    .accessibilityIdentifier("fallbackAppleBrowserSignInButton")
                }

                #if DEBUG
                Button {
                    authStore.signInAsDeveloper()
                } label: {
                    Label("Developer access", systemImage: "hammer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.signalSage)
                .disabled(authStore.isWorking)
                .accessibilityIdentifier("developerAccessButton")
                #endif

                Text("No feeds, no public profile, no social loop.")
                    .font(.caption)
                    .foregroundStyle(Color.signalMuted)

                Text("Build \(AppBuildInfo.buildNumber)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.signalMuted.opacity(0.68))
                    .accessibilityIdentifier("buildNumberLabel")
            }
            .padding(22)
            .padding(.horizontal, AuthLayout.horizontalPadding)

            Spacer(minLength: 28)
        }
        .padding(.vertical, 18)
        .signalScreen()
    }

    private func startAppleBrowserAuthorization() {
        Task {
            guard let authorizationURL = await authStore.startAppleWebAuthorization() else { return }

            await MainActor.run {
                let session = ASWebAuthenticationSession(
                    url: authorizationURL,
                    callbackURLScheme: "thebrief"
                ) { callbackURL, error in
                    Task { @MainActor in
                        defer { appleWebSession = nil }
                        if let callbackURL {
                            await authStore.completeAppleWebAuthorization(callbackURL: callbackURL)
                        } else {
                            authStore.handleAppleWebAuthorizationFailure(error)
                        }
                    }
                }
                session.presentationContextProvider = appleWebPresentationContext
                session.prefersEphemeralWebBrowserSession = true
                appleWebSession = session
                if !session.start() {
                    authStore.handleAppleWebAuthorizationFailure(nil)
                    appleWebSession = nil
                }
            }
        }
    }
}

enum AuthLayout {
    static let horizontalPadding: CGFloat = 20
    static let usesOuterCardBorder = false
    static let usesManualAppleAuthorizationController = false
    static let showsBuildNumberOnAuthScreen = true
    static let usesNativeSwiftUIAppleButton = true
    static let usesBrowserAppleAsPrimary = false
    static let showsBrowserAppleFallback = false

    static func appleButtonType(for mode: AuthMode) -> ASAuthorizationAppleIDButton.ButtonType {
        mode == .signUp ? .signUp : .signIn
    }

    static func signInWithAppleLabel(for mode: AuthMode) -> SignInWithAppleButton.Label {
        mode == .signUp ? .signUp : .signIn
    }
}

enum AppBuildInfo {
    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }
}

private struct AppleNativeSignInButton: View {
    @Bindable var authStore: AuthStore

    var body: some View {
        SignInWithAppleButton(AuthLayout.signInWithAppleLabel(for: authStore.mode)) { request in
            authStore.prepareAppleAuthorization(request)
        } onCompletion: { result in
            Task { await authStore.handleAppleAuthorization(result) }
        }
        .signInWithAppleButtonStyle(.black)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel(authStore.mode == .signUp ? "Sign up with Apple" : "Sign in with Apple")
        .id(authStore.mode)
    }
}

private struct AppleBrowserSignInButton: UIViewRepresentable {
    var mode: AuthMode
    var onTap: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: AuthLayout.appleButtonType(for: mode),
            authorizationButtonStyle: .black
        )
        button.cornerRadius = 14
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didTapAppleButton),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject {
        var onTap: () -> Void

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        @objc func didTapAppleButton() {
            onTap()
        }
    }
}

struct AppleAuthorizationButton: UIViewRepresentable {
    var authStore: AuthStore

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: appleButtonType,
            authorizationButtonStyle: .black
        )
        button.cornerRadius = 14
        button.addTarget(
            context.coordinator,
            action: #selector(AppleAuthorizationCoordinator.startAuthorization),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.authStore = authStore
    }

    func makeCoordinator() -> AppleAuthorizationCoordinator {
        AppleAuthorizationCoordinator(authStore: authStore)
    }

    private var appleButtonType: ASAuthorizationAppleIDButton.ButtonType {
        AuthLayout.appleButtonType(for: authStore.mode)
    }
}

@MainActor
final class AppleAuthorizationCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var authStore: AuthStore
    private var authorizationController: ASAuthorizationController?

    init(authStore: AuthStore) {
        self.authStore = authStore
    }

    @objc func startAuthorization() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        authStore.prepareAppleAuthorization(request)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        authorizationController = controller
        controller.performRequests()
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            await authStore.handleAppleAuthorization(.success(authorization))
            authorizationController = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            authStore.handleAppleAuthorizationFailure(error)
            authorizationController = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

final class AppleWebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

private struct CalmTextField: View {
    let title: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.signalSage)
                .frame(width: 22)
            TextField(title, text: $text)
                .font(.body)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.signalSurface.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.signalLine.opacity(0.75), lineWidth: 1)
        )
    }
}

private struct CalmSecureField: View {
    let title: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.signalSage)
                .frame(width: 22)
            SecureField(title, text: $text)
                .font(.body)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.signalSurface.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.signalLine.opacity(0.75), lineWidth: 1)
        )
    }
}
