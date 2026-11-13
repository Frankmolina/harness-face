import AVFoundation
import Foundation

/// Local whisper.cpp wrapper. Nothing leaves the Mac.
final class WhisperEngine {
    private let binary = "/opt/homebrew/bin/whisper-cli"
    private let modelDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Harness Face/Models")

    private let logURL = URL(fileURLWithPath: "/tmp/harness-whisper-engine.log")
    private func log(_ message: String) {
        let line = "\(Date()) \(message)\n"
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8) ?? Data())
            try? handle.close()
        } else {
            try? line.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

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
                self.log("text=\(text)")
                DispatchQueue.main.async { completion(text) }
            } catch {
                NSLog("Whisper: no pude ejecutar whisper-cli: %@", error.localizedDescription)
                DispatchQueue.main.async { completion("") }
            }
        }
    }
}

final class WhisperRecorder {
    private let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Harness Face/whisper.log")
    private func log(_ message: String) {
        let line = "\(Date()) \(message)\n"
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8) ?? Data())
            try? handle.close()
        } else {
            try? line.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

    private var recorder: AVAudioRecorder?
    private(set) var currentURL: URL?
    var isRecording: Bool { recorder?.isRecording ?? false }
    var averagePower: Float {
        recorder?.updateMeters()
        return recorder?.averagePower(forChannel: 0) ?? -160
    }

    func start(duration: TimeInterval? = nil) -> URL? {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        log("start status=\(status.rawValue)")
        guard status == .authorized else {
            log("no autorizado")
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
            recorder.isMeteringEnabled = true
            if let duration, duration > 0 {
                recorder.record(forDuration: duration)
            } else {
                recorder.record()
            }
            self.recorder = recorder
            self.currentURL = url
            return url
        } catch {
            log("AVAudioRecorder error: \(error.localizedDescription)")
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
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        log("stop \(url.lastPathComponent) size=\(size ?? 0)")
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
        guard recorder.start(duration: 5) != nil else {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.2, execute: work)
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
    private var silenceTimer: DispatchSourceTimer?
    private var heardSpeech = false
    private var lastVoice = Date()
    private(set) var isRecording = false
    var onStateChange: ((Bool) -> Void)?
    var onFinal: ((String) -> Void)?
    var onFinished: (() -> Void)?

    private func checkSilence() {
        guard isRecording else { return }
        let power = recorder.averagePower
        if power > -35 {
            heardSpeech = true
            lastVoice = Date()
        } else if heardSpeech, Date().timeIntervalSince(lastVoice) > 1.8 {
            stop()
        }
    }

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
        heardSpeech = false
        lastVoice = Date()
        onStateChange?(true)
        let timeout = DispatchWorkItem { [weak self] in self?.stop() }
        self.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
        silenceTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.25, repeating: 0.25)
        timer.setEventHandler { [weak self] in self?.checkSilence() }
        timer.resume()
        silenceTimer = timer
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        timeout?.cancel()
        timeout = nil
        silenceTimer?.cancel()
        silenceTimer = nil
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

/// Continuous wake listener using whisper-stream: one microphone session, no
/// start/stop flicker. It is killed before dictation records.
final class WhisperStreamWake {
    private let binary = "/opt/homebrew/bin/whisper-stream"
    private let modelDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Harness Face/Models")
    private var process: Process?
    private var buffer = ""
    private var running = false
    var enabled = true
    var onWake: (() -> Void)?

    private var modelPath: String? {
        for name in ["ggml-small.bin", "ggml-base.bin"] {
            let path = modelDir.appendingPathComponent(name).path
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }

    func start() {
        guard enabled, !running, let model = modelPath else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = [
            "-m", model, "-l", "es",
            "--step", "2500", "--length", "6000", "--keep", "300",
        ]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.consume(chunk) }
        }
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.process = nil
                self?.running = false
                if self?.enabled == true {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.start() }
                }
            }
        }
        do {
            try process.run()
            self.process = process
            running = true
        } catch {
            NSLog("Whisper stream: no pude arrancar: %@", error.localizedDescription)
        }
    }

    func stop() {
        enabled = false
        running = false
        process?.terminate()
        process = nil
        buffer = ""
    }

    func resume() {
        enabled = true
        start()
    }

    private func consume(_ chunk: String) {
        guard running, enabled else { return }
        buffer.append(chunk)
        if buffer.count > 4000 { buffer = String(buffer.suffix(2000)) }
        if Self.containsWakeWord(buffer) {
            stop()
            onWake?()
        }
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
