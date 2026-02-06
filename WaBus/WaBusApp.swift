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
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading transit data...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
