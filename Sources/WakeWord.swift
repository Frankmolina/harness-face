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
    private let debugURL = URL(fileURLWithPath: "/tmp/harness-wake.log")

    private func log(_ message: String) {
        let line = "\(Date()) \(message)\n"
        if let handle = try? FileHandle(forWritingTo: debugURL) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8) ?? Data())
            try? handle.close()
        } else {
            try? line.write(to: debugURL, atomically: true, encoding: .utf8)
        }
    }

    func start() {
        log("start enabled=\(enabled) running=\(running)")
        guard enabled, !running else { return }
        guard let recognizer, recognizer.isAvailable else {
            log("recognizer not available")
            return
        }
        running = true
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            self?.log("speech auth=\(status.rawValue)")
            guard status == .authorized else {
                self?.running = false
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                self?.log("mic granted=\(granted)")
                guard granted else {
                    self?.running = false
                    return
                }
                DispatchQueue.main.async { self?.begin(recognizer) }
            }
        }
    }

    private func begin(_ recognizer: SFSpeechRecognizer) {
        log("begin enabled=\(enabled) running=\(running)")
        guard enabled, running else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Do not force on-device: the Spanish asset can invalidate and leave the
        // listener silent. Apple's Speech service decides the best path.
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
            log("engine started")
        } catch {
            log("engine error: \(error.localizedDescription)")
            cleanup()
            running = false
            return
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let text = result?.bestTranscription.formattedString {
                log("heard: \(text)")
            }
            if let error {
                log("task error: \(error.localizedDescription)")
            }
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
