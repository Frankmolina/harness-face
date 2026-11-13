import AVFoundation
import Foundation

/// Local whisper.cpp wrapper. Nothing leaves the Mac.
final class WhisperEngine {
    private let binary = "/opt/homebrew/bin/whisper-cli"
    private let modelDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Harness Face/Models")

    private var modelPath: String? {
        for name in ["ggml-small.bin", "ggml-base.bin"] {
            let path = modelDir.appendingPathComponent(name).path
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }

    func transcribe(url: URL, completion: @escaping (String) -> Void) {
        guard let model = modelPath else {
            NSLog("Whisper: no hay modelo en %@", modelDir.path)
            DispatchQueue.main.async { completion("") }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.binary)
            process.arguments = ["-m", model, "-f", url.path, "-l", "es", "-nt", "-np"]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                let raw = String(data: data, encoding: .utf8) ?? ""
                let text = raw
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !$0.hasPrefix("[") }
                    .joined(separator: " ")
                DispatchQueue.main.async { completion(text) }
            } catch {
                NSLog("Whisper: no pude ejecutar whisper-cli: %@", error.localizedDescription)
                DispatchQueue.main.async { completion("") }
            }
        }
    }
}

final class WhisperRecorder {
    private var recorder: AVAudioRecorder?
    private(set) var currentURL: URL?
    var isRecording: Bool { recorder?.isRecording ?? false }

    func start(duration: TimeInterval? = nil) -> URL? {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            NSLog("Whisper: micrófono sin permiso")
            return nil
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("harness-face-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = false
            if let duration, duration > 0 {
                recorder.record(forDuration: duration)
            } else {
                recorder.record()
            }
            self.recorder = recorder
            self.currentURL = url
            return url
        } catch {
            NSLog("Whisper: no pude grabar: %@", error.localizedDescription)
            return nil
        }
    }

    func stop() -> URL? {
        guard let recorder else { return nil }
        recorder.stop()
        let url = currentURL
        self.recorder = nil
        self.currentURL = nil
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
}

final class WhisperWake {
    private let engine = WhisperEngine()
    private let recorder = WhisperRecorder()
    private var work: DispatchWorkItem?
    private var permissionAsked = false
    private var running = false
    var enabled = true
    var onWake: (() -> Void)?

    func start() {
        guard enabled, !running else { return }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            running = true
            listen()
        } else if !permissionAsked {
            permissionAsked = true
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    self?.running = true
                    self?.listen()
                }
            }
        }
    }

    func stop() {
        enabled = false
        running = false
        work?.cancel()
        work = nil
        _ = recorder.stop()
    }

    func resume() {
        enabled = true
        start()
    }

    private func listen() {
        guard enabled, running else { return }
        guard recorder.start(duration: 3) != nil else {
            work = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.listen() }
            return
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.running else { return }
            guard let url = self.recorder.stop() else {
                self.listen()
                return
            }
            self.engine.transcribe(url: url) { text in
                guard self.running else { return }
                if Self.containsWakeWord(text) {
                    self.stop()
                    self.onWake?()
                } else {
                    self.listen()
                }
            }
        }
        self.work = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: work)
    }

    static func containsWakeWord(_ text: String) -> Bool {
        let folded = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        let candidates = ["veniron", "beniron", "venirion", "benirion", "venirron", "benirron", "venirom", "benirom"]
        return candidates.contains { folded.contains($0) }
    }
}

final class WhisperDictation {
    private let engine = WhisperEngine()
    private let recorder = WhisperRecorder()
    private var timeout: DispatchWorkItem?
    private(set) var isRecording = false
    var onStateChange: ((Bool) -> Void)?
    var onFinal: ((String) -> Void)?
    var onFinished: (() -> Void)?

    func toggle() {
        if isRecording { stop() } else { start() }
    }

    func start() {
        guard !isRecording else { return }
        guard recorder.start() != nil else {
            onFinished?()
            return
        }
        isRecording = true
        onStateChange?(true)
        let timeout = DispatchWorkItem { [weak self] in self?.stop() }
        self.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        timeout?.cancel()
        timeout = nil
        onStateChange?(false)
        guard let url = recorder.stop() else {
            onFinished?()
            return
        }
        engine.transcribe(url: url) { [weak self] text in
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { self?.onFinal?(clean) }
            self?.onFinished?()
        }
    }
}
