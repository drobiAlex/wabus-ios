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
    private var _ids: Set<String> = []

    init() {
        load()
    }

    func add(_ favourite: FavouriteLine) {
        guard _ids.insert(favourite.id).inserted else { return }
        lines.append(favourite)
        save()
    }

    func remove(_ favourite: FavouriteLine) {
        _ids.remove(favourite.id)
        lines.removeAll { $0.id == favourite.id }
        save()
    }

    func isFavourite(line: String, type: VehicleType) -> Bool {
        _ids.contains("\(type.rawValue)-\(line)")
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([FavouriteLine].self, from: data) else { return }
        lines = decoded
        _ids = Set(decoded.map(\.id))
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(lines) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
