//
//  WaBusApp.swift
//  WaBus
//
//  Created by Oleksandr Drobinin on 05/02/2026.
//

import SwiftUI

@main
struct WaBusApp: App {
    @State private var isSyncing = true
    @State private var syncError: Error?

    var body: some Scene {
        WindowGroup {
            Group {
                if isSyncing {
                    SyncLoadingView()
                } else if syncError != nil {
                    SyncErrorView {
                        syncError = nil
                        isSyncing = true
                        Task { await performInitialSync() }
                    }
                } else {
                    ContentView()
                }
            }
            .task {
                await performInitialSync()
            }
        }
    }

    private func performInitialSync() async {
        do {
            await GTFSSyncManager.shared.syncIfNeeded()
            isSyncing = false
        } catch {
            syncError = error
            isSyncing = false
        }
    }
}

// MARK: - Sync Loading View

private struct SyncLoadingView: View {
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "bus.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)

            Text("Loading transit data...")
                .font(DS.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Sync Error View

private struct SyncErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            VStack(spacing: DS.Spacing.sm) {
                Text("Unable to load data")
                    .font(DS.headline)
                Text("Check your internet connection and try again.")
                    .font(DS.small)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onRetry) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(DS.bodyBold)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
                    .background(.blue, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .foregroundStyle(.white)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
