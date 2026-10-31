import Foundation

/// Plain-text record of everything shown on screen, one file per day in the
/// app's Documents folder (visible in Files > On My iPhone > Egypt Talk), so the
/// conversations in Egypt can be reviewed afterwards. Only AppModel's render
/// functions write here, with the same cleaned strings the views receive.
/// Owned and called only by AppModel, which is main-actor isolated.
final class SessionLog {
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var currentFileURL: URL {
        documents.appendingPathComponent("EgyptTalk-\(dayFormatter.string(from: Date())).txt")
    }

    func append(_ line: String) {
        let stamped = "[\(timeFormatter.string(from: Date()))] \(line)\n"
        let url = currentFileURL
        let data = Data(stamped.utf8)
        // A failed log write must not take the conversation down; it is reported
        // to the console and the line stays on screen.
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            print("SessionLog write failed: \(error)")
        }
    }
}
