import AVFoundation
import SwiftUI
import UIKit

/// The 60 original full-bleed backdrops (Resources/Backgrounds/scroll-bg-NN.heic: made for this app, no people, text
/// or logos, about 150 KB each).
enum FeedBackgrounds {
    static let count = 60

    static func name(_ index: Int) -> String {
        String(format: "scroll-bg-%02d", (index % count + count) % count + 1)
    }

    static func url(_ index: Int, bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: name(index), withExtension: "heic")
    }
}

/// Decodes backdrops off the main thread and keeps the cards around the current one (±3) ready to draw, so a swipe
/// never waits on a decode.
final class BackdropCache: @unchecked Sendable {
    static let shared = BackdropCache()
    static let window = 3

    private let cache = NSCache<NSNumber, UIImage>()
    private let lock = NSLock()
    private var loading: Set<Int> = []

    init() {
        cache.countLimit = 2 * Self.window + 3
    }

    func cached(_ index: Int) -> UIImage? {
        cache.object(forKey: NSNumber(value: index))
    }

    /// The backdrop, decoded (from the cache when it's there).
    func image(_ index: Int) async -> UIImage? {
        if let hit = cached(index) { return hit }
        return await Task.detached(priority: .userInitiated) { [self] in self.decode(index) }.value
    }

    /// Starts decoding these (the ±3 around the current card) in the background.
    func preload(_ indices: [Int]) {
        for index in indices where cached(index) == nil {
            let start = lock.withLock { loading.insert(index).inserted }
            guard start else { continue }
            Task.detached(priority: .utility) { [self] in
                _ = self.decode(index)
                self.lock.withLock { _ = self.loading.remove(index) }
            }
        }
    }

    private func decode(_ index: Int) -> UIImage? {
        if let hit = cached(index) { return hit }
        guard let url = FeedBackgrounds.url(index), let raw = UIImage(contentsOfFile: url.path) else { return nil }
        let ready = raw.preparingForDisplay() ?? raw
        cache.setObject(ready, forKey: NSNumber(value: index))
        return ready
    }
}

/// A card's backdrop: the photo with a slow Ken Burns drift on the card you're looking at, and a scrim so white text
/// always reads. Falls back to the drawn sky while the photo decodes.
struct PhotoBackdrop: View {
    let index: Int
    let scene: FeedScene
    var isCurrent: Bool
    @State private var image: UIImage?
    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(index: Int, scene: FeedScene, isCurrent: Bool) {
        self.index = index
        self.scene = scene
        self.isCurrent = isCurrent
        _image = State(initialValue: BackdropCache.shared.cached(index))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(drift ? 1.12 : 1.02)
                        .offset(x: drift ? -geo.size.width * 0.03 : geo.size.width * 0.02,
                                y: drift ? -geo.size.height * 0.015 : 0)
                        .clipped()
                        .transition(.opacity)
                } else {
                    FeedBackdrop(scene: scene)
                }
                // Legibility scrim: darker behind the text and the buttons, lighter in the sky.
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.50), location: 0),
                    .init(color: .black.opacity(0.18), location: 0.22),
                    .init(color: .black.opacity(0.38), location: 0.5),
                    .init(color: .black.opacity(0.70), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .task(id: index) {
            if image == nil {
                let loaded = await BackdropCache.shared.image(index)
                withAnimation(.easeOut(duration: 0.25)) { image = loaded }
            }
        }
        .onAppear { updateDrift() }
        .onChange(of: isCurrent) { _, _ in updateDrift() }
    }

    private func updateDrift() {
        guard !reduceMotion else { drift = false; return }
        if isCurrent {
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) { drift = true }
        } else {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { drift = false }
        }
    }
}

/// Optional ambient sound under Scroll the Word: an original 32-second pad (Resources/scroll-ambient.m4a, made for
/// this app), looped without a gap. Off by default; mixes with other audio and follows the silent switch.
@MainActor
final class AmbientSound {
    static let shared = AmbientSound()

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var fadeTimer: Timer?
    private(set) var isPlaying = false

    func start() {
        guard !isPlaying else { return }
        guard let url = Bundle.main.url(forResource: "scroll-ambient", withExtension: "m4a"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        engine.mainMixerNode.outputVolume = 0
        do { try engine.start() } catch { return }
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
        self.engine = engine
        self.player = player
        isPlaying = true
        fade(to: 0.55, over: 1.5)
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        fade(to: 0, over: 0.6) { [weak self] in
            guard let self, !self.isPlaying else { return }
            self.player?.stop()
            self.engine?.stop()
            self.player = nil
            self.engine = nil
        }
    }

    private func fade(to target: Float, over seconds: Double, then done: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        guard let mixer = engine?.mainMixerNode else { done?(); return }
        let start = mixer.outputVolume
        let steps = max(1, Int(seconds * 30))
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: seconds / Double(steps), repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                step += 1
                mixer.outputVolume = start + (target - start) * Float(step) / Float(steps)
                if step >= steps {
                    timer.invalidate()
                    self?.fadeTimer = nil
                    done?()
                }
            }
        }
    }
}
