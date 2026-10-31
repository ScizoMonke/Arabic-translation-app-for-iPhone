import Foundation

/// D22: about 200 vetted family-visit phrases in front of the model. Bundled as
/// Resources/phrasebook.json (authored and audited by a separate wave); when the
/// file is absent from the build, this stage is skipped and every sentence goes
/// to the model.
///
/// Schema (version 1):
/// {"version":1,"entries":[{"id":"greet-01","english":["hello","hi"],"arabic":"...",
///   "arabizi":"...","respelling":"...","gloss":"...","tags":["greeting"]}]}
/// `arabic` and `arabizi` are decoded but never shown; the card shows the entry's
/// own vetted `respelling` and `gloss`.
struct PhrasebookEntry: Decodable, Sendable {
    let id: String
    let english: [String]
    let arabic: String
    let arabizi: String
    let respelling: String
    let gloss: String
    let tags: [String]?
}

struct PhrasebookMatch: Sendable {
    let entry: PhrasebookEntry
    /// The alias that matched, as written in the phrasebook.
    let alias: String
    /// 1.0 for an exact alias match, otherwise the word-set Jaccard similarity.
    let similarity: Double
    var isExact: Bool { similarity >= 1.0 }
}

enum PhrasebookError: LocalizedError {
    case badVersion(Int)
    var errorDescription: String? {
        switch self {
        case .badVersion(let v): return "phrasebook.json has version \(v); this build reads version 1."
        }
    }
}

struct Phrasebook: Sendable {
    static let fileName = "phrasebook"
    /// D22 threshold for a close (non-exact) match.
    static let minimumSimilarity = 0.75

    /// Words whose presence on one side only flips the meaning of a sentence that
    /// is otherwise word-for-word the same ("I don't want tea" vs "I want tea" has
    /// Jaccard 0.75; "please turn left at the next street now" vs "... right ..."
    /// has 0.78). A close match is refused when the two sentences differ in any of
    /// these; an exact alias match is unaffected. Contractions appear without the
    /// apostrophe because `normalize` removes it.
    private static let meaningFlippers: Set<String> = [
        "not", "no", "never", "nothing", "nobody", "none", "dont", "doesnt", "didnt",
        "cant", "cannot", "wont", "isnt", "arent", "wasnt", "werent", "havent", "hasnt",
        "shouldnt", "wouldnt", "couldnt", "without", "yes",
        "left", "right", "before", "after", "more", "less", "too", "much", "many",
        "yesterday", "today", "tomorrow", "tonight", "now", "later",
        "i", "you", "he", "she", "we", "they", "my", "your", "his", "her", "our", "their",
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven", "twelve", "fifteen", "twenty", "thirty", "hundred", "thousand",
    ]

    let entries: [PhrasebookEntry]
    private let exact: [String: (entry: Int, alias: String)]
    private let aliasWords: [(entry: Int, alias: String, words: Set<String>)]

    /// Nil when the build carries no phrasebook.json. Throws when the file is
    /// there but unreadable, so a broken phrasebook is reported, not silently skipped.
    static func loadBundled() throws -> Phrasebook? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            return nil
        }
        let data = try Data(contentsOf: url)
        struct File: Decodable {
            let version: Int
            let entries: [PhrasebookEntry]
        }
        let file = try JSONDecoder().decode(File.self, from: data)
        guard file.version == 1 else { throw PhrasebookError.badVersion(file.version) }
        return Phrasebook(entries: file.entries)
    }

    init(entries: [PhrasebookEntry]) {
        self.entries = entries
        var exact: [String: (entry: Int, alias: String)] = [:]
        var aliasWords: [(entry: Int, alias: String, words: Set<String>)] = []
        for (index, entry) in entries.enumerated() {
            for alias in entry.english {
                let key = Self.normalize(alias)
                guard !key.isEmpty else { continue }
                // First entry in file order wins a duplicated alias.
                if exact[key] == nil { exact[key] = (index, alias) }
                aliasWords.append((index, alias, Set(key.split(separator: " ").map(String.init))))
            }
        }
        self.exact = exact
        self.aliasWords = aliasWords
    }

    /// Lowercase; apostrophes removed (so "don't" and "dont" agree); every other
    /// punctuation or symbol becomes a space; whitespace collapsed.
    static func normalize(_ text: String) -> String {
        var out = ""
        for scalar in text.lowercased().unicodeScalars {
            if scalar == "'" || scalar == "\u{2019}" || scalar == "\u{2018}" {
                continue
            }
            if CharacterSet.punctuationCharacters.contains(scalar) || CharacterSet.symbols.contains(scalar) {
                out.append(" ")
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
        return out.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// D22 matching: an exact alias match wins; otherwise the alias with the
    /// highest word-set Jaccard similarity, if at least 0.75 and not separated
    /// from the heard sentence by a meaning-flipping word; otherwise nil (model).
    func match(_ heard: String) -> PhrasebookMatch? {
        let key = Self.normalize(heard)
        guard !key.isEmpty else { return nil }
        if let hit = exact[key] {
            return PhrasebookMatch(entry: entries[hit.entry], alias: hit.alias, similarity: 1.0)
        }
        let heardWords = Set(key.split(separator: " ").map(String.init))
        var best: (entry: Int, alias: String, similarity: Double)?
        for candidate in aliasWords {
            let union = heardWords.union(candidate.words).count
            guard union > 0 else { continue }
            let similarity = Double(heardWords.intersection(candidate.words).count) / Double(union)
            guard similarity >= Self.minimumSimilarity else { continue }
            let difference = heardWords.symmetricDifference(candidate.words)
            guard difference.isDisjoint(with: Self.meaningFlippers) else { continue }
            // Strictly greater: on a tie the earlier entry in file order stays.
            if best == nil || similarity > best!.similarity {
                best = (candidate.entry, candidate.alias, similarity)
            }
        }
        guard let best else { return nil }
        return PhrasebookMatch(entry: entries[best.entry], alias: best.alias, similarity: best.similarity)
    }
}
