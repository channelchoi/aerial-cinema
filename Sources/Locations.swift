import Foundation

struct PlaceName: Equatable {
    let chinese: String
    let english: String
    static let unknown = PlaceName(chinese: "地点未知", english: "Location unknown")
}

/// Resolve the UUID in the local filename through Apple's catalog, never queue order.
struct LocationCatalog {
    private struct Manifest: Decodable { let assets: [Asset] }
    private struct Asset: Decodable {
        let id: String
        let accessibilityLabel: String?
    }
    private var places: [String: PlaceName] = [:]
    private static let cities: [String: PlaceName] = [
        "new york": PlaceName(chinese: "纽约 · 美国", english: "New York · United States"),
        "san francisco": PlaceName(chinese: "旧金山 · 美国", english: "San Francisco · United States"),
        "los angeles": PlaceName(chinese: "洛杉矶 · 美国", english: "Los Angeles · United States"),
        "london": PlaceName(chinese: "伦敦 · 英国", english: "London · United Kingdom"),
        "dubai": PlaceName(chinese: "迪拜 · 阿联酋", english: "Dubai · United Arab Emirates"),
        "hong kong": PlaceName(chinese: "香港 · 中国", english: "Hong Kong · China")
    ]

    init(manifestURLs: [URL]) {
        for url in manifestURLs {
            guard let data = try? Data(contentsOf: url),
                  let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { continue }
            for asset in manifest.assets where places[asset.id.uppercased()] == nil {
                guard let label = asset.accessibilityLabel?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                      let place = Self.cities[label] else { continue }
                places[asset.id.uppercased()] = place
            }
        }
    }
    func place(forVideo url: URL) -> PlaceName {
        places[url.deletingPathExtension().lastPathComponent.uppercased()] ?? .unknown
    }
    static func manifestURLs(for directories: [URL]) -> [URL] {
        var result: [URL] = []
        for directory in directories {
            let parent = directory.deletingLastPathComponent()
            for url in [parent.appendingPathComponent("manifest/entries.json"),
                        parent.appendingPathComponent("entries.json"),
                        directory.appendingPathComponent("entries.json")] where !result.contains(url) {
                result.append(url)
            }
        }
        return result
    }
}
