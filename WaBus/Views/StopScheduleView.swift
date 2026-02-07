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
        Dictionary(uniqueKeysWithValues: lines.map { ($0.line, $0.type.color) })
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ScheduleSkeletonView()
                } else {
                    List {
                        if !lines.isEmpty {
                            Section {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: DS.Spacing.sm) {
                                        // "All" pill
                                        Button {
                                            withAnimation(DS.spring) {
                                                selectedLine = nil
                                            }
                                        } label: {
                                            Text("All")
                                                .font(.headline)
                                                .foregroundStyle(selectedLine == nil ? .white : .secondary)
                                                .padding(.horizontal, DS.Spacing.sm + DS.Spacing.xs)
                                                .padding(.vertical, 6)
                                                .background(
                                                    selectedLine == nil ? Color.blue : Color.blue.opacity(0.15),
                                                    in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Show all lines")
                                        .accessibilityValue(selectedLine == nil ? "selected" : "not selected")

                                        ForEach(lines) { line in
                                            let isSelected = selectedLine == line.line
                                            Button {
                                                withAnimation(DS.spring) {
                                                    selectedLine = isSelected ? nil : line.line
                                                }
                                            } label: {
                                                Text(line.line)
                                                    .font(.headline)
                                                    .foregroundStyle(isSelected ? .white : line.type.color)
                                                    .padding(.horizontal, DS.Spacing.sm + DS.Spacing.xs)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        isSelected ? line.type.color : line.type.color.opacity(0.15),
                                                        in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("Line \(line.line)")
                                            .accessibilityValue(isSelected ? "selected" : "not selected")
                                        }
                                    }
                                    .padding(.vertical, DS.Spacing.xs)
                                }
                            } header: {
                                Text("Lines at this stop")
                            }
                        }

                        if !filteredArrivals.isEmpty {
                            Section {
                                ForEach(filteredArrivals) { arrival in
                                    arrivalRow(arrival)
                                }
                            } header: {
                                HStack {
                                    if let selectedLine {
                                        Text("Arrivals for \(selectedLine)")
                                        Spacer()
                                        Button("Clear") {
                                            withAnimation(DS.spring) {
                                                self.selectedLine = nil
                                            }
                                        }
                                        .font(DS.small)
                                    } else {
                                        Text("Upcoming Arrivals")
                                    }
                                }
                            }
                        }

                        if lines.isEmpty && allArrivals.isEmpty {
                            ContentUnavailableView(
                                "No Upcoming Arrivals",
                                systemImage: "calendar.badge.exclamationmark",
                                description: Text("No scheduled arrivals in the next 2 hours for this stop.")
                            )
                        } else if filteredArrivals.isEmpty && selectedLine != nil {
                            ContentUnavailableView(
                                "No Arrivals for Line \(selectedLine!)",
                                systemImage: "bus",
                                description: Text("No upcoming arrivals for this line. Try selecting a different line.")
                            )
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
        .presentationDetents([.medium, .large])
        .task {
            await loadData()
        }
    }

    // MARK: - Arrival Row

    private func arrivalRow(_ arrival: StopTime) -> some View {
        HStack {
            Text(arrival.line)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: DS.Size.minTapTarget)
                .padding(.vertical, DS.Spacing.xs)
                .background(lineColors[arrival.line] ?? .blue, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(arrival.headsign)
                    .font(.subheadline)
                Text(arrival.displayTime)
                    .font(DS.small)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let date = arrival.arrivalDate {
                let totalMinutes = Int(date.timeIntervalSinceNow / 60)
                if totalMinutes <= 0 {
                    Text("Now")
                        .font(DS.bodyBold)
                        .foregroundStyle(.green)
                } else if totalMinutes <= 15 {
                    Text("\(totalMinutes) min")
                        .font(DS.bodyBold)
                        .foregroundStyle(.blue)
                } else if totalMinutes < 60 {
                    Text("\(totalMinutes) min")
                        .font(DS.bodyBold)
                        .foregroundStyle(.secondary)
                } else {
                    let h = totalMinutes / 60
                    let m = totalMinutes % 60
                    Text("\(h)h \(m)m")
                        .font(DS.bodyBold)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityLabel("Line \(arrival.line) to \(arrival.headsign)")
        .accessibilityValue(arrivalAccessibilityValue(arrival))
    }

    private func arrivalAccessibilityValue(_ arrival: StopTime) -> String {
        guard let date = arrival.arrivalDate else { return arrival.displayTime }
        let totalMinutes = Int(date.timeIntervalSinceNow / 60)
        if totalMinutes <= 0 { return "arriving now" }
        if totalMinutes < 60 { return "in \(totalMinutes) minutes" }
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "in \(h) hour\(h > 1 ? "s" : "") \(m) minutes"
    }

    // MARK: - Data

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

        var seenLines = Set<String>()
        let uniqueLines = linesResult.filter { seenLines.insert($0.line).inserted }

        var seenTrips = Set<String>()
        let uniqueArrivals = scheduleResult
            .filter { seenTrips.insert($0.tripId).inserted }
            .prefix(30)

        lines = uniqueLines
        allArrivals = Array(uniqueArrivals)
        isLoading = false
    }
}
