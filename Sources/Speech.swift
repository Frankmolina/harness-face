import AppKit
import ApplicationServices
import AVFoundation

/// Reads text aloud with the free macOS voice. It prefers the current selection
/// in the frontmost app and falls back to the pasteboard. Nothing is sent anywhere.
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let harnessBundleID = "com.deepseek.dsh"
    private(set) var isSpeaking = false
    var onStateChange: ((Bool) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Reads the current selection, or the pasteboard when nothing is selected.
    @discardableResult
    func readSelection() -> String? {
        if isSpeaking {
            stop()
            return nil
        }
        let text = selectedText() ?? NSPasteboard.general.string(forType: .string) ?? ""
        let clean = Self.clean(text)
        guard !clean.isEmpty else {
            NSLog("Speaker: no hay nada que leer")
            return nil
        }
        speak(clean)
        return clean
    }

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        isSpeaking = true
        onStateChange?(true)
        synthesizer.speak(utterance)
    }

    func stop() {
        guard isSpeaking || synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        onStateChange?(false)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        onStateChange?(false)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        onStateChange?(false)
    }

    /// Spanish voice when available, otherwise the system default.
    private static func voice() -> AVSpeechSynthesisVoice? {
        for identifier in ["es-ES", "es-MX", "es-AR", "es-US"] {
            if let voice = AVSpeechSynthesisVoice(language: identifier) { return voice }
        }
        return AVSpeechSynthesisVoice(language: "es")
    }

    /// Strips markdown noise so the reading sounds natural.
    static func clean(_ raw: String) -> String {
        var text = raw
        text = text.replacingOccurrences(of: "```", with: " ")
        text = text.replacingOccurrences(of: "`", with: "")
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "__", with: "")
        text = text.replacingOccurrences(of: "#", with: "")
        text = text.replacingOccurrences(of: ">", with: "")
        text = text.replacingOccurrences(of: "|", with: " ")
        // Turn markdown links into their label.
        while let open = text.firstIndex(of: "["),
              let close = text[open...].firstIndex(of: "]"),
              let parenIndex = text.index(close, offsetBy: 1, limitedBy: text.endIndex),
              parenIndex < text.endIndex,
              text[parenIndex] == "(",
              let end = text[parenIndex...].firstIndex(of: ")") {
            let label = String(text[text.index(after: open)..<close])
            text.replaceSubrange(open...end, with: label)
        }
        let lines = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: ". ")
    }

    /// Reads AXSelectedText from the focused element, preferring Harness.
    private func selectedText() -> String? {
        var apps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == harnessBundleID
        }
        if let front = NSWorkspace.shared.frontmostApplication, !apps.contains(where: { $0 == front }) {
            apps.append(front)
        }

        for app in apps {
            let ax = AXUIElementCreateApplication(app.processIdentifier)
            var focused: CFTypeRef?
            guard AXUIElementCopyAttributeValue(ax, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
                  let focused
            else { continue }
            var selected: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                focused as! AXUIElement,
                kAXSelectedTextAttribute as CFString,
                &selected
            )
            if result == .success, let text = selected as? String, !text.isEmpty {
                return text
            }
        }
        return nil
    }
}
