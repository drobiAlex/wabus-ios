import SwiftUI

struct StopScheduleView: View {
    let stop: Stop

    @State private var lines: [StopLine] = []
    @State private var allArrivals: [StopTime] = []
    @State private var isLoading = true
    @State private var selectedLine: String?

    private var filteredArrivals: [StopTime] {
        guard let selectedLine else { return allArrivals }
        return allArrivals.filter { $0.line == selectedLine }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !lines.isEmpty {
                            Section("Lines at this stop") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(lines) { line in
                                            let isSelected = selectedLine == line.line
                                            Button {
                                                withAnimation {
                                                    selectedLine = isSelected ? nil : line.line
                                                }
                                            } label: {
                                                Text(line.line)
                                                    .font(.headline)
                                                    .foregroundStyle(isSelected ? .white : line.displayColor)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        isSelected ? line.displayColor : line.displayColor.opacity(0.15),
                                                        in: RoundedRectangle(cornerRadius: 8)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        if !filteredArrivals.isEmpty {
                            Section(selectedLine != nil ? "Arrivals for \(selectedLine!)" : "Upcoming Arrivals") {
                                ForEach(filteredArrivals) { arrival in
                                    HStack {
                                        Text(arrival.line)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .frame(width: 44)
                                            .padding(.vertical, 4)
                                            .background(.blue, in: RoundedRectangle(cornerRadius: 6))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(arrival.headsign)
                                                .font(.subheadline)
                                            Text(arrival.arrivalTime)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if let date = arrival.arrivalDate {
                                            let minutes = Int(date.timeIntervalSinceNow / 60)
                                            if minutes <= 0 {
                                                Text("Now")
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(.green)
                                            } else {
                                                Text("\(minutes) min")
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if lines.isEmpty && allArrivals.isEmpty {
                            ContentUnavailableView("No Schedule", systemImage: "calendar.badge.exclamationmark", description: Text("No schedule data available for this stop."))
                        }
                    }
                }
            }
            .navigationTitle(stop.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        async let fetchedLines: [StopLine] = {
            do { return try await WaBusClient.shared.getStopLines(id: stop.id) }
            catch { return [] }
        }()
        async let fetchedSchedule: [StopTime] = {
            do { return try await WaBusClient.shared.getStopSchedule(id: stop.id) }
            catch { return [] }
        }()

        let (linesResult, scheduleResult) = await (fetchedLines, fetchedSchedule)

        // Deduplicate lines by line number
        var seenLines = Set<String>()
        let uniqueLines = linesResult.filter { seenLines.insert($0.line).inserted }

        // Deduplicate arrivals by tripId and filter to future only
        let now = Date()
        var seenTrips = Set<String>()
        let futureArrivals = scheduleResult
            .filter { seenTrips.insert($0.tripId).inserted }
            .filter { stopTime in
                guard let date = stopTime.arrivalDate else { return false }
                return date > now
            }
            .sorted { a, b in
                guard let da = a.arrivalDate, let db = b.arrivalDate else { return false }
                return da < db
            }
            .prefix(20)

        lines = uniqueLines
        allArrivals = Array(futureArrivals)
        isLoading = false
    }
}
