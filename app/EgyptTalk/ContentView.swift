import SwiftUI
import Translation

/// Every string these views show comes from AppModel's render paths, already
/// cleaned of Arabic script (D5). Labels written here are English literals.
struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if model.phase == .ready {
            ConversationView()
        } else {
            SetupView()
        }
    }
}

// MARK: - Conversation: the split screen

struct ConversationView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingPackSheet = false

    var body: some View {
        VStack(spacing: 0) {
            TheirHalf(lines: model.topLines)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            StatusBar(showingPackSheet: $showingPackSheet)
            MyHalf()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingPackSheet) {
            NavigationStack {
                ScrollView {
                    TranslationPackSection()
                        .padding()
                }
                .navigationTitle("Apple Arabic pack")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingPackSheet = false }
                    }
                }
            }
            .environmentObject(model)
        }
    }
}

/// Top half: English for what is said around him.
struct TheirHalf: View {
    let lines: [TopLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THEY SAID")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(lines) { line in
                            let isNewest = line.id == lines.last?.id
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.english)
                                    .font(isNewest ? Font.title2.weight(.semibold) : Font.body)
                                    .foregroundStyle(isNewest ? Color.primary : Color.secondary)
                                if let note = line.note {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: lines.last?.id) { _, newID in
                    guard let newID else { return }
                    withAnimation { proxy.scrollTo(newID, anchor: .bottom) }
                }
            }
        }
        .background(Color(.systemBackground))
    }
}

/// Bottom half: for each thing he said, the English heard, the Egyptian to say
/// in Latin letters (largest), the meaning check (D13, D20), and a small tag
/// saying whether it came from the phrasebook or the model (D22).
///
/// D34: the whole half is the talk button. A transparent layer over it takes
/// every touch: touch down begins a hold, lifting the finger ends it. The press
/// is a @GestureState, which SwiftUI resets both when the finger lifts AND when
/// the system cancels the touch (a call, Control Center), so a hold cannot be
/// left on by a touch that never "ended". The history underneath no longer
/// scrolls by hand; it keeps the newest card in view by itself.
struct MyHalf: View {
    @EnvironmentObject private var model: AppModel
    @GestureState private var pressing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("YOU SAY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if model.isComposing {
                    ProgressView()
                        .controlSize(.mini)
                    Text("working out the Egyptian")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            HoldPrompt()
                .padding(.horizontal)
                .padding(.top, 4)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(model.bottomLines) { line in
                            let isNewest = line.id == model.bottomLines.last?.id
                            VStack(alignment: .leading, spacing: 4) {
                                Text("You: \(line.heard)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(line.latin)
                                    .font(.system(size: isNewest ? 34 : 22, weight: .bold))
                                    .foregroundStyle(isNewest ? Color.primary : Color.secondary)
                                Text(line.gloss)
                                    .font(.callout)
                                    .italic()
                                    .foregroundStyle(.secondary)
                                Text(line.source)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().strokeBorder(Color.secondary.opacity(0.5)))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: model.bottomLines.last?.id) { _, newID in
                    guard let newID else { return }
                    withAnimation { proxy.scrollTo(newID, anchor: .bottom) }
                }
            }
        }
        .background(model.isHolding ? Color.blue.opacity(0.16) : Color(.secondarySystemBackground))
        .overlay {
            if model.isHolding {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.blue, lineWidth: 3)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($pressing) { _, isPressed, _ in
                            isPressed = true
                        }
                )
        }
        .onChange(of: pressing) { _, isPressed in
            if isPressed {
                model.beginHold()
            } else {
                model.endHold()
            }
        }
    }
}

/// The line under "YOU SAY": how to talk, what is being heard right now, or why
/// talking cannot work yet.
struct HoldPrompt: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if model.isHolding {
            VStack(alignment: .leading, spacing: 2) {
                Label("Listening to you. Let go when you are done.", systemImage: "mic.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.blue)
                Text(model.liveHeard.isEmpty ? "..." : model.liveHeard)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if !model.liveHeard.isEmpty {
            Text("You: \(model.liveHeard)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let problem = model.englishProblem {
            Text(problem)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Label("Press and hold anywhere here, speak English, let go.", systemImage: "hand.tap")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The middle strip: microphone indicator, Apple pack button, last status.
struct StatusBar: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showingPackSheet: Bool

    // The hold is shown from the model's own flag: the mic's state stream can
    // lag a buffer behind a touch.
    private var micColor: Color {
        if model.isHolding { return .blue }
        switch model.micState {
        case .off: return .gray
        case .listening: return .green
        case .hearing: return .orange
        case .holding: return .blue
        }
    }

    private var micLabel: String {
        if model.isHolding { return "Your turn: top half paused" }
        switch model.micState {
        case .off: return "Mic off"
        case .listening: return "Listening for Arabic"
        case .hearing: return "Hearing"
        case .holding: return "Your turn: top half paused"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(micColor)
                    .frame(width: 14, height: 14)
                Text(micLabel)
                    .font(.footnote.weight(.semibold))
                if model.isWorking {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button {
                    showingPackSheet = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Apple Arabic pack")
            }
            if let message = model.statusMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

// MARK: - Setup: one time, at home, on Wi-Fi

struct SetupView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Egypt Talk")
                    .font(.largeTitle.bold())
                Text("One-time setup, at home on Wi-Fi. Two downloads: the speech model (about 950 MB) and the Egyptian model (about 2.5 GB). Both stay on the phone, and after setup the app needs no internet. Keep the app open and the screen on until it says it is ready. If a download stops, tap Try again: it carries on from where it stopped. The Egyptian model downloads only over Wi-Fi, never mobile data.")
                    .font(.body)

                switch model.phase {
                case .checking:
                    ProgressView("Checking what is already on the phone")
                case .needsDownload:
                    Button {
                        Task { await model.downloadModels() }
                    } label: {
                        Label("Download the two models", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                case .downloading(let label, let fraction):
                    ProgressView(value: fraction) {
                        Text("\(label): \(Int(fraction * 100))%")
                    }
                case .preparing(let message):
                    ProgressView(message)
                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.red)
                    Button("Try again") {
                        Task { await model.retry() }
                    }
                    .buttonStyle(.bordered)
                case .ready:
                    Text("Ready.")
                }

                Divider()
                TranslationPackSection()
            }
            .padding()
        }
    }
}

/// Optional second engine: Apple's on-device Arabic to English pack, used when
/// Whisper answers in Arabic, and later as the gloss engine. Downloading it uses
/// Apple's own prompt, so it must also be done at home on Wi-Fi.
struct TranslationPackSection: View {
    @EnvironmentObject private var model: AppModel
    @State private var configuration: TranslationSession.Configuration?

    private var statusText: String {
        switch model.translationStatus {
        case .installed: return "Installed on this phone. Works offline."
        case .supported: return "Available but not downloaded yet."
        case .unsupported: return "Not available on this phone."
        case nil: return "Checking..."
        @unknown default: return "Unknown state."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Apple Arabic pack (needed for the meaning check)")
                .font(.headline)
            Text("Under each Egyptian sentence, Egypt Talk shows what it means in English, translated back by Apple on this phone. Without this pack that line says the check is unavailable.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
            if model.translationStatus == .supported {
                Button("Download Apple Arabic pack") {
                    if configuration == nil {
                        configuration = TranslationSession.Configuration(
                            source: AppleTranslator.arabic,
                            target: AppleTranslator.english
                        )
                    } else {
                        configuration?.invalidate()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .translationTask(configuration) { session in
            do {
                // Shows Apple's download prompt when the pair is not installed.
                try await session.prepareTranslation()
            } catch {
                print("Arabic pack download did not finish: \(error)")
            }
            await model.refreshTranslationStatus()
        }
        .task { await model.refreshTranslationStatus() }
    }
}
