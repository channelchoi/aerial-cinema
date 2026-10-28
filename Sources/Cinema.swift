import AppKit
import AVFoundation
import QuartzCore
import CoreText
import IOKit.pwr_mgt

@MainActor func trace(_ message: String) {
    #if QA
    let path = ProcessInfo.processInfo.environment["AERIAL_QA_LOG"] ?? NSTemporaryDirectory() + "aerial-cinema-qa.log"
    if let data = String(format: "%.3f %@\n", ProcessInfo.processInfo.systemUptime, message).data(using: .utf8) {
        if !FileManager.default.fileExists(atPath: path) { FileManager.default.createFile(atPath: path, contents: nil) }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile(); handle.write(data); try? handle.close()
        }
    }
    #endif
}

@MainActor final class CinemaApplication: NSApplication {
    override func sendEvent(_ event: NSEvent) {
        if let controller = delegate as? CinemaController, controller.handle(event) { return }
        super.sendEvent(event)
    }
}

@MainActor final class CinemaWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { }
    override func performClose(_ sender: Any?) { }
}

@MainActor final class CinemaView: NSView {
    let video = AVPlayerLayer()
    private let track = CAShapeLayer()
    private let arc = CAShapeLayer()
    private let ring = CALayer()
    private let location = CALayer()
    private let chinese = CATextLayer()
    private let english = CATextLayer()
    private var isHolding = false
    private var hasPlace = false
    private(set) var place: PlaceName?
    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer!.backgroundColor = NSColor.black.cgColor
        video.videoGravity = .resizeAspectFill
        layer!.addSublayer(video)
        layer!.addSublayer(location)
        layer!.addSublayer(ring)
        location.addSublayer(chinese); location.addSublayer(english)
        ring.addSublayer(track); ring.addSublayer(arc)
        configure(chinese, size: 12)
        configure(english, size: 10)
        for shape in [track, arc] {
            shape.fillColor = nil; shape.lineWidth = 2; shape.lineCap = .round
        }
        track.strokeColor = NSColor.white.withAlphaComponent(0.23).cgColor
        arc.strokeColor = NSColor.white.withAlphaComponent(0.95).cgColor
        arc.strokeEnd = 0
        location.opacity = 0
        ring.opacity = 0
        location.zPosition = 100; ring.zPosition = 100
        needsLayout = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func configure(_ text: CATextLayer, size: CGFloat) {
        let font = NSFont.systemFont(ofSize: size)
        text.font = CTFontCreateWithName(font.fontName as CFString, size, nil)
        text.fontSize = size
        text.alignmentMode = .left
        text.isWrapped = false
        text.truncationMode = .end
        text.foregroundColor = NSColor.white.cgColor
        text.shadowColor = NSColor.black.cgColor
        text.shadowOpacity = 0.65
        text.shadowRadius = 1.5
        text.shadowOffset = CGSize(width: 0, height: -1)
    }
    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        video.frame = bounds
        ring.frame = bounds
        location.frame = bounds
        for shape in [track, arc] { shape.frame = bounds }
        let width = max(0, min(480, bounds.width - 48))
        english.frame = CGRect(x: 24, y: 24, width: width, height: 14)
        chinese.frame = CGRect(x: 24, y: 41, width: width, height: 17)
        let scale = window?.backingScaleFactor ?? 2
        chinese.contentsScale = scale; english.contentsScale = scale
        let path = CGMutablePath()
        path.addArc(center: CGPoint(x: 36, y: 36), radius: 12,
                    startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
        track.path = path; arc.path = path
        CATransaction.commit()
    }
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsLayout = true
    }
    func setPlace(_ place: PlaceName) {
        self.place = place
        CATransaction.begin(); CATransaction.setDisableActions(true)
        chinese.string = place.chinese
        english.string = place.english
        if !hasPlace {
            hasPlace = true
            location.opacity = isHolding ? 0 : 1
        }
        CATransaction.commit()
    }
    private func fade(_ target: CALayer, to opacity: Float, at time: CFTimeInterval) {
        let visible = target.presentation()?.opacity ?? target.opacity
        CATransaction.begin(); CATransaction.setDisableActions(true)
        target.opacity = opacity
        CATransaction.commit()
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = visible
        animation.toValue = opacity
        animation.duration = 0.25
        animation.beginTime = target.convertTime(time, from: nil)
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        target.add(animation, forKey: "hold-crossfade")
    }
    func showProgress(_ value: Double?, at time: CFTimeInterval = CACurrentMediaTime()) {
        let holding = value != nil
        if holding != isHolding {
            isHolding = holding
            fade(location, to: holding || !hasPlace ? 0 : 1, at: time)
            fade(ring, to: holding ? 1 : 0, at: time)
            trace("OVERLAY mode=\(holding ? "ring" : "location") zh=\(place?.chinese ?? "")")
        }
        if let progress = value {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            arc.strokeEnd = CGFloat(progress)
            CATransaction.commit()
        }
    }
}

@MainActor final class PlayerGroup {
    let entry: VideoEntry
    let players: [AVPlayer]
    private(set) var started = false
    init(entry: VideoEntry, count: Int) {
        self.entry = entry
        players = (0..<count).map { _ in
            let item = AVPlayerItem(url: entry.url)
            item.preferredForwardBufferDuration = 3
            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            player.actionAtItemEnd = .pause
            player.automaticallyWaitsToMinimizeStalling = false
            return player
        }
    }
    func prepare() async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 12
        while players.contains(where: { $0.currentItem?.status != .readyToPlay }) {
            try Task.checkCancellation()
            if let broken = players.first(where: { $0.currentItem?.status == .failed }) {
                throw broken.currentItem?.error ?? NSError(domain: "Cinema", code: 1)
            }
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw NSError(domain: "Cinema", code: 2) }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        // Queue prerolls together rather than serially to align decoder readiness.
        try await withThrowingTaskGroup(of: Bool.self) { tasks in
            for player in players { tasks.addTask { await player.preroll(atRate: 1) } }
            for try await ready in tasks { if !ready { throw NSError(domain: "Cinema", code: 3) } }
        }
        try Task.checkCancellation()
    }
    var time: CMTime { players.first?.currentTime() ?? .zero }
    func run(from time: CMTime) {
        let host = CMTimeAdd(CMClockGetTime(CMClockGetHostTimeClock()), CMTime(seconds: 0.2, preferredTimescale: 1_000_000_000))
        for player in players { player.setRate(1, time: time, atHostTime: host) }
        started = true
    }
    func pause() { for player in players { player.pause() } }
    func stop() {
        pause()
        for player in players { player.cancelPendingPrerolls(); player.replaceCurrentItem(with: nil) }
    }
}

@MainActor final class CinemaController: NSObject, NSApplicationDelegate {
    private var windows: [CinemaWindow] = []
    private var views: [CinemaView] = []
    private var hold = EscapeHold()
    private var tick: Timer?
    private var scanTimer: Timer?
    private var scanTask: Task<Void, Never>?
    private var transitionTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?
    private var nextGroup: PlayerGroup?
    private var current: PlayerGroup?
    private var entries: [URL: VideoEntry] = [:]
    private var bag = ShuffleBag<URL>()
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var assertion: IOPMAssertionID = 0
    private var assertionActive = false
    private var cursorHidden = false
    private var quitting = false
    private var sleeping = false
    private var suspended = false
    private var busy = false
    private var epoch = 0
    private var reserved: URL?
    private var libraryLoaded = false
    private var screenSignature: [String] = []
    private var transitionDeadline: Double = 0
    private var stallStart: Double?
    private var lastTime: Double = -1
    private var lastSync: Double = 0
    private var lastSyncTrace: Double = 0
    private var sleepTime: CMTime = .zero
    private var originalPresentation: NSApplication.PresentationOptions = []
    private var activePresentation = false
    private var qaStarted: Double = 0
    private var qaVisibleLogged = false
    private var qaPlayCount = 0
    private let library: VideoLibrary

    override init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var directories = [home.appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials/videos"),
            URL(fileURLWithPath: "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS")]
        #if QA
        if let path = ProcessInfo.processInfo.environment["AERIAL_QA_DIR"] { directories = [URL(fileURLWithPath: path)] }
        #endif
        library = VideoLibrary(directories: directories)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Guard direct executable launches as well as normal Launch Services opens.
        let siblings = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.channel.aerialcinema")
        if let existing = siblings.first(where: { !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            trace("EXISTING pid=\(existing.processIdentifier)")
            existing.activate(options: [.activateAllWindows])
            quitting = true; NSApp.terminate(nil); return
        }
        NSApp.mainMenu = nil
        NSApp.setActivationPolicy(.regular)
        originalPresentation = NSApp.presentationOptions
        observeLifecycle()
        createWindows()
        guard !windows.isEmpty else { fail("没有找到可播放的显示器。"); return }
        NSApp.activate(ignoringOtherApps: true)
        enterPresentation()
        preventSleep()
        tick = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        RunLoop.main.add(tick!, forMode: .common)
        qaStarted = ProcessInfo.processInfo.systemUptime
        trace("LAUNCH screens=\(windows.count)")
        scanTask = Task { [weak self] in
            guard let self else { return }
            _ = await self.library.scan()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled, !self.quitting else { return }
            let found = await self.library.scan()
            guard !Task.isCancelled, !self.quitting else { return }
            self.libraryLoaded = true
            self.apply(found)
            self.scanTask = nil
            guard !found.isEmpty else {
                self.fail("没有找到可播放的已下载航拍视频。请先在系统设置的墙纸中完成航拍视频下载，再打开航拍影院。")
                return
            }
            self.advance()
        }
        scanTimer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.scan() }
        }
        RunLoop.main.add(scanTimer!, forMode: .common)
    }

    private func observeLifecycle() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        })
        observers.append(center.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, !self.sleeping, let item = note.object as? AVPlayerItem,
                      item === self.current?.players.first?.currentItem else { return }
                self.advance()
            }
        })
        observers.append(center.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, let item = note.object as? AVPlayerItem,
                      self.current?.players.contains(where: { $0.currentItem === item }) == true else { return }
                self.rejectCurrent()
            }
        })
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sleep() }
        })
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.wake() }
        })
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sleep() }
        })
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.wake() }
        })
    }

    private func displaySignature() -> [String] {
        NSScreen.screens.map {
            "\($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] ?? 0)-\($0.frame)-\($0.backingScaleFactor)"
        }
    }
    private func createWindows() {
        screenSignature = displaySignature()
        for window in windows { window.orderOut(nil); window.close() }
        windows.removeAll(); views.removeAll()
        for screen in NSScreen.screens {
            let window = CinemaWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
            window.setFrame(screen.frame, display: false)
            window.backgroundColor = .black
            window.isOpaque = true; window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            window.level = .normal
            window.animationBehavior = .none
            window.isMovable = false
            window.title = "航拍影院"
            let view = CinemaView(frame: NSRect(origin: .zero, size: screen.frame.size))
            window.contentView = view
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
            window.makeFirstResponder(view)
            window.orderFront(nil)
            windows.append(window); views.append(view)
        }
        windows.first?.makeKeyAndOrderFront(nil)
    }

    private func enterPresentation() {
        guard !quitting, NSApp.isActive else { return }
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableHideApplication]
        activePresentation = true
        if !cursorHidden { NSCursor.hide(); cursorHidden = true }
    }
    private func leavePresentation() {
        if activePresentation { NSApp.presentationOptions = originalPresentation; activePresentation = false }
        if cursorHidden { NSCursor.unhide(); cursorHidden = false }
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        guard !quitting else { return }
        windows.forEach { $0.orderFront(nil) }
        windows.first?.makeKeyAndOrderFront(nil)
        enterPresentation()
    }
    func applicationDidResignActive(_ notification: Notification) {
        cancelHold(); leavePresentation(); trace("DEACTIVATE")
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if quitting { return .terminateNow }
        cancelHold(); trace("BLOCK_TERMINATE"); return .terminateCancel
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windows.forEach { $0.orderFront(nil) }; enterPresentation(); trace("REOPEN"); return true
    }

    func handle(_ event: NSEvent) -> Bool {
        guard !quitting, !windows.isEmpty else { return false }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift, .function])
        if event.type == .flagsChanged {
            if !modifiers.isEmpty { cancelHold() }
            return false
        }
        if event.type == .keyDown {
            if event.keyCode == 53, modifiers.isEmpty, NSApp.isActive, !sleeping {
                hold.press(at: ProcessInfo.processInfo.systemUptime, repeating: event.isARepeat)
                if !event.isARepeat { trace("HOLD_BEGIN") }
            } else { cancelHold() }
            // App switching and forced quit are handled by macOS before app key events.
            return true
        }
        if event.type == .keyUp {
            if event.keyCode == 53 { cancelHold() }
            return true
        }
        return false
    }
    private func cancelHold() {
        if hold.beganAt != nil { trace("HOLD_CANCEL") }
        hold.cancel()
        let time = CACurrentMediaTime()
        views.forEach { $0.showProgress(nil, at: time) }
    }

    private func update() {
        guard !quitting else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if hold.beganAt != nil {
            guard NSApp.isActive, !sleeping else { cancelHold(); return }
            let progress = hold.progress(at: now)
            let time = CACurrentMediaTime()
            views.forEach { $0.showProgress(progress, at: time) }
            if hold.isComplete(at: now) { trace("HOLD_COMPLETE"); finish(); return }
        }
        guard !sleeping, !suspended else { return }
        if busy {
            if now > transitionDeadline { fail("视频准备超时。请稍后重新打开航拍影院。"); return }
            return
        }
        guard let current else { return }
        if current.players.contains(where: { $0.currentItem?.status == .failed }) { rejectCurrent(); return }
        let seconds = current.time.seconds
        let end = current.entry.duration
        if seconds.isFinite, seconds >= end - 0.04 { advance(); return }
        if seconds.isFinite, abs(seconds - lastTime) > 0.005 { stallStart = nil; lastTime = seconds }
        else if stallStart == nil { stallStart = now }
        else if now - stallStart! > 12 { trace("STALL"); rejectCurrent(); return }
        if now - lastSync > 1, seconds.isFinite {
            lastSync = now
            let drift = current.players.dropFirst().map { abs($0.currentTime().seconds - seconds) }.max() ?? 0
            if drift > 0.06 { current.run(from: current.time); trace("RESYNC drift=\(drift)") }
            if now - lastSyncTrace > 5 { trace("SYNC drift=\(drift)"); lastSyncTrace = now }
        }
        #if QA
        if !qaVisibleLogged, views.allSatisfy({ $0.video.isReadyForDisplay }) {
            qaVisibleLogged = true; trace("VISIBLE layers=\(views.count) bounds=\(views.map { $0.bounds }) frames=\(views.map { $0.video.frame })")
        }
        if let limit = Double(ProcessInfo.processInfo.environment["AERIAL_QA_CLIP_SECONDS"] ?? "5"), seconds > limit { advance() }
        if let limit = Double(ProcessInfo.processInfo.environment["AERIAL_QA_TIMEOUT"] ?? "180"), now - qaStarted > limit {
            trace("QA_TIMEOUT"); finish()
        }
        #endif
    }

    private func scan() {
        guard scanTask == nil, !quitting else { return }
        scanTask = Task { [weak self] in
            guard let self else { return }
            let found = await self.library.scan()
            guard !Task.isCancelled, !self.quitting else { return }
            self.apply(found); self.scanTask = nil
        }
    }
    private func apply(_ found: [VideoEntry]) {
        entries = Dictionary(uniqueKeysWithValues: found.map { ($0.url, $0) })
        bag.update(found.map(\.url))
        if let url = current?.entry.url, let entry = entries[url] {
            views.forEach { $0.setPlace(entry.place) }
        }
        if let next = nextGroup, entries[next.entry.url] != next.entry {
            let wasBusy = busy
            cancelPipeline()
            if wasBusy { advance() } else { preload() }
        }
        trace("LIBRARY count=\(found.count)")
    }
    private func remove(_ entry: VideoEntry) {
        entries.removeValue(forKey: entry.url)
        bag.update(Array(entries.keys))
        Task { await library.reject(entry) }
        trace("REJECT \(entry.url.lastPathComponent)")
    }
    private func rejectCurrent() {
        guard let entry = current?.entry, !busy else { return }
        remove(entry); advance()
    }

    private func advance() {
        guard !busy, !quitting, !sleeping, !suspended else { return }
        busy = true; transitionDeadline = ProcessInfo.processInfo.systemUptime + 25
        stallStart = nil; lastTime = -1
        let generation = epoch
        transitionTask = Task { [weak self] in
            guard let self else { return }
            // A preload may already be preparing the next item. Await it once.
            if let task = self.preloadTask { await task.value }
            guard !Task.isCancelled, !self.quitting, generation == self.epoch else { return }
            var ready: PlayerGroup?
            if let next = self.nextGroup, self.entries[next.entry.url] == next.entry, next.players.count == self.views.count {
                ready = next; self.nextGroup = nil
            } else { self.nextGroup?.stop(); self.nextGroup = nil }
            while ready == nil, !self.entries.isEmpty {
                guard !Task.isCancelled, !self.quitting, generation == self.epoch else { return }
                guard let url = self.bag.take(), let entry = self.entries[url] else { break }
                self.reserved = url
                let group = PlayerGroup(entry: entry, count: self.views.count)
                do { try await group.prepare(); ready = group }
                catch {
                    group.stop()
                    if Task.isCancelled || generation != self.epoch { return }
                    self.reserved = nil; self.remove(entry)
                }
            }
            guard !Task.isCancelled, !self.quitting, generation == self.epoch else { ready?.stop(); return }
            guard let ready else { self.fail("当前航拍视频均无法播放。请在系统设置中检查视频下载是否完成。"); return }
            self.install(ready, from: .zero)
            self.busy = false; self.transitionTask = nil
            self.preload()
        }
    }
    private func install(_ group: PlayerGroup, from time: CMTime) {
        let old = current
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for (view, player) in zip(views, group.players) { view.video.player = player }
        CATransaction.commit()
        current = group
        views.forEach { $0.setPlace(group.entry.place) }
        trace("LOCATION zh=\(group.entry.place.chinese) en=\(group.entry.place.english)")
        reserved = nil
        group.run(from: time)
        old?.stop()
        stallStart = nil; lastTime = -1; qaVisibleLogged = false; qaPlayCount += 1
        trace("PLAY \(group.entry.url.lastPathComponent) ordinal=\(qaPlayCount) screens=\(views.count)")
    }
    private func preload() {
        guard preloadTask == nil, nextGroup == nil, !quitting, !sleeping, !suspended else { return }
        let generation = epoch
        preloadTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, !self.quitting, generation == self.epoch, !self.entries.isEmpty {
                guard let url = self.bag.take(), let entry = self.entries[url] else { break }
                self.reserved = url
                let group = PlayerGroup(entry: entry, count: self.views.count)
                do {
                    try await group.prepare()
                    guard !Task.isCancelled, !self.quitting, generation == self.epoch else { group.stop(); break }
                    guard self.entries[url] == entry else { group.stop(); self.reserved = nil; continue }
                    self.nextGroup = group; trace("PRELOAD \(url.lastPathComponent)"); break
                } catch {
                    group.stop()
                    if Task.isCancelled || generation != self.epoch { break }
                    self.reserved = nil; self.remove(entry)
                }
            }
            if generation == self.epoch { self.preloadTask = nil }
        }
    }

    private func cancelPipeline() {
        epoch += 1
        transitionTask?.cancel(); transitionTask = nil
        preloadTask?.cancel(); preloadTask = nil
        if let url = reserved { bag.putBack(url, lastPlayed: current?.entry.url) }
        reserved = nil
        nextGroup?.stop(); nextGroup = nil
        busy = false
    }

    private func screensChanged() {
        guard !quitting else { return }
        cancelHold()
        if sleeping || displaySignature() == screenSignature { return }
        rebuild()
    }
    private func rebuild() {
        cancelPipeline()
        let entry = current?.entry
        let time = sleeping ? sleepTime : (current?.time ?? .zero)
        current?.pause()
        createWindows()
        guard !windows.isEmpty else { suspended = true; releaseSleep(); return }
        suspended = false; preventSleep(); enterPresentation()
        guard let entry else { busy = false; if libraryLoaded { advance() }; return }
        busy = true; transitionDeadline = ProcessInfo.processInfo.systemUptime + 25
        let generation = epoch
        transitionTask = Task { [weak self] in
            guard let self else { return }
            let group = PlayerGroup(entry: entry, count: self.views.count)
            do {
                try await group.prepare()
                guard !Task.isCancelled, !self.quitting, generation == self.epoch else { group.stop(); return }
                self.install(group, from: time)
                self.busy = false; self.transitionTask = nil; self.preload()
                trace("SCREENS_REBUILT count=\(self.views.count)")
            } catch {
                group.stop()
                guard !Task.isCancelled, !self.quitting, generation == self.epoch else { return }
                self.busy = false; self.remove(entry); self.advance()
            }
        }
    }
    private func sleep() {
        guard !sleeping, !quitting else { return }
        sleeping = true; sleepTime = current?.time ?? .zero
        cancelHold(); current?.pause()
        cancelPipeline()
        releaseSleep(); trace("SLEEP")
    }
    private func wake() {
        guard sleeping, !quitting else { return }
        sleeping = false; scan(); rebuild(); trace("WAKE")
    }
    private func preventSleep() {
        guard !assertionActive else { return }
        assertionActive = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), "航拍影院正在播放" as CFString, &assertion) == kIOReturnSuccess
    }
    private func releaseSleep() {
        if assertionActive { IOPMAssertionRelease(assertion); assertionActive = false }
    }
    private func cleanup() {
        cancelHold(); tick?.invalidate(); scanTimer?.invalidate()
        scanTask?.cancel(); cancelPipeline()
        current?.stop()
        releaseSleep(); leavePresentation()
        for window in windows { window.orderOut(nil); window.close() }
        windows.removeAll(); views.removeAll()
        for token in observers { NotificationCenter.default.removeObserver(token) }
        for token in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        observers.removeAll(); workspaceObservers.removeAll()
    }
    private func finish() {
        guard !quitting else { return }
        quitting = true; trace("EXIT"); cleanup(); NSApp.terminate(nil)
    }
    private func fail(_ message: String) {
        guard !quitting else { return }
        quitting = true; trace("ERROR \(message)"); cleanup()
        let alert = NSAlert(); alert.messageText = "航拍影院暂时无法播放"
        alert.informativeText = message; alert.alertStyle = .warning; alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true); alert.runModal(); NSApp.terminate(nil)
    }
    func applicationWillTerminate(_ notification: Notification) { cleanup() }
}

@main struct CinemaMain {
    @MainActor static func main() {
        trace("MAIN")
        let application = CinemaApplication.shared
        let controller = CinemaController()
        application.delegate = controller
        application.run()
        withExtendedLifetime(controller) { }
    }
}
