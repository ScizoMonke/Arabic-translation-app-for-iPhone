import Darwin
import Foundation
import os

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

    /// TIME lines (R27, R28): local wall-clock time with milliseconds, the
    /// ISO 8601 extended time format, e.g. 14:02:03.120.
    private let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    func clock(_ date: Date) -> String {
        clockFormatter.string(from: date)
    }

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

/// R10/R13: how close the app is to iOS killing it for memory. One line per call,
/// written to the session log after each model load and each utterance so the
/// user can report it from the Files app.
///   footprint      phys_footprint, the number the kernel's memory limit is checked against
///   peak           ledger_phys_footprint_peak, the highest footprint since launch
///   resident       pages in RAM, including the memory-mapped model weights
///   peak resident  resident_size_peak
///   headroom       os_proc_available_memory(): what is left before the limit
enum MemoryProbe {
    static func line() -> String {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), reboundPointer, &count)
            }
        }
        let headroom = megabytes(os_proc_available_memory())
        guard result == KERN_SUCCESS else {
            return "MEM task_info failed (\(result)); headroom \(headroom) MB"
        }
        return "MEM footprint \(megabytes(info.phys_footprint)) MB, peak \(megabytes(info.ledger_phys_footprint_peak)) MB, "
            + "resident \(megabytes(info.resident_size)) MB, peak resident \(megabytes(info.resident_size_peak)) MB, "
            + "headroom \(headroom) MB"
    }

    /// Generic because the SDK declares these fields with different integer types
    /// (mach_vm_size_t, int64_t, size_t).
    private static func megabytes<T: BinaryInteger>(_ bytes: T) -> Int64 {
        Int64(bytes) / 1_048_576
    }
}
