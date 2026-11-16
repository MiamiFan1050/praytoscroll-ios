import AVFoundation
import Observation

/// Reads verses aloud with the iPhone's own voices (the best English voice installed: Premium, then Enhanced).
/// Off unless the person taps Listen or turns on "Read each verse aloud". Nothing leaves the device.
@MainActor
@Observable
final class VerseReader: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = VerseReader()

    /// The verse being read (its day), for the Listen button's state.
    private(set) var speakingDay: Int?
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// The best installed English voice, preferring the phone's own English region.
    static var bestVoice: AVSpeechSynthesisVoice? {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        let preferred = Locale.preferredLanguages.first { $0.hasPrefix("en") } ?? "en-US"
        return english.max { a, b in
            if a.quality != b.quality { return a.quality.rawValue < b.quality.rawValue }
            return (a.language == preferred ? 1 : 0) < (b.language == preferred ? 1 : 0)
        } ?? AVSpeechSynthesisVoice(language: preferred)
    }

    /// True when only the basic (compact) voices are installed: the UI suggests downloading an Enhanced one.
    static var onlyCompactVoices: Bool { (bestVoice?.quality ?? .default) == .default }

    func read(_ verse: Verse) {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: "\(verse.displayText) \(Self.spokenRef(verse.ref))")
        utterance.voice = Self.bestVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.postUtteranceDelay = 0.2
        speakingDay = verse.day
        synthesizer.speak(utterance)
    }

    func toggle(_ verse: Verse) {
        if speakingDay == verse.day { stop() } else { read(verse) }
    }

    func stop() {
        guard synthesizer.isSpeaking || speakingDay != nil else { return }
        synthesizer.stopSpeaking(at: .immediate)
        finished()
    }

    /// "John 3:16-17" → "John 3, verses 16 to 17" so the voice doesn't read a time or a fraction.
    nonisolated static func spokenRef(_ ref: String) -> String {
        guard let colon = ref.lastIndex(of: ":") else { return ref }
        let head = ref[..<colon]
        let tail = ref[ref.index(after: colon)...]
        if tail.contains("-") {
            let parts = tail.split(separator: "-")
            return "\(head), verses \(parts.first ?? "") to \(parts.last ?? "")"
        }
        return "\(head), verse \(tail)"
    }

    private func finished() {
        speakingDay = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in if !self.synthesizer.isSpeaking { self.speakingDay = nil } }
    }
}
