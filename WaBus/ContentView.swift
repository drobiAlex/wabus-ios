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
                ConnectionStatusView(state: viewModel.connectionState)
                    .padding(.top, 4)
                Spacer()
                FilterBarView(viewModel: viewModel)
            }
        }
        .sheet(item: $viewModel.selectedVehicle) { vehicle in
            VehicleDetailSheet(vehicle: vehicle)
                .environment(viewModel)
        }
        .sheet(isPresented: $viewModel.showLineList) {
            LineListView()
                .environment(viewModel)
        }
        .task {
            viewModel.start()
        }
    }
}

#Preview {
    ContentView()
}
