//
//  AppRootView.swift
//  Everything
//
//  Created by Karen Karapetyan on 16.04.26.
//

import SwiftUI

struct AppRootView: View {
    
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        Group {
            if authService.currentUser != nil {
                HomeView()
            } else {
                SignInView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.currentUser == nil)
    }
}
