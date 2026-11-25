import Flutter
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Intelligence's on-device model, for study notes on a verse, a word's
/// meaning in plain English, and quizzes. Everything runs on the phone, with no
/// connection. On phones without Apple Intelligence (or before iOS 26) it says
/// so, and the app keeps to its own study tools.
///
/// FoundationModels is weak linked (Runner build settings), so the app still
/// opens on iOS 16 to 25.
class AIChannel: NSObject {
    static let channelName = "com.dailykjb/ai"
    private var channel: FlutterMethodChannel?

    func register(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: AIChannel.channelName, binaryMessenger: messenger)
        channel?.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let args = call.arguments as? [String: Any] ?? [:]
            switch call.method {
            case "availability":
                result(Writer.availability())
            case "explainVerse":
                run(result) { try await Writer.explainVerse(args) }
            case "wordMeaning":
                run(result) { try await Writer.wordMeaning(args) }
            case "quiz":
                run(result) { try await Writer.quiz(args) }
            default:
                result(FlutterMethodNotImplemented)
            }
            return
        }
        #endif
        if call.method == "availability" {
            result("unsupported")
        } else {
            result(FlutterError(code: "UNAVAILABLE", message: "Apple Intelligence isn't available.", details: nil))
        }
    }

    private func run(_ result: @escaping FlutterResult, _ work: @escaping () async throws -> String) {
        Task {
            do {
                let out = try await work()
                await MainActor.run { result(out) }
            } catch {
                await MainActor.run {
                    result(FlutterError(code: "GENERATION", message: "\(error)", details: nil))
                }
            }
        }
    }
}

#if canImport(FoundationModels)

@available(iOS 26.0, *)
private enum Writer {
    /// The rules every answer keeps.
    static let rules = """
    You help a Christian read the King James Bible. Rules, without exception:
    - The King James Bible is the preserved, inerrant word of God and the final authority. Quote only King James words given to you. Never quote, name or suggest another translation or paraphrase, and never say the King James "should read" anything else.
    - Hebrew and Greek (Strong's) may only help explain what the King James English means. Never correct it or retranslate it.
    - Salvation is by grace through faith in the Lord Jesus Christ alone, not by works. The gospel is for whosoever will.
    - No higher criticism and no "scholars say". Never invent history, names, dates, numbers or customs; if the text and what's given don't settle something, leave it out.
    - Old English words are explained as they were meant in 1611 (conversation: manner of life; let: hinder; prevent: go before), never replaced.
    - Plain, warm, reverent words; short sentences. Say "the Bible" or "the King James Bible".
    - Scripture references are written "Book chapter:verse" (Romans 5:8).
    """

    static func availability() -> String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "available"
        case .unavailable(.deviceNotEligible):
            return "deviceNotEligible"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "appleIntelligenceNotEnabled"
        case .unavailable(.modelNotReady):
            return "modelNotReady"
        case .unavailable:
            return "unsupported"
        }
    }

    static func text(_ args: [String: Any], _ key: String) -> String {
        (args[key] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func session(_ task: String) -> LanguageModelSession {
        LanguageModelSession(instructions: rules + "\n\n" + task)
    }

    static func json<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    }

    // MARK: Study notes on a verse

    @Generable
    struct WordNote: Encodable {
        @Guide(description: "A word or short phrase exactly as the King James verse has it")
        var word: String
        @Guide(description: "What it means here, one sentence")
        var meaning: String
    }

    @Generable
    struct TruthNote: Encodable {
        @Guide(description: "A doctrine or lesson the verse teaches, one sentence")
        var truth: String
        @Guide(description: "Up to two supporting references, each \"Book chapter:verse\", from the cross references given", .count(0...2))
        var refs: [String]
    }

    @Generable
    struct VerseNotes: Encodable {
        @Guide(description: "Who is speaking, to whom, and when or where; one or two sentences")
        var setting: String
        @Guide(description: "What the verse says and means in its setting; two or three sentences")
        var summary: String
        @Guide(description: "Two to four words or phrases from the verse worth explaining", .count(2...4))
        var words: [WordNote]
        @Guide(description: "Two or three truths the verse teaches", .count(2...3))
        var truths: [TruthNote]
        @Guide(description: "For a believer today, one or two sentences")
        var application: String
        @Guide(description: "Only if the verse bears on salvation: one sentence pointing to Christ. Otherwise empty.")
        var gospel: String
    }

    static func explainVerse(_ args: [String: Any]) async throws -> String {
        let prompt = """
        The verse: \(text(args, "reference")): "\(text(args, "text"))"

        Around it:
        \(text(args, "context"))

        Its words in Strong's Concordance:
        \(text(args, "strongs"))

        Cross references:
        \(text(args, "xrefs"))

        Write short study notes on this verse.
        """
        let s = session("You write short study notes on one verse for church members.")
        let r = try await s.respond(to: prompt, generating: VerseNotes.self, options: GenerationOptions(temperature: 0.3))
        return try json(r.content)
    }

    // MARK: A word in plain words

    static func wordMeaning(_ args: [String: Any]) async throws -> String {
        let prompt = """
        The word: "\(text(args, "word"))"
        In \(text(args, "reference")): "\(text(args, "verse"))"

        Strong's Concordance:
        \(text(args, "strongs"))

        Webster's 1828 dictionary:
        \(text(args, "webster"))

        In one to three plain sentences, say what this word means in this verse, drawing on Strong's and Webster's 1828 together. Don't repeat the verse. No lists, no headings.
        """
        let s = session("You explain one word of a King James verse to an ordinary reader.")
        let r = try await s.respond(to: prompt, options: GenerationOptions(temperature: 0.2))
        return r.content
    }

    // MARK: A quiz

    @Generable
    struct Question: Encodable {
        @Guide(description: "A clear question on what the passage says, answerable from the passage alone")
        var question: String
        @Guide(description: "Four short answer choices; only one is right", .count(4))
        var choices: [String]
        @Guide(description: "The index (0 to 3) of the right choice")
        var answer: Int
        @Guide(description: "The verse that answers it, \"Book chapter:verse\"")
        var reference: String
    }

    @Generable
    struct Quiz: Encodable {
        @Guide(description: "Five questions spread across the passage", .count(5))
        var questions: [Question]
    }

    static func quiz(_ args: [String: Any]) async throws -> String {
        let prompt = """
        The passage just read, \(text(args, "passage")):

        \(text(args, "text"))

        Write a short quiz to check that it was read with understanding: what happened, who said what, what it teaches. Use only this passage. Make the wrong choices believable but plainly wrong from the text.
        """
        let s = session("You write a short Bible quiz for someone who just read a passage.")
        let r = try await s.respond(to: prompt, generating: Quiz.self, options: GenerationOptions(temperature: 0.4))
        return try json(r.content)
    }
}

#endif
