//
//  HomeView.swift
//  Everything
//
//  Created by Karen Karapetyan on 16.04.26.
//

import SwiftUI
import FirebaseAuth

enum HomeMenuItem: String, CaseIterable, Identifiable {
    case chats
    case ai
    case apps
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chats:
            return "Chats"
        case .ai:
            return "AI"
        case .apps:
            return "Apps"
        case .settings:
            return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .chats:
            return "ellipsis.message"
        case .ai:
            return "sparkles"
        case .apps:
            return "square.grid.2x2"
        case .settings:
            return "gearshape"
        }
    }

    var description: String {
        switch self {
        case .chats:
            return "Browse conversations and jump back into recent threads."
        case .ai:
            return "Access AI tools, workflows, and generated content."
        case .apps:
            return "See installed apps, add more tools, and manage your workspace library."
        case .settings:
            return "Adjust preferences for the app and your workspace."
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isSearchFieldFocused: Bool

    @State private var selectedItem: HomeMenuItem? = .chats
    @StateObject private var appLibrary = WorkspaceAppLibrary()
    @State private var isProfilePresented = false
    @State private var isSearchExpanded = false
    @State private var searchText = ""

    private var avatarInitials: String {
        let name = authService.currentUser?.displayName ?? ""
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
        }
        if !name.isEmpty {
            return String(name.prefix(2)).uppercased()
        }
        return (authService.currentUser?.email?.prefix(2) ?? "?").uppercased()
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactHomeView
            } else {
                regularHomeView
            }
        }
        .sheet(isPresented: $isProfilePresented) {
            ProfileView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: isSearchExpanded) { _, isExpanded in
            if isExpanded {
                isSearchFieldFocused = true
            }
        }
    }

    private var compactSelection: Binding<HomeMenuItem> {
        Binding(
            get: { selectedItem ?? .chats },
            set: { selectedItem = $0 }
        )
    }

    private var regularHomeView: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            ZStack {
                BackgroundView()
                detailView(for: selectedItem ?? .chats)
            }
        }
    }

    private var compactHomeView: some View {
        TabView(selection: compactSelection) {
            ConversationListView()
                .tabItem {
                    Label(HomeMenuItem.chats.title, systemImage: HomeMenuItem.chats.icon)
                }
                .tag(HomeMenuItem.chats)

            compactWrappedDetail(for: .ai)
                .tabItem {
                    Label(HomeMenuItem.ai.title, systemImage: HomeMenuItem.ai.icon)
                }
                .tag(HomeMenuItem.ai)

            compactWrappedDetail(for: .apps)
                .tabItem {
                    Label(HomeMenuItem.apps.title, systemImage: HomeMenuItem.apps.icon)
                }
                .tag(HomeMenuItem.apps)

            compactWrappedDetail(for: .settings)
                .tabItem {
                    Label(HomeMenuItem.settings.title, systemImage: HomeMenuItem.settings.icon)
                }
                .tag(HomeMenuItem.settings)
        }
    }

    private func compactWrappedDetail(for item: HomeMenuItem) -> some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                detailView(for: item)
            }
        }
    }

    private var sidebarContent: some View {
        ZStack {
            BackgroundView()

            VStack(alignment: .leading, spacing: 20) {
                sidebarHeader

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Menu")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        ForEach(filteredItems) { item in
                            sidebarItemButton(for: item)
                        }

                        if filteredItems.isEmpty {
                            ContentUnavailableView(
                                "No Results",
                                systemImage: "magnifyingglass",
                                description: Text("Try another search term.")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 36)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func detailView(for item: HomeMenuItem) -> some View {
        switch item {
        case .chats:
            ConversationListView()
        case .ai:
            AppWorkspacePlaceholderView(app: appLibrary.app(for: .ai))
        case .apps:
            AppsLibraryView(appLibrary: appLibrary) { menuItem in
                selectedItem = menuItem
            }
        case .settings:
            VStack(alignment: .leading, spacing: 16) {
                Text(item.title)
                    .font(.largeTitle.bold())

                Text(item.description)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button("Open Profile") {
                    isProfilePresented = true
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            .navigationTitle(item.title)
        }
    }

    private var filteredItems: [HomeMenuItem] {
        guard !searchText.isEmpty else { return HomeMenuItem.allCases }

        return HomeMenuItem.allCases.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText)
                || item.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sidebarHeader: some View {
        Group {
            if isSearchExpanded {
                expandedSearchBar
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                HStack(spacing: 12) {
                    Text("Eve")
                        .font(.system(size: 34, weight: .bold, design: .default))

                    Spacer()

                    compactActionCluster
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearchExpanded)
    }

    @ViewBuilder
    private func sidebarItemButton(for item: HomeMenuItem) -> some View {
        if horizontalSizeClass == .compact {
            NavigationLink {
                ZStack {
                    BackgroundView()
                    detailView(for: item)
                }
            } label: {
                sidebarItemLabel(for: item)
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    selectedItem = item
                }
            )
            .buttonStyle(.plain)
        } else {
            Button {
                selectedItem = item
            } label: {
                sidebarItemLabel(for: item)
            }
            .buttonStyle(.plain)
        }
    }

    private func sidebarItemLabel(for item: HomeMenuItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 22)

            Text(item.title)
                .font(.body.weight(.medium))

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(selectionBackground(for: item))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func selectionBackground(for item: HomeMenuItem) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(selectedItem == item ? selectedFillColor : .clear)
    }

    private var compactActionCluster: some View {
        HStack(spacing: 0) {
            Button(action: expandSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            clusterDivider

            avatarButton
                .padding(.leading, 6)
                .padding(.trailing, 3)
        }
        .padding(.vertical, 3)
        .padding(.leading, 3)
        .background(clusterSurface)
        .clipShape(Capsule(style: .continuous))
    }

    private var expandedSearchBar: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 16)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFieldFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 14)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            } else {
                Button(action: collapseSearch) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }

            clusterDivider
                .padding(.vertical, 8)

            avatarButton
                .padding(.leading, 8)
                .padding(.trailing, 6)
        }
        .frame(maxWidth: .infinity)
        .background(clusterSurface)
        .clipShape(Capsule(style: .continuous))
    }

    private var avatarButton: some View {
        Button(action: { isProfilePresented = true }) {
            Text(avatarInitials)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.94, green: 0.53, blue: 0.42),
                                    Color(red: 0.87, green: 0.33, blue: 0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var clusterDivider: some View {
        Rectangle()
            .fill(colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.10))
            .frame(width: 1, height: 24)
    }

    private var selectedFillColor: Color {
        colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.10)
    }

    private var clusterSurface: some View {
        Capsule(style: .continuous)
            .fill(colorScheme == .light ? Color.white.opacity(0.88) : Color.white.opacity(0.10))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        colorScheme == .light ? Color.white.opacity(0.70) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: colorScheme == .light ? Color.black.opacity(0.08) : .clear,
                radius: 20,
                x: 0,
                y: 10
            )
    }

    private func expandSearch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearchExpanded = true
        }
    }

    private func collapseSearch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearchExpanded = false
            searchText = ""
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService())
}
