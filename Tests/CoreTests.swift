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
        let url = URL(fileURLWithPath: "/tmp/aerial-cinema-stability-test")
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
    }
}
