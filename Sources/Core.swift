import Foundation

/// Pure state: use a monotonic clock supplied by the caller.
struct EscapeHold {
    private(set) var beganAt: TimeInterval?
    let duration: TimeInterval = 5
    mutating func press(at now: TimeInterval, repeating: Bool = false) {
        guard !repeating, beganAt == nil else { return }
        beganAt = now
    }
    mutating func cancel() { beganAt = nil }
    func progress(at now: TimeInterval) -> Double {
        guard let start = beganAt else { return 0 }
        return min(1, max(0, (now - start) / duration))
    }
    func isComplete(at now: TimeInterval) -> Bool {
        guard let start = beganAt else { return false }
        return now - start >= duration
    }
}

struct ShuffleBag<Element: Hashable> {
    private(set) var available: Set<Element> = []
    private(set) var remaining: [Element] = []
    private(set) var seen: Set<Element> = []
    private(set) var last: Element?

    mutating func update(_ values: [Element]) {
        let next = Set(values)
        let new = next.subtracting(available).subtracting(seen)
        remaining.removeAll { !next.contains($0) }
        remaining.append(contentsOf: new.shuffled())
        available = next
    }
    mutating func putBack(_ value: Element, lastPlayed: Element?) {
        if available.contains(value), !remaining.contains(value) {
            remaining.insert(value, at: 0)
            seen.remove(value)
        }
        last = lastPlayed
    }
    mutating func take() -> Element? {
        guard !available.isEmpty else { return nil }
        if remaining.isEmpty {
            seen.removeAll()
            remaining = available.shuffled()
        }
        if remaining.count > 1, remaining.first == last {
            remaining.swapAt(0, Int.random(in: 1..<remaining.count))
        }
        let result = remaining.removeFirst()
        seen.insert(result)
        last = result
        return result
    }
}

struct FileStamp: Equatable {
    let bytes: Int64
    let modified: TimeInterval
    init?(url: URL) {
        guard let values = try? FileManager.default.attributesOfItem(atPath: url.path),
              values[.type] as? FileAttributeType == .typeRegular,
              let size = values[.size] as? NSNumber, size.int64Value > 0,
              let date = values[.modificationDate] as? Date else { return nil }
        bytes = size.int64Value
        modified = date.timeIntervalSince1970
    }
}

struct StableFileGate {
    private var previous: [URL: FileStamp] = [:]
    mutating func accept(_ current: [URL: FileStamp]) -> [URL: FileStamp] {
        let stable = current.filter { previous[$0.key] == $0.value }
        previous = current
        return stable
    }
}
