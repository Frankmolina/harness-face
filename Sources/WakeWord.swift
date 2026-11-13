import AVFoundation
import Speech

/// Always-on, local wake-word listener for "Veniron".
/// It owns the microphone only while idle; Dictation stops it before recording.
final class WakeWord {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var running = false
    private var restartWork: DispatchWorkItem?
    var enabled = true
    var onWake: (() -> Void)?

    func start() {
        guard enabled, !running else { return }
        guard let recognizer, recognizer.isAvailable else { return }
        running = true
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                self?.running = false
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                guard granted else {
                    self?.running = false
                    return
                }
                DispatchQueue.main.async { self?.begin(recognizer) }
            }
        }
    }

    private func begin(_ recognizer: SFSpeechRecognizer) {
        guard enabled, running else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            running = false
            return
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true

        do {
            engine.prepare()
            try engine.start()
        } catch {
            NSLog("Harness Face: wake word no pudo arrancar: %@", error.localizedDescription)
            cleanup()
            running = false
            return
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let text = result?.bestTranscription.formattedString, Self.containsWakeWord(text) {
                DispatchQueue.main.async {
                    self.stop()
                    self.onWake?()
                }
                return
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async { self.scheduleRestart() }
            }
        }
    }

    func stop() {
        enabled = false
        running = false
        restartWork?.cancel()
        restartWork = nil
        cleanup()
    }

    func resume() {
        enabled = true
        start()
    }

    private func scheduleRestart() {
        guard running, enabled else { return }
        cleanup()
        running = false
        let work = DispatchWorkItem { [weak self] in
            self?.running = false
            self?.start()
        }
        restartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func cleanup() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
    }

    private static func containsWakeWord(_ text: String) -> Bool {
        let folded = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
            .lowercased()
        let compact = folded.replacingOccurrences(of: " ", with: "")
        // "Veniron" and the usual Spanish transcriptions (V/B, accent, joined/split words).
        let candidates = [
            "veniron", "beniron", "venirion", "benirion",
            "venirom", "benirom", "venirron", "benirron",
        ]
        return candidates.contains { compact.contains($0) }
    }
}
