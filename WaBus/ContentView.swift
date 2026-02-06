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
                        .padding(.top, 8)
                        .padding(.trailing, 16)
                }
                Spacer()

                if let vehicle = viewModel.selectedVehicle {
                    VehicleRouteBar(vehicle: vehicle)
                        .environment(viewModel)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 4)
                }

                FilterBarView(viewModel: viewModel)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $viewModel.showVehicleDetail) {
            if let vehicle = viewModel.selectedVehicle {
                VehicleDetailSheet(vehicle: vehicle)
                    .environment(viewModel)
            }
        }
        .sheet(item: $viewModel.selectedStop) { stop in
            StopScheduleView(stop: stop)
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
