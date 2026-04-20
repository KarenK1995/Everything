//
//  AuthService.swift
//  Everything
//
//  Created by Karen Karapetyan on 16.04.26.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import UIKit

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: FirebaseAuth.User?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var currentNonce: String?
    private var stateListener: AuthStateDidChangeListenerHandle?

    init() {
        currentUser = Auth.auth().currentUser
        stateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                if let user {
                    await UserSyncService.syncUser(user)
                }
            }
        }
    }

    deinit {
        if let handle = stateListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Apple Sign In

    /// Call from SignInWithAppleButton's onRequest. Returns the hashed nonce to set on the request.
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        switch result {
        case .failure(let error):
            let code = (error as? ASAuthorizationError)?.code
            if code != .canceled && code != .unknown {
                errorMessage = error.localizedDescription
            }

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Sign in failed. Please try again."
                return
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: credential.fullName
            )

            do {
                try await Auth.auth().signIn(with: firebaseCredential)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle() {
        errorMessage = nil
        Task {
            await performGoogleSignIn()
        }
    }

    private func performGoogleSignIn() async {
        isLoading = true
        defer { isLoading = false }

        guard let options = FirebaseApp.app()?.options else {
            errorMessage = "Google Sign-In is unavailable because Firebase is not configured."
            return
        }

        guard let clientID = options.clientID else {
            errorMessage = "Google Sign-In needs CLIENT_ID and REVERSED_CLIENT_ID in GoogleService-Info.plist."
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presentingViewController = topViewController() else {
            errorMessage = "Could not start Google Sign-In from the current screen."
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google Sign-In did not return an ID token."
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            try await Auth.auth().signIn(with: credential)
        } catch {
            let nsError = error as NSError
            if nsError.code != GIDSignInError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            GIDSignIn.sharedInstance.signOut()
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async {
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await user.delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var byte: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
                return byte
            }
            for byte in randoms {
                guard remaining > 0 else { break }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let rootViewController = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController

        return topViewController(from: rootViewController)
    }

    private func topViewController(from controller: UIViewController?) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }

        if let tabBarController = controller as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }

        if let presentedViewController = controller?.presentedViewController {
            return topViewController(from: presentedViewController)
        }

        return controller
    }
}
