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
            MyHalf(lines: model.bottomLines)
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
                                    .font(isNewest ? .title2.weight(.semibold) : .body)
                                    .foregroundStyle(isNewest ? .primary : .secondary)
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
/// in Latin letters (largest), and its literal meaning (D13).
struct MyHalf: View {
    let lines: [BottomLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOU SAY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(lines) { line in
                            let isNewest = line.id == lines.last?.id
                            VStack(alignment: .leading, spacing: 4) {
                                Text("You: \(line.heard)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(line.latin)
                                    .font(.system(size: isNewest ? 34 : 22, weight: .bold))
                                    .foregroundStyle(isNewest ? .primary : .secondary)
                                Text("Means: \(line.gloss)")
                                    .font(.callout)
                                    .italic()
                                    .foregroundStyle(.secondary)
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
        .background(Color(.secondarySystemBackground))
    }
}

/// The middle strip: microphone indicator, Auto/Them/Me switch, last status.
struct StatusBar: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showingPackSheet: Bool

    private var micColor: Color {
        switch model.micState {
        case .off: return .gray
        case .listening: return .green
        case .hearing: return .orange
        }
    }

    private var micLabel: String {
        switch model.micState {
        case .off: return "Mic off"
        case .listening: return "Listening"
        case .hearing: return "Hearing"
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
                Picker("Who is speaking", selection: $model.routing) {
                    ForEach(Routing.allCases) { routing in
                        Text(routing.rawValue).tag(routing)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
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
                Text("One-time setup, at home on Wi-Fi. This downloads the speech model (about 950 MB) and keeps it on the phone. After setup the app needs no internet. Keep the app open and the phone awake until it says it is ready.")
                    .font(.body)

                switch model.phase {
                case .checking:
                    ProgressView("Checking what is already on the phone")
                case .needsDownload:
                    Button {
                        Task { await model.downloadModel() }
                    } label: {
                        Label("Download speech model", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                case .downloading(let fraction):
                    ProgressView(value: fraction) {
                        Text("Downloading: \(Int(fraction * 100))%")
                    }
                case .preparing:
                    ProgressView("Preparing the model for this phone. The first time can take several minutes.")
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
            Text("Apple Arabic pack (optional backup)")
                .font(.headline)
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
