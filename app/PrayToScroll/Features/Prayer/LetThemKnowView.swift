import MessageUI
import SwiftUI

/// "Let Sarah know?" The text that turns a private prayer into a moment of grace (and PrayToScroll's best growth loop).
/// One button opens Messages with their number and the text filled in; they only tap Send.
struct LetThemKnowView: View {
    @Bindable var flow: PrayerFlow
    @State private var message: String = ""
    @State private var showComposer = false
    @State private var showShare = false
    @State private var showPicker = false
    #if DEBUG
    @State private var showDemoComposer = false
    #endif
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
                    Text(flow.personPhone == nil
                         ? "You just prayed for them. A short text can carry a lot of grace."
                         : "You just prayed for them. One tap opens the text, ready to send.")
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
                    PrimaryButton("Let \(flow.personFirstName) know", systemImage: "message.fill", action: send)
                        .accessibilityIdentifier("letknow.send")
                    if let phone = flow.personPhone {
                        Text("To \(phone)")
                            .font(.akFootnote)
                            .foregroundStyle(Palette.cream.opacity(0.55))
                            .accessibilityIdentifier("letknow.to")
                    } else {
                        Button {
                            showPicker = true
                        } label: {
                            Label("Pick their number from Contacts", systemImage: "person.crop.circle.badge.plus")
                        }
                        .font(.akSubheadlineSemibold)
                        .foregroundStyle(Palette.warmGold)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("letknow.pickNumber")
                    }
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
                message = flow.letThemKnowMessage
            }
        }
        .background(
            ContactPickerPresenter(isPresented: $showPicker) { picked in
                flow.setPhone(picked?.phone)
            }
        )
        .sheet(isPresented: $showComposer) {
            MessageComposer(body: message, recipients: flow.personPhone.map { [$0] } ?? []) { sent in
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
        #if DEBUG
        .sheet(isPresented: $showDemoComposer) {
            DemoMessageComposer(recipients: flow.personPhone.map { [$0] } ?? [], text: message) { sent in
                showDemoComposer = false
                if sent { Haptics.success() }
                flow.finishLetThemKnow()
            }
        }
        #endif
    }

    /// Messages with their number and the text filled in. Without Messages (an iPad, a Mac, the simulator):
    /// the share sheet, which also has Copy.
    private func send() {
        editing = false
        #if DEBUG
        if LaunchOptions.current.isDemo {
            showDemoComposer = true
            return
        }
        #endif
        if MFMessageComposeViewController.canSendText() {
            showComposer = true
        } else {
            showShare = true
        }
    }
}

#if DEBUG
/// Debug builds only: stands in for Apple's Messages sheet in demo runs (the simulator can't send texts), so UI tests
/// can check the composer was asked for with the right number and text. Not in the Release binary.
struct DemoMessageComposer: View {
    let recipients: [String]
    let text: String
    let onFinish: (Bool) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("To: \(recipients.joined(separator: ", "))")
                    .font(.akHeadline)
                    .accessibilityIdentifier("demo.composer.to")
                Text(text)
                    .font(.akBody)
                    .accessibilityIdentifier("demo.composer.body")
                Spacer()
            }
            .padding(24)
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onFinish(false) } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { onFinish(true) }.accessibilityIdentifier("demo.composer.send")
                }
            }
        }
        .accessibilityIdentifier("demo.composer")
    }
}
#endif

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
    static var canSend: Bool { MFMessageComposeViewController.canSendText() }

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
