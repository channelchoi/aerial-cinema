import Foundation

@main struct CoreTests {
    static func main() {
        var hold = EscapeHold()
        hold.press(at: 10)
        assert(!hold.isComplete(at: 14.999999))
        assert(hold.isComplete(at: 15))
        hold.press(at: 12, repeating: true)
        assert(hold.beganAt == 10)
        hold.cancel()
        assert(!hold.isComplete(at: 100))
        hold.press(at: 20)
        assert(hold.progress(at: 22.5) == 0.5)
        hold.cancel()
        hold.press(at: 30)
        assert(!hold.isComplete(at: 34.99))
        assert(hold.isComplete(at: 35))
        print("PASS: hold threshold, autorepeat, cancellation, restart")
        var bag = ShuffleBag<Int>()
        bag.update(Array(0..<6))
        var last: Int?
        for _ in 0..<1000 {
            let round = (0..<6).map { _ in bag.take()! }
            assert(Set(round).count == 6)
            assert(round.first != last)
            last = round.last
        }
        print("PASS: 1,000 random rounds, no repeats within/across round boundary")
        bag.update([6])
        assert(bag.take() == 6 && bag.take() == 6)
        bag.update([])
        assert(bag.take() == nil)
        bag.update([1, 2])
        let first = bag.take()!
        bag.update([1, 2, 3])
        let next = [bag.take()!, bag.take()!]
        assert(Set(next).count == 2 && !next.contains(first) && next.contains(3))
        let reserved = bag.take()!
        bag.putBack(reserved, lastPlayed: nil)
        assert(bag.take() == reserved)
        print("PASS: added files, deleted files, single/empty library, cancelled reservation")
        var gate = StableFileGate()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("aerial-cinema-stability-" + UUID().uuidString)
        try! Data([1, 2, 3]).write(to: url)
        let a = FileStamp(url: url)!
        assert(gate.accept([url: a]).isEmpty)
        assert(gate.accept([url: a]).count == 1)
        try! Data([1, 2, 3, 4]).write(to: url)
        let b = FileStamp(url: url)!
        assert(gate.accept([url: b]).isEmpty)
        assert(gate.accept([url: b]).count == 1)
        assert(gate.accept([:]).isEmpty)
        assert(gate.accept([url: b]).isEmpty)
        try! FileManager.default.removeItem(at: url)
        print("PASS: stable downloads, size change, disappearance/reappearance")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("aerial-locations-" + UUID().uuidString)
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = root.appendingPathComponent("entries.json")
        let cases = [
            ("New York", "纽约 · 美国", "New York · United States"),
            ("San Francisco", "旧金山 · 美国", "San Francisco · United States"),
            ("Los Angeles", "洛杉矶 · 美国", "Los Angeles · United States"),
            ("London", "伦敦 · 英国", "London · United Kingdom"),
            ("Dubai", "迪拜 · 阿联酋", "Dubai · United Arab Emirates"),
            ("Hong Kong", "香港 · 中国", "Hong Kong · China")
        ]
        var assets: [[String: Any]] = cases.enumerated().map { index, item in
            ["id": "ASSET-\(index)", "accessibilityLabel": item.0]
        }
        assets.append(["id": "UNSUPPORTED", "accessibilityLabel": "A region we cannot identify"])
        assets.append(["id": "UNLABELED"])
        try! JSONSerialization.data(withJSONObject: ["assets": assets.reversed().map { $0 }]).write(to: manifest)
        let catalog = LocationCatalog(manifestURLs: [manifest])
        for (index, item) in cases.enumerated() {
            let place = catalog.place(forVideo: root.appendingPathComponent("asset-\(index).MOV"))
            assert(place.chinese == item.1 && place.english == item.2)
        }
        for filename in ["UNSUPPORTED.mov", "UNLABELED.mp4", "London.mov", "missing.mov"] {
            assert(catalog.place(forVideo: root.appendingPathComponent(filename)) == .unknown)
        }
        try! Data("corrupt manifest".utf8).write(to: manifest)
        assert(LocationCatalog(manifestURLs: [manifest]).place(forVideo: root.appendingPathComponent("ASSET-0.mov")) == .unknown)
        print("PASS: bilingual locations follow asset IDs, all six cities, unknown/missing/corrupt catalog")

    }
}
