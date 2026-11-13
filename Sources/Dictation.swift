import AppKit
import AVFoundation
import Speech

/// Native macOS dictation for Harness Face. It never sends anything: the final
/// transcript goes to the pasteboard and is pasted into the focused Harness chat.
final class Dictation {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var stopWork: DispatchWorkItem?
    private(set) var isRecording = false
    var onStateChange: ((Bool) -> Void)?
    var onFinal: ((String) -> Void)?

    func toggle() {
        if isRecording { stop() } else { start() }
    }

    func start() {
        guard !isRecording else { return }
        guard let recognizer, recognizer.isAvailable else {
            NSLog("Harness Face: el reconocedor de español no está disponible")
            return
        }
        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            guard speechStatus == .authorized else {
                NSLog("Harness Face: permiso de reconocimiento de voz denegado")
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                guard granted else {
                    NSLog("Harness Face: permiso de micrófono denegado")
                    return
                }
                DispatchQueue.main.async { self?.begin(recognizer) }
            }
        }
    }

    private func begin(_ recognizer: SFSpeechRecognizer) {
        guard !isRecording else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            NSLog("Harness Face: no hay formato de micrófono")
            self.request = nil
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
            NSLog("Harness Face: no pude arrancar el micrófono: %@", error.localizedDescription)
            cleanup(cancelTask: true)
            return
        }

        isRecording = true
        onStateChange?(true)
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result, result.isFinal {
                let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    self.stopWork?.cancel()
                    self.stopWork = nil
                    self.cleanup(cancelTask: false)
                    if !text.isEmpty { self.onFinal?(text) }
                }
            } else if error != nil {
                DispatchQueue.main.async { self.cleanup(cancelTask: true) }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        onStateChange?(false)
        // Let Speech deliver the final result; do not cancel it here.
        request?.endAudio()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        stopWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.stopWork = nil
            self?.cleanup(cancelTask: true)
        }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    private func cleanup(cancelTask: Bool) {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        request = nil
        if cancelTask { task?.cancel() }
        task = nil
        if isRecording {
            isRecording = false
            onStateChange?(false)
        }
    }
}
