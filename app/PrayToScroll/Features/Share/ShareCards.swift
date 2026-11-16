import SwiftUI
import UIKit

/// Everything that can become a 1080×1920 share card (Instagram Stories friendly).
enum ShareCardKind: Identifiable, Equatable {
    case streak
    case verse(Verse)
    case prayedInstead
    case milestone(Int)
    case answered(request: String, person: String, note: String, days: Int?)

    var id: String {
        switch self {
        case .streak: return "streak"
        case .verse(let v): return "verse-\(v.ref)"
        case .prayedInstead: return "instead"
        case .milestone(let m): return "milestone-\(m)"
        case .answered(let r, _, _, _): return "answered-\(r)"
        }
    }

    var title: String {
        switch self {
        case .streak: return "Share your streak"
        case .verse: return "Share this verse"
        case .prayedInstead: return "Share your progress"
        case .milestone: return "Share your milestone"
        case .answered: return "Share an answered prayer"
        }
    }
}

/// Facts a card needs, captured from the model when the sheet opens.
struct ShareCardData {
    var streak: Int
    var longest: Int
    var prayedInstead: Int
    var name: String
}

/// The card itself, designed at 360×640 points and rendered at 3× (1080×1920).
struct ShareCardView: View {
    let kind: ShareCardKind
    let data: ShareCardData

    static let size = CGSize(width: 360, height: 640)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x15223A), Palette.midnight, Palette.midnightDeep], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Palette.gold.opacity(0.32), .clear], center: UnitPoint(x: 0.5, y: 0.28), startRadius: 0, endRadius: 300)
            // light rays
            ForEach(0..<14, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: [Palette.warmGold.opacity(0.14), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: 260)
                    .offset(y: -40)
                    .rotationEffect(.degrees(Double(i) * (360.0 / 14.0)), anchor: .bottom)
                    .offset(y: -150)
            }
            VStack(spacing: 0) {
                Spacer(minLength: 56)
                content
                Spacer(minLength: 24)
                footer
                    .padding(.bottom, 44)
            }
            .padding(.horizontal, 30)
        }
        .frame(width: ShareCardView.size.width, height: ShareCardView.size.height)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .streak:
            VStack(spacing: 18) {
                StreakFlame(streak: data.streak, lit: true, size: 150, showsNumber: false)
                Text("\(data.streak)")
                    .font(.system(size: 96, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.cream)
                Text(data.streak == 1 ? "day of praying\nbefore scrolling" : "days of praying\nbefore scrolling")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.warmGold)
                    .multilineTextAlignment(.center)
            }
        case .milestone(let m):
            VStack(spacing: 20) {
                BadgeView(milestone: m, earned: true, size: 150)
                Text(MilestoneEngine.title(for: m))
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.cream)
                    .multilineTextAlignment(.center)
                Text("\(m) days of praying first")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.warmGold)
            }
        case .verse(let verse):
            VStack(spacing: 22) {
                Text(verse.themeTitle.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Palette.warmGold)
                Text("“\(verse.text)”")
                    .font(.system(size: verse.text.count > 220 ? 21 : (verse.text.count > 140 ? 25 : 30), weight: .regular, design: .serif))
                    .foregroundStyle(Palette.cream)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .minimumScaleFactor(0.5)
                Text(verse.ref)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.warmGold)
                Text("World English Bible")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.cream.opacity(0.45))
            }
        case .prayedInstead:
            VStack(spacing: 16) {
                PrayToScrollMark(glow: true)
                    .frame(height: 120)
                Text("I prayed instead of scrolling")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.cream)
                    .multilineTextAlignment(.center)
                Text("\(data.prayedInstead)")
                    .font(.system(size: 110, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.goldGradient)
                Text(data.prayedInstead == 1 ? "time" : "times")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.warmGold)
            }
        case .answered(let request, let person, let note, let days):
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(Palette.sage.opacity(0.22)).frame(width: 110, height: 110)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(Palette.sage)
                }
                Text("God answered")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.cream)
                Text(request)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.cream.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                if !note.isEmpty {
                    Text(note)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.warmGold)
                        .multilineTextAlignment(.center)
                }
                Text([person.isEmpty ? nil : "For \(person)", days.map { "after \($0) days of prayer" }].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.cream.opacity(0.6))
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                PrayToScrollMark(glow: false)
                    .frame(height: 26)
                Text(AppConstants.appName)
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.cream)
            }
            Text(AppConstants.slogan)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.cream.opacity(0.6))
        }
    }
}

@MainActor
enum ShareCardRenderer {
    static func image(kind: ShareCardKind, data: ShareCardData) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(kind: kind, data: data))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// Preview + share for a card.
struct ShareCardSheet: View {
    let kind: ShareCardKind
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 20) {
                    ShareCardView(kind: kind, data: data)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                        .scaleEffect(0.82)
                        .frame(width: ShareCardView.size.width * 0.82, height: ShareCardView.size.height * 0.82)
                        .accessibilityLabel(kind.title)
                    PrimaryButton("Share", systemImage: "square.and.arrow.up") {
                        image = ShareCardRenderer.image(kind: kind, data: data)
                        if image != nil { showShare = true }
                    }
                    .padding(.horizontal, 32)
                    Text("Made for Stories: 1080 × 1920")
                        .font(.akCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.vertical, 12)
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                if let image {
                    ShareSheet(items: [image, "\(AppConstants.slogan) \(AppLinks.shareURL.absoluteString)"])
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }

    private var data: ShareCardData {
        ShareCardData(streak: model.streak.current, longest: model.streak.longest,
                      prayedInstead: model.gatesHonoured, name: model.settings.displayName)
    }
}

/// UIActivityViewController wrapper.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
