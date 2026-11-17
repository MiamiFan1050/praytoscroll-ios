import AVFoundation
import StoreKit
import SwiftUI

// MARK: Home card

/// Today → Bible Stories: "Continue" plus a shelf of series. Hidden until a catalog has loaded (bundled or fetched).
struct StoriesCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let library = model.stories
        Group {
            if !library.series.isEmpty, showsInThisRun {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Bible Stories", systemImage: "play.rectangle.on.rectangle.fill")
                            .font(.akOverline)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.goldText)
                        Spacer()
                        Chip(text: "New episodes weekly", tint: Theme.sageText)
                    }
                    if let target = library.continueTarget {
                        NavigationLink {
                            StoryPlayerView(series: target.series, startID: target.episode.id)
                        } label: {
                            continueRow(series: target.series, episode: target.episode)
                        }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityIdentifier("stories.continue")
                    } else {
                        Text("The Bible, told by the people who were there. One short prayer opens each new part.")
                            .font(.akCallout)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(library.series) { series in
                                NavigationLink {
                                    StoryPlayerView(series: series, startID: startEpisode(in: series).id)
                                } label: {
                                    seriesTile(series)
                                }
                                .buttonStyle(PressScaleStyle())
                                .accessibilityIdentifier("stories.series.\(series.id)")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }
                .akCard()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("stories.card")
            }
        }
        .task { await library.refresh() }
    }

    /// UI-test runs (crawl, App Store screenshots) keep today's Home unless a test passes -stories.
    private var showsInThisRun: Bool {
        !model.options.isUITest || ProcessInfo.processInfo.arguments.contains("-stories")
    }

    /// The first episode not yet watched (the start of the series once it's all watched).
    private func startEpisode(in series: StorySeries) -> StoryEpisode {
        series.episodes.first { !model.stories.watched.contains($0.id) } ?? series.episodes[0]
    }

    private func continueRow(series: StorySeries, episode: StoryEpisode) -> some View {
        HStack(spacing: 12) {
            StoryPoster(path: episode.poster)
                .frame(width: 54, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("Continue · \(series.title)").akOverline()
                Text("\(episode.label): \(episode.title)")
                    .font(.akHeadline)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(model.stories.isUnlocked(episode) ? "Ready to watch" : "Opens with one short prayer")
                    .font(.akFootnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: model.stories.isUnlocked(episode) ? "play.circle.fill" : "lock.circle.fill")
                .font(.title)
                .foregroundStyle(Theme.goldIcon)
        }
        .contentShape(Rectangle())
    }

    private func seriesTile(_ series: StorySeries) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                StoryPoster(path: series.poster)
                    .frame(width: 112, height: 199)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                let seen = model.stories.watchedCount(in: series)
                if seen > 0 {
                    Text("\(seen)/\(series.episodes.count)")
                        .font(.akCaption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.black.opacity(0.55)))
                        .padding(8)
                }
            }
            Text(series.title)
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text("\(series.episodes.count) episodes")
                .font(.akCaption)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(width: 112, alignment: .leading)
    }
}

/// A remote poster with a quiet placeholder.
struct StoryPoster: View {
    @Environment(AppModel.self) private var model
    let path: String
    var fill = true

    var body: some View {
        AsyncImage(url: model.stories.url(path)) { phase in
            if let image = phase.image {
                if fill { image.resizable().scaledToFill() } else { image.resizable().scaledToFit() }
            } else {
                ZStack {
                    Palette.midnight
                    Image(systemName: "play.rectangle.fill").font(.title2).foregroundStyle(.white.opacity(0.35))
                }
            }
        }
    }
}

// MARK: Player

/// Full-screen, vertical, swipe for the next part. Locked parts show "Pray to watch"; the Amen opens them for good.
struct StoryPlayerView: View {
    let series: StorySeries
    let startID: String

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var currentID: String?
    @State private var player = AVPlayer()
    @State private var loadedID: String?
    @State private var endedID: String?
    @State private var paused = false
    @State private var showCredits = false
    @State private var advance: Task<Void, Never>?
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(series.episodes) { episode in
                    StoryPage(series: series, episode: episode, player: player,
                              isCurrent: currentID == episode.id, isLoaded: loadedID == episode.id,
                              ended: endedID == episode.id, paused: paused,
                              onTap: togglePause, onReplay: replay, onNext: { goNext(from: episode) })
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(episode.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        .background(Color.black)
        .ignoresSafeArea()
        .overlay(alignment: .top) { topBar }
        .overlay {
            if showCredits { credits }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden()
        .onAppear {
            if currentID == nil { currentID = startID }
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
            load(currentID)
        }
        .onDisappear {
            advance?.cancel()
            player.pause()
            // Let music the viewer had playing come back.
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        .onChange(of: currentID) { _, id in load(id) }
        .onChange(of: model.stories.unlocked) { _, _ in load(currentID) }
        // The Amen screen sits on top of the player: start the newly opened part only once it closes.
        .onChange(of: model.activeSession == nil) { _, closed in
            if closed { load(currentID) } else { player.pause() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { note in
            guard let item = note.object as? AVPlayerItem, item === player.currentItem else { return }
            finished()
        }
    }

    private var currentEpisode: StoryEpisode? { series.episodes.first { $0.id == currentID } }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.black.opacity(0.35)))
            }
            .accessibilityLabel("Close")
            .accessibilityIdentifier("stories.close")
            VStack(alignment: .leading, spacing: 1) {
                Text(series.title).font(.akSubheadlineSemibold).foregroundStyle(.white)
                if let episode = currentEpisode, let index = series.episodes.firstIndex(of: episode) {
                    Text("\(index + 1) of \(series.episodes.count)").font(.akCaption).foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer()
            Button { withAnimation { showCredits.toggle() } } label: {
                Image(systemName: "info.circle")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Credits")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var credits: some View {
        VStack(spacing: 12) {
            Text("Credits").font(.akHeadline).foregroundStyle(.white)
            Text(model.stories.notice)
                .font(.akFootnote)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Text("Told from the perspective of people in each story. Every line is checked against Scripture; read the full passage to go deeper.")
                .font(.akFootnote)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Close") { withAnimation { showCredits = false } }
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Palette.warmGold)
                .frame(minHeight: 44)
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.black.opacity(0.85)))
        .padding(28)
    }

    private func load(_ id: String?) {
        advance?.cancel()
        endedID = nil
        paused = false
        guard let id, let episode = series.episodes.first(where: { $0.id == id }) else { return }
        guard model.stories.isUnlocked(episode), let url = model.stories.url(episode.video) else {
            player.pause()
            player.replaceCurrentItem(with: nil)
            loadedID = nil
            model.stories.scheduleCliffhanger(for: episode, in: series)
            return
        }
        if loadedID != id {
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            loadedID = id
        }
        if model.activeSession == nil {
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
        }
    }

    private func togglePause() {
        guard loadedID != nil, endedID == nil else { return }
        paused.toggle()
        paused ? player.pause() : player.play()
    }

    private func replay() {
        advance?.cancel()
        endedID = nil
        paused = false
        player.seek(to: .zero)
        player.play()
    }

    private func finished() {
        guard let episode = currentEpisode else { return }
        model.stories.markWatched(episode)
        endedID = episode.id
        Haptics.selection()
        // DramaWave's rule: the next unlocked part starts by itself; a locked one waits for the prayer.
        if let next = model.stories.next(after: episode, in: series) {
            guard model.stories.isUnlocked(next) else { return }
            advance = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                guard !Task.isCancelled, endedID == episode.id else { return }
                withAnimation { currentID = next.id }
            }
        } else if ReviewPrompt.shouldAsk(model: model, source: .manual, isSample: false) {
            // A whole series watched: the happiest moment in the app to ask for a rating.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                ReviewPrompt.markAsked(model: model)
                requestReview()
            }
        }
    }

    private func goNext(from episode: StoryEpisode) {
        guard let next = model.stories.next(after: episode, in: series) else {
            dismiss()
            return
        }
        withAnimation { currentID = next.id }
    }
}

/// One episode: video (when current and open), poster otherwise, the lock, and the end card.
private struct StoryPage: View {
    let series: StorySeries
    let episode: StoryEpisode
    let player: AVPlayer
    let isCurrent: Bool
    let isLoaded: Bool
    let ended: Bool
    let paused: Bool
    let onTap: () -> Void
    let onReplay: () -> Void
    let onNext: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        let unlocked = model.stories.isUnlocked(episode)
        ZStack {
            Color.black
            StoryPoster(path: episode.poster, fill: false)
                .blur(radius: unlocked ? 0 : 18)
                .opacity(unlocked ? 1 : 0.55)
            if unlocked, isCurrent, isLoaded {
                PlayerLayerView(player: player)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
                    .accessibilityLabel(paused ? "Play" : "Pause")
                    .accessibilityAddTraits(.isButton)
            }
            if paused, isCurrent, !ended {
                Image(systemName: "play.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.white.opacity(0.85))
                    .allowsHitTesting(false)
            }
            if !unlocked {
                lockPanel
            } else if ended, isCurrent {
                endCard
            }
            VStack {
                Spacer()
                if unlocked && !ended { caption }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stories.page.\(episode.id)")
    }

    private var caption: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(episode.label) · \(episode.title)")
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(.white)
                Text(episode.scripture)
                    .font(.system(.footnote, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.warmGold)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 40)
        .padding(.bottom, 34)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
    }

    private var lockPanel: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Palette.warmGold)
            Text(episode.label.uppercased())
                .font(.akOverline)
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.75))
            Text(episode.title)
                .font(.akTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("“\(episode.hook)”")
                .font(.akVerse)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton("Pray to watch", systemImage: "hands.and.sparkles.fill") {
                model.prayToWatch(episode, in: series)
            }
            .accessibilityIdentifier("stories.pray.\(episode.id)")
            Text("One short prayer opens it for good.")
                .font(.akFootnote)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 30)
    }

    private var endCard: some View {
        let next = model.stories.next(after: episode, in: series)
        return VStack(spacing: 16) {
            Text(episode.scripture)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.warmGold)
            Text(episode.question)
                .font(.akTitle2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let next {
                if model.stories.isUnlocked(next) {
                    PrimaryButton("Next: \(next.label)", systemImage: "play.fill", action: onNext)
                } else {
                    PrimaryButton("Pray to watch \(next.label)", systemImage: "hands.and.sparkles.fill") {
                        model.prayToWatch(next, in: series)
                    }
                    .accessibilityIdentifier("stories.prayNext")
                }
            } else {
                Text("You finished \(series.title).")
                    .font(.akCallout)
                    .foregroundStyle(.white.opacity(0.85))
                PrimaryButton("More stories", systemImage: "square.grid.2x2.fill", action: onNext)
            }
            Button(action: onReplay) {
                Label("Watch again", systemImage: "arrow.counterclockwise")
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(minHeight: 44)
            }
        }
        .padding(26)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.black.opacity(0.72)))
        .padding(.horizontal, 22)
        .transition(.opacity)
    }
}

/// AVPlayerLayer in SwiftUI, letterboxed so the films' on-screen text is never cropped.
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
    }

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
