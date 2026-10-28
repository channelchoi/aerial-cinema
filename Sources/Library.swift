import Foundation
import AVFoundation

struct VideoEntry: Equatable {
    let url: URL
    let stamp: FileStamp
    let duration: Double
    let place: PlaceName
}

actor VideoLibrary {
    let directories: [URL]
    private let manifestURLs: [URL]
    private var gate = StableFileGate()
    private var checked: [URL: FileStamp] = [:]
    private var valid: [URL: VideoEntry] = [:]
    private var failed: [URL: FileStamp] = [:]
    init(directories: [URL], manifestURLs: [URL]? = nil) {
        self.directories = directories
        self.manifestURLs = manifestURLs ?? LocationCatalog.manifestURLs(for: directories)
    }

    func snapshot() -> [URL: FileStamp] {
        var found: [URL: FileStamp] = [:]
        for directory in directories {
            guard let files = try? FileManager.default.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else { continue }
            for url in files where ["mov", "mp4", "m4v"].contains(url.pathExtension.lowercased()) {
                if let stamp = FileStamp(url: url) { found[url] = stamp }
            }
        }
        return found
    }

    func reject(_ entry: VideoEntry) {
        failed[entry.url] = entry.stamp
        valid.removeValue(forKey: entry.url)
    }

    func scan() async -> [VideoEntry] {
        let catalog = LocationCatalog(manifestURLs: manifestURLs)
        let files = snapshot()
        let stable = gate.accept(files)
        valid = valid.filter { files[$0.key] == $0.value.stamp && failed[$0.key] != $0.value.stamp }
        for (url, stamp) in stable where checked[url] != stamp && failed[url] != stamp {
            checked[url] = stamp
            let asset = AVURLAsset(url: url)
            do {
                let playable = try await asset.load(.isPlayable)
                let duration = try await asset.load(.duration).seconds
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard playable, duration.isFinite, duration > 0, !tracks.isEmpty,
                      FileStamp(url: url) == stamp else { continue }
                valid[url] = VideoEntry(url: url, stamp: stamp, duration: duration, place: catalog.place(forVideo: url))
            } catch { /* Incomplete and unsupported files never enter the queue. */ }
        }
        // A refreshed catalog can identify an existing movie without re-decoding it.
        valid = valid.mapValues {
            VideoEntry(url: $0.url, stamp: $0.stamp, duration: $0.duration, place: catalog.place(forVideo: $0.url))
        }
        return valid.values.sorted { $0.url.path < $1.url.path }
    }
}
