import Foundation
import AVFoundation

@main struct LibraryTests {
    static func main() async throws {
        let actual = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials/videos")
        let library = VideoLibrary(directories: [actual])
        let check1 = await library.scan()
        assert(check1.isEmpty)
        let real = await library.scan()
        assert(!real.isEmpty, "Download at least one aerial video before running media tests")
        print("PASS: existing library \(real.count) playable movies")
        for entry in real { print(entry.url.lastPathComponent, String(format: "%.2fs", entry.duration)) }
        let testDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Tests")
        let root = testDirectory.appendingPathComponent("library-fixtures-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fixture = testDirectory.appendingPathComponent("clips/clip-1.mp4")
        let movie = root.appendingPathComponent("one.mp4")
        let bad = root.appendingPathComponent("broken.mov")
        if FileManager.default.fileExists(atPath: movie.path) { try FileManager.default.removeItem(at: movie) }
        try FileManager.default.copyItem(at: fixture, to: movie)
        try Data("this is not a movie".utf8).write(to: bad)
        let watched = VideoLibrary(directories: [root])
        let check2 = await watched.scan()
        assert(check2.isEmpty)
        let first = await watched.scan()
        assert(first.count == 1 && first.first?.url.lastPathComponent == "one.mp4")
        print("PASS: bad file rejected; stable valid file accepted")
        let second = root.appendingPathComponent("two.mp4")
        if FileManager.default.fileExists(atPath: second.path) { try FileManager.default.removeItem(at: second) }
        try FileManager.default.copyItem(at: fixture, to: second)
        let check3 = await watched.scan()
        assert(check3.count == 1)
        let check4 = await watched.scan()
        assert(check4.count == 2)
        print("PASS: new file requires two stable observations")
        try FileManager.default.removeItem(at: movie)
        let check5 = await watched.scan()
        assert(check5.count == 1)
        let remaining = await watched.scan()
        await watched.reject(remaining[0])
        let check6 = await watched.scan()
        assert(check6.isEmpty)
        print("PASS: deletions removed; runtime failure quarantined until file changes")
        try FileManager.default.removeItem(at: second)
        try FileManager.default.removeItem(at: bad)
        try FileManager.default.removeItem(at: root)
    }
}
