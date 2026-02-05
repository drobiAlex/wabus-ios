import Foundation

struct FavouriteLine: Codable, Identifiable, Hashable {
    let line: String
    let type: VehicleType

    var id: String { "\(type.rawValue)-\(line)" }
}

@Observable
final class FavouritesStore {
    private static let key = "favourite_lines"

    var lines: [FavouriteLine] = []

    init() {
        load()
    }

    func add(_ favourite: FavouriteLine) {
        guard !lines.contains(where: { $0.id == favourite.id }) else { return }
        lines.append(favourite)
        save()
    }

    func remove(_ favourite: FavouriteLine) {
        lines.removeAll { $0.id == favourite.id }
        save()
    }

    func isFavourite(line: String, type: VehicleType) -> Bool {
        lines.contains { $0.line == line && $0.type == type }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([FavouriteLine].self, from: data) else { return }
        lines = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(lines) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
