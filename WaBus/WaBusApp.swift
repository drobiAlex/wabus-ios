//
//  WaBusApp.swift
//  WaBus
//
//  Created by Oleksandr Drobinin on 05/02/2026.
//

import SwiftUI

@main
struct WaBusApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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
