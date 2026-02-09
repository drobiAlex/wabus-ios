//
//  ContentView.swift
//  WaBus
//
//  Created by Oleksandr Drobinin on 05/02/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = MapViewModel()

    var body: some View {
        ZStack {
            MapContentView(viewModel: viewModel)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    ConnectionStatusView(state: viewModel.connectionState)
                        .padding(.top, DS.Spacing.sm)
                        .padding(.trailing, DS.Spacing.md)
                }
                Spacer()
            }
        }
        .sheet(isPresented: .constant(true)) {
            BottomSheetContent(viewModel: viewModel)
                .presentationDetents(
                    [.height(90), .medium, .large],
                    selection: $viewModel.selectedDetent
                )
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled()
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(44)
        }
        .task {
            viewModel.start()
        }
    }
}

#Preview {
    ContentView()
}
