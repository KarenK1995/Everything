//
//  AppsLibraryView.swift
//  Everything
//
//  Created by OpenAI Codex on 18.04.26.
//

import SwiftUI

struct AppsLibraryView: View {
    @ObservedObject var appLibrary: WorkspaceAppLibrary
    let openMenuItem: (HomeMenuItem) -> Void

    @State private var previewedAppID: WorkspaceAppID?

    private var previewedApp: WorkspaceApp? {
        guard let previewedAppID else { return nil }
        return appLibrary.app(for: previewedAppID)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                heroCard

                if let previewedApp {
                    previewCard(for: previewedApp)
                }

                installedSection

                if !appLibrary.availableApps.isEmpty {
                    availableSection
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .navigationTitle("Apps")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Apps")
                .font(.system(size: 34, weight: .black, design: .rounded))

            Text("Chats and AI are installed from the start. Add the rest of the workspace apps here and they will stay under Apps.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                LibraryMetricCard(
                    title: "Installed",
                    value: "\(appLibrary.installedApps.count)",
                    icon: "square.grid.2x2.fill"
                )
                LibraryMetricCard(
                    title: "Available",
                    value: "\(appLibrary.availableApps.count)",
                    icon: "plus.circle.fill"
                )
                LibraryMetricCard(
                    title: "Included",
                    value: "\(appLibrary.fixedAppIDs.count)",
                    icon: "star.fill"
                )
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.90),
                            Color(red: 0.97, green: 0.98, blue: 1.0).opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 24, x: 0, y: 14)
    }

    private var installedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Installed Apps")
                .font(.title3.bold())

            ForEach(appLibrary.installedApps) { app in
                AppCard(
                    app: app,
                    buttonTitle: app.id == .chats || app.id == .ai ? "Open" : "Preview",
                    trailingTitle: app.isPreinstalled ? nil : "Remove",
                    onPrimaryAction: { handlePrimaryAction(for: app) },
                    onSecondaryAction: app.isPreinstalled ? nil : {
                        appLibrary.remove(app)
                        if previewedAppID == app.id {
                            previewedAppID = nil
                        }
                    }
                )
            }
        }
    }

    private var availableSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Available To Add")
                .font(.title3.bold())

            ForEach(appLibrary.availableApps) { app in
                AppCard(
                    app: app,
                    buttonTitle: "Add",
                    trailingTitle: nil,
                    onPrimaryAction: {
                        appLibrary.install(app)
                        previewedAppID = app.id
                    },
                    onSecondaryAction: nil
                )
            }
        }
    }

    private func previewCard(for app: WorkspaceApp) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                appIcon(for: app, size: 56)

                VStack(alignment: .leading, spacing: 6) {
                    Text(app.name)
                        .font(.title2.bold())
                    Text(app.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(app.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("What this app adds")
                    .font(.headline)

                ForEach(app.highlights, id: \.self) { highlight in
                    Label(highlight, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.primary)
                }
            }

            if app.id == .chats || app.id == .ai {
                Button("Open \(app.name)") {
                    handlePrimaryAction(for: app)
                }
                .buttonStyle(.borderedProminent)
                .tint(app.accent.first ?? .accentColor)
            }
        }
        .padding(22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func handlePrimaryAction(for app: WorkspaceApp) {
        switch app.id {
        case .chats:
            openMenuItem(.chats)
        case .ai:
            openMenuItem(.ai)
        default:
            previewedAppID = app.id
        }
    }

    private func appIcon(for app: WorkspaceApp, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(
                LinearGradient(
                    colors: app.accent,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: app.icon)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(.white)
            }
    }
}

struct AppWorkspacePlaceholderView: View {
    let app: WorkspaceApp

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: app.accent,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 84, height: 84)
                            .overlay {
                                Image(systemName: app.icon)
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(app.name)
                                .font(.system(size: 34, weight: .black, design: .rounded))
                            Text(app.subtitle)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(app.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        LibraryMetricCard(
                            title: "Focus",
                            value: app.highlights.first ?? "Ready",
                            icon: app.icon
                        )
                        LibraryMetricCard(
                            title: "Status",
                            value: "Installed",
                            icon: "checkmark.seal.fill"
                        )
                    }
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.thinMaterial)
                )

                VStack(alignment: .leading, spacing: 14) {
                    Text("Inside \(app.name)")
                        .font(.title3.bold())

                    ForEach(app.highlights, id: \.self) { highlight in
                        HStack(spacing: 14) {
                            Circle()
                                .fill((app.accent.first ?? .accentColor).opacity(0.16))
                                .frame(width: 38, height: 38)
                                .overlay {
                                    Image(systemName: "sparkle")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(app.accent.first ?? .accentColor)
                                }

                            Text(highlight)
                                .font(.body.weight(.medium))

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .navigationTitle(app.name)
    }
}

private struct AppCard: View {
    let app: WorkspaceApp
    let buttonTitle: String
    let trailingTitle: String?
    let onPrimaryAction: () -> Void
    let onSecondaryAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: app.accent,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .overlay {
                    Image(systemName: app.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.headline)
                        Text(app.subtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if app.isPreinstalled {
                        Text("Preinstalled")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.05), in: Capsule())
                    }
                }

                Text(app.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button(buttonTitle, action: onPrimaryAction)
                        .buttonStyle(.borderedProminent)
                        .tint(app.accent.first ?? .accentColor)

                    if let trailingTitle, let onSecondaryAction {
                        Button(trailingTitle, action: onSecondaryAction)
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct LibraryMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    AppsLibraryView(appLibrary: WorkspaceAppLibrary()) { _ in }
}
