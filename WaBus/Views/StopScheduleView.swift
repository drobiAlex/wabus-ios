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

    private var lineColors: [String: Color] {
        Dictionary(uniqueKeysWithValues: lines.map { ($0.line, $0.displayColor) })
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ScheduleSkeletonView()
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
                                            .background(lineColors[arrival.line] ?? .blue, in: RoundedRectangle(cornerRadius: 6))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(arrival.headsign)
                                                .font(.subheadline)
                                            Text(arrival.displayTime)
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if let date = arrival.arrivalDate {
                                            let totalMinutes = Int(date.timeIntervalSinceNow / 60)
                                            if totalMinutes <= 0 {
                                                Text("Now")
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                                    .foregroundStyle(.green)
                                            } else if totalMinutes < 60 {
                                                Text("\(totalMinutes) min")
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                                    .foregroundStyle(.blue)
                                            } else {
                                                let h = totalMinutes / 60
                                                let m = totalMinutes % 60
                                                Text(String(format: "%d:%02d", h, m))
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
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
            .refreshable {
                await ScheduleService.shared.clearCache(for: stop.id)
                await loadData()
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        async let fetchedLines: [StopLine] = {
            do { return try await ScheduleService.shared.getStopLines(stopId: stop.id) }
            catch { return [] }
        }()
        async let fetchedSchedule: [StopTime] = {
            do { return try await ScheduleService.shared.getUpcomingArrivals(stopId: stop.id, minutes: 120) }
            catch { return [] }
        }()

        let (linesResult, scheduleResult) = await (fetchedLines, fetchedSchedule)

        // Deduplicate lines by line number
        var seenLines = Set<String>()
        let uniqueLines = linesResult.filter { seenLines.insert($0.line).inserted }

        // Deduplicate arrivals by tripId
        var seenTrips = Set<String>()
        let uniqueArrivals = scheduleResult
            .filter { seenTrips.insert($0.tripId).inserted }
            .prefix(20)

        lines = uniqueLines
        allArrivals = Array(uniqueArrivals)
        isLoading = false
    }
}
