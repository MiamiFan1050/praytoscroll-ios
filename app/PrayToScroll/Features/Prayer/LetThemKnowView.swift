import MessageUI
import SwiftUI

/// "Let Sarah know?" The text that turns a private prayer into a moment of grace (and PrayToScroll's best growth loop).
struct LetThemKnowView: View {
    @Bindable var flow: PrayerFlow
    @State private var message: String = ""
    @State private var showComposer = false
    @State private var showShare = false
    @FocusState private var editing: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 24)
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Palette.rose.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 110))
                        .frame(width: 220, height: 220)
                    Circle()
                        .fill(LinearGradient(colors: [Palette.rose, Color(hex: 0xC97F79)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 104, height: 104)
                        .shadow(color: Palette.rose.opacity(0.6), radius: 24)
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(-12))
                        .offset(x: -2, y: 2)
                }
                .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("Let \(flow.personFirstName) know?")
                        .font(.akLargeTitle)
                        .foregroundStyle(Palette.cream)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("letknow.title")
                    Text("You just prayed for them. A short text can carry a lot of grace.")
                        .font(.akCallout)
                        .foregroundStyle(Palette.cream.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)

                // iMessage-style bubble, editable.
                VStack(alignment: .trailing, spacing: 6) {
                    TextField("", text: $message, axis: .vertical)
                        .font(.system(.body, design: .default))
                        .foregroundStyle(.white)
                        .lineLimit(2...6)
                        .focused($editing)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            BubbleShape()
                                .fill(LinearGradient(colors: [Color(hex: 0x3A8DFF), Color(hex: 0x1F6FEB)], startPoint: .top, endPoint: .bottom))
                        )
                        .frame(maxWidth: 300, alignment: .trailing)
                        .accessibilityLabel("Message")
                        .accessibilityIdentifier("letknow.message")
                    Label(editing ? "Editing" : "Tap to edit", systemImage: "pencil")
                        .font(.akCaption)
                        .foregroundStyle(Palette.cream.opacity(0.45))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 8)

                VStack(spacing: 12) {
                    PrimaryButton("Send a text", systemImage: "message.fill") {
                        editing = false
                        if MFMessageComposeViewController.canSendText() {
                            showComposer = true
                        } else {
                            showShare = true
                        }
                    }
                    .accessibilityIdentifier("letknow.send")
                    Button("Not now") {
                        Haptics.tap()
                        flow.finishLetThemKnow()
                    }
                    .font(.akHeadline)
                    .foregroundStyle(Palette.cream.opacity(0.7))
                    .frame(minHeight: 48)
                    .accessibilityIdentifier("letknow.skip")
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if message.isEmpty {
                message = "I just prayed for you 🙏 \(AppLinks.shareURL.absoluteString)"
            }
        }
        .sheet(isPresented: $showComposer) {
            MessageComposer(body: message) { sent in
                showComposer = false
                if sent { Haptics.success() }
                flow.finishLetThemKnow()
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showShare, onDismiss: { flow.finishLetThemKnow() }) {
            ShareSheet(items: [message])
                .presentationDetents([.medium, .large])
        }
    }
}

/// A speech-bubble shape with a tail on the bottom right.
struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 20
        var path = Path(roundedRect: rect, cornerRadius: r, style: .continuous)
        var tail = Path()
        tail.move(to: CGPoint(x: rect.maxX - 18, y: rect.maxY - 12))
        tail.addQuadCurve(to: CGPoint(x: rect.maxX + 5, y: rect.maxY + 2), control: CGPoint(x: rect.maxX - 2, y: rect.maxY - 2))
        tail.addQuadCurve(to: CGPoint(x: rect.maxX - 26, y: rect.maxY - 2), control: CGPoint(x: rect.maxX - 12, y: rect.maxY + 2))
        tail.closeSubpath()
        path.addPath(tail)
        return path
    }
}

/// MFMessageComposeViewController wrapper.
struct MessageComposer: UIViewControllerRepresentable {
    let body: String
    var recipients: [String] = []
    let onFinish: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.body = body
        controller.recipients = recipients
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (Bool) -> Void
        init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            onFinish(result == .sent)
        }
    }
}
