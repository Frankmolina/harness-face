import AppKit
import ApplicationServices
import Carbon
import ServiceManagement

private let harnessBundleID = "com.deepseek.dsh"
private let harnessAppPath = "/Applications/DeepSeek Harness.app"

final class MaskView: NSView {
    var onOpen: (() -> Void)?
    var onQuit: (() -> Void)?
    var onDictate: (() -> Void)?
    var onToggleLogin: ((Bool) -> Void)?
    var onToggleContinuous: ((Bool) -> Void)?
    var onTogglePause: ((Bool) -> Void)?
    var onRead: (() -> Void)?
    var launchAtLogin = false
    var continuous = true
    var paused = false
    private var hovered = false
    private var listening = false
    private var tracking: NSTrackingArea?
    private var downPoint: NSPoint?
    private var dragged = false

    // El dibujo usa fracciones contadas desde arriba (top = 0.20, chin = 0.82).
    // Con isFlipped = true el origen y=0 es el borde superior y la cara sale derecha;
    // con false salía invertida (barbilla arriba, ojos abajo).
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)

        // Hover and listening shrink the mask without moving the always-on-top panel.
        let inset: CGFloat = listening ? 12 : hovered ? 8 : 4
        let bounds = self.bounds.insetBy(dx: inset, dy: inset)

        // Electric blue halo behind the mask.
        let halo = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
        NSColor(calibratedRed: 0.0, green: 0.70, blue: 1.0, alpha: 0.22).setFill()
        halo.fill()

        // Dark disc.
        let disc = NSBezierPath(ovalIn: bounds.insetBy(dx: 7, dy: 7))
        NSColor(calibratedWhite: 0.04, alpha: 0.96).setFill()
        disc.fill()
        NSColor(calibratedRed: 0.0, green: 0.70, blue: 1.0, alpha: 0.95).setStroke()
        disc.lineWidth = 2.5
        disc.stroke()

        // Ivory Vendetta-style face, narrow chin.
        let face = NSBezierPath()
        let cx = bounds.midX
        let top = bounds.minY + bounds.height * 0.20
        let bottom = bounds.minY + bounds.height * 0.82
        let half = bounds.width * 0.24
        face.move(to: NSPoint(x: cx, y: bottom))
        face.curve(to: NSPoint(x: cx - half, y: bounds.minY + bounds.height * 0.43),
                   controlPoint1: NSPoint(x: cx - half * 0.75, y: bounds.minY + bounds.height * 0.68),
                   controlPoint2: NSPoint(x: cx - half, y: bounds.minY + bounds.height * 0.56))
        face.curve(to: NSPoint(x: cx, y: top),
                   controlPoint1: NSPoint(x: cx - half, y: bounds.minY + bounds.height * 0.25),
                   controlPoint2: NSPoint(x: cx - half * 0.55, y: top))
        face.curve(to: NSPoint(x: cx + half, y: bounds.minY + bounds.height * 0.43),
                   controlPoint1: NSPoint(x: cx + half * 0.55, y: top),
                   controlPoint2: NSPoint(x: cx + half, y: bounds.minY + bounds.height * 0.25))
        face.curve(to: NSPoint(x: cx, y: bottom),
                   controlPoint1: NSPoint(x: cx + half, y: bounds.minY + bounds.height * 0.56),
                   controlPoint2: NSPoint(x: cx + half * 0.75, y: bounds.minY + bounds.height * 0.68))
        face.close()
        NSColor(calibratedRed: 0.94, green: 0.92, blue: 0.84, alpha: 1).setFill()
        face.fill()

        // Eyes.
        NSColor(calibratedWhite: 0.03, alpha: 1).setFill()
        for dx in [-1.0, 1.0] {
            let eye = NSBezierPath()
            let ex = cx + dx * half * 0.44
            let ey = bounds.minY + bounds.height * 0.43
            eye.move(to: NSPoint(x: ex - 7, y: ey))
            eye.curve(to: NSPoint(x: ex + 7, y: ey),
                      controlPoint1: NSPoint(x: ex - 3, y: ey + 5),
                      controlPoint2: NSPoint(x: ex + 3, y: ey + 5))
            eye.curve(to: NSPoint(x: ex - 7, y: ey),
                      controlPoint1: NSPoint(x: ex + 3, y: ey - 3),
                      controlPoint2: NSPoint(x: ex - 3, y: ey - 3))
            eye.close()
            eye.fill()
        }

        // Moustache.
        let moustache = NSBezierPath()
        moustache.move(to: NSPoint(x: cx - 13, y: bounds.minY + bounds.height * 0.55))
        moustache.curve(to: NSPoint(x: cx, y: bounds.minY + bounds.height * 0.58),
                        controlPoint1: NSPoint(x: cx - 8, y: bounds.minY + bounds.height * 0.52),
                        controlPoint2: NSPoint(x: cx - 3, y: bounds.minY + bounds.height * 0.55))
        moustache.curve(to: NSPoint(x: cx + 13, y: bounds.minY + bounds.height * 0.55),
                        controlPoint1: NSPoint(x: cx + 3, y: bounds.minY + bounds.height * 0.55),
                        controlPoint2: NSPoint(x: cx + 8, y: bounds.minY + bounds.height * 0.52))
        moustache.curve(to: NSPoint(x: cx + 7, y: bounds.minY + bounds.height * 0.61),
                        controlPoint1: NSPoint(x: cx + 3, y: bounds.minY + bounds.height * 0.58),
                        controlPoint2: NSPoint(x: cx + 1, y: bounds.minY + bounds.height * 0.60))
        moustache.curve(to: NSPoint(x: cx, y: bounds.minY + bounds.height * 0.59),
                        controlPoint1: NSPoint(x: cx - 2, y: bounds.minY + bounds.height * 0.60),
                        controlPoint2: NSPoint(x: cx - 5, y: bounds.minY + bounds.height * 0.59))
        moustache.curve(to: NSPoint(x: cx - 7, y: bounds.minY + bounds.height * 0.61),
                        controlPoint1: NSPoint(x: cx - 1, y: bounds.minY + bounds.height * 0.60),
                        controlPoint2: NSPoint(x: cx - 3, y: bounds.minY + bounds.height * 0.58))
        moustache.curve(to: NSPoint(x: cx - 13, y: bounds.minY + bounds.height * 0.55),
                        controlPoint1: NSPoint(x: cx - 11, y: bounds.minY + bounds.height * 0.57),
                        controlPoint2: NSPoint(x: cx - 12, y: bounds.minY + bounds.height * 0.56))
        moustache.close()
        moustache.fill()

        // Goatee.
        let goatee = NSBezierPath()
        goatee.move(to: NSPoint(x: cx - 7, y: bounds.minY + bounds.height * 0.68))
        goatee.curve(to: NSPoint(x: cx, y: bounds.minY + bounds.height * 0.80),
                     controlPoint1: NSPoint(x: cx - 5, y: bounds.minY + bounds.height * 0.74),
                     controlPoint2: NSPoint(x: cx - 2, y: bounds.minY + bounds.height * 0.78))
        goatee.curve(to: NSPoint(x: cx + 7, y: bounds.minY + bounds.height * 0.68),
                     controlPoint1: NSPoint(x: cx + 2, y: bounds.minY + bounds.height * 0.78),
                     controlPoint2: NSPoint(x: cx + 5, y: bounds.minY + bounds.height * 0.74))
        goatee.curve(to: NSPoint(x: cx - 7, y: bounds.minY + bounds.height * 0.68),
                     controlPoint1: NSPoint(x: cx + 3, y: bounds.minY + bounds.height * 0.70),
                     controlPoint2: NSPoint(x: cx - 3, y: bounds.minY + bounds.height * 0.70))
        goatee.close()
        goatee.fill()

        if paused {
            // A dark pause badge over the mask while listening is paused.
            let badge = NSBezierPath(ovalIn: bounds.insetBy(dx: bounds.width * 0.36, dy: bounds.height * 0.36))
            NSColor(calibratedWhite: 0.02, alpha: 0.88).setFill()
            badge.fill()
            NSColor(calibratedRed: 0.0, green: 0.70, blue: 1.0, alpha: 0.95).setStroke()
            badge.lineWidth = 1.5
            badge.stroke()
            NSColor.white.setFill()
            NSBezierPath(rect: NSRect(x: cx - 5, y: bounds.minY + bounds.height * 0.44, width: 3, height: 12)).fill()
            NSBezierPath(rect: NSRect(x: cx + 2, y: bounds.minY + bounds.height * 0.44, width: 3, height: 12)).fill()
        }
    }

    func setListening(_ value: Bool) {
        listening = value
        needsDisplay = true
    }


    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        downPoint = event.locationInWindow
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard downPoint != nil, let window else { return }
        if abs(event.deltaX) + abs(event.deltaY) > 1 { dragged = true }
        var frame = window.frame
        frame.origin.x += event.deltaX
        // deltaY de NSEvent crece hacia abajo (origen de pantalla arriba-izquierda),
        // mientras que frame.origin.y crece hacia arriba: hay que restar.
        frame.origin.y -= event.deltaY
        window.setFrameOrigin(frame.origin)
    }

    override func mouseUp(with event: NSEvent) {
        if !dragged { onOpen?() }
        downPoint = nil
        dragged = false
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Abrir Harness", action: #selector(openAction), keyEquivalent: "")
        menu.addItem(withTitle: "Dictar / detener", action: #selector(dictateAction), keyEquivalent: "")
        menu.addItem(withTitle: "Leer en voz alta (Alt+R)", action: #selector(readAction), keyEquivalent: "")
        let continuous = NSMenuItem(title: "Conversación continua", action: #selector(continuousAction), keyEquivalent: "")
        continuous.state = self.continuous ? .on : .off
        continuous.target = self
        menu.addItem(continuous)
        let pause = NSMenuItem(title: "Pausar escucha", action: #selector(pauseAction), keyEquivalent: "")
        pause.state = paused ? .on : .off
        pause.target = self
        menu.addItem(pause)
        let login = NSMenuItem(title: "Abrir al iniciar sesión", action: #selector(loginAction), keyEquivalent: "")
        login.state = launchAtLogin ? .on : .off
        login.target = self
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Salir de Harness Face", action: #selector(quitAction), keyEquivalent: "q")
        for item in menu.items where item.target == nil { item.target = self }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func openAction() {
        onOpen?()
    }

    @objc private func dictateAction() {
        onOpen?()
        onDictate?()
    }

    @objc private func readAction() {
        onRead?()
    }

    @objc private func pauseAction(_ sender: NSMenuItem) {
        let next = sender.state != .on
        sender.state = next ? .on : .off
        paused = next
        onTogglePause?(next)
    }

    @objc private func continuousAction(_ sender: NSMenuItem) {
        let next = sender.state != .on
        sender.state = next ? .on : .off
        continuous = next
        onToggleContinuous?(next)
    }

    @objc private func loginAction(_ sender: NSMenuItem) {
        let next = sender.state != .on
        sender.state = next ? .on : .off
        launchAtLogin = next
        onToggleLogin?(next)
    }

    @objc private func quitAction() {
        onQuit?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var panel: NSPanel?
    private var maskView: MaskView?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeySignature = OSType(0x48414E46) // "HANF"
    private let dictation = WhisperDictation()
    private let wakeWord = WhisperStreamWake()
    private let speaker = Speaker()
    private var readHotKeyRef: EventHotKeyRef?
    private var view: MaskView?
    private var pendingDictation: DispatchWorkItem?
    private var continuous = false
    private var listeningPaused = false
    private var lastPasted = ""
    private var lastPastedAt = Date.distantPast
    private let loginKey = "launchAtLogin"
    private let continuousKey = "continuousConversation"
    private let handsFreeMigrationKey = "handsFreeApagado20261113"
    private let pausedKey = "listeningPaused"
    private let originXKey = "maskOriginX"
    private let originYKey = "maskOriginY"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createPanel()
        registerHotKey()
        if !listeningPaused && continuous { wakeWord.start() }
        configureLaunchAtLogin()
    }

    private func createPanel() {
        let size = NSSize(width: 84, height: 84)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let fallback = NSPoint(x: screen.maxX - size.width - 24, y: screen.minY + 24)
        let defaults = UserDefaults.standard
        let savedX = defaults.object(forKey: originXKey) as? Double
        let savedY = defaults.object(forKey: originYKey) as? Double
        var origin = fallback
        if let savedX, let savedY {
            let candidate = NSRect(x: savedX, y: savedY, width: size.width, height: size.height)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(candidate) }) {
                origin = NSPoint(x: savedX, y: savedY)
            }
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false

        let mask = MaskView(frame: NSRect(origin: .zero, size: size))
        mask.wantsLayer = true
        mask.onOpen = { [weak self] in self?.openHarness() }
        mask.onQuit = { NSApp.terminate(nil) }
        mask.onDictate = { [weak self] in self?.dictation.toggle() }
        mask.onToggleLogin = { [weak self] enabled in self?.setLaunchAtLogin(enabled) }
        mask.onToggleContinuous = { [weak self] enabled in self?.setContinuous(enabled) }
        mask.onTogglePause = { [weak self] paused in self?.setListeningPaused(paused) }
        mask.onRead = { [weak self] in self?.readAloud() }
        mask.launchAtLogin = UserDefaults.standard.bool(forKey: loginKey)
        // 13 nov 2026: la conversación continua quedó apagada por defecto. Con el
        // micrófono abierto siempre, whisper-stream oía la tele/YouTube y mandaba
        // frases sueltas («¡Suscríbete!») a Harness como si las dijera Frank.
        continuous = (UserDefaults.standard.object(forKey: continuousKey) as? Bool) ?? false
        if continuous, !UserDefaults.standard.bool(forKey: handsFreeMigrationKey) {
            continuous = false
            UserDefaults.standard.set(false, forKey: continuousKey)
        }
        UserDefaults.standard.set(true, forKey: handsFreeMigrationKey)
        mask.continuous = continuous
        listeningPaused = UserDefaults.standard.bool(forKey: pausedKey)
        mask.paused = listeningPaused
        dictation.onStateChange = { [weak self] listening in
            self?.maskView?.setListening(listening)
        }
        dictation.onFinal = { [weak self] text in
            self?.pasteIntoHarness(text)
        }
        dictation.onFinished = { [weak self] in
            guard let self, !self.listeningPaused else { return }
            if self.continuous {
                self.scheduleNextDictation()
            }
            // Sin conversación continua el micrófono queda cerrado: solo Alt+V.
        }
        wakeWord.onWake = { [weak self] in
            guard let self, !self.listeningPaused else { return }
            self.openHarness()
            self.wakeWord.stop()
            self.dictation.start()
        }
        panel.contentView = mask

        panel.delegate = self
        panel.orderFrontRegardless()
        self.panel = panel
        self.maskView = mask
        self.view = mask
    }

    private func registerHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Alt+V dicta; Alt+R lee en voz alta la selección o el portapapeles.
        let dictateID = EventHotKeyID(signature: hotKeySignature, id: 1)
        let dictateStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(optionKey),
            dictateID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if dictateStatus != noErr {
            NSLog("Harness Face: no pude registrar Alt+V (%d)", dictateStatus)
        }

        let readID = EventHotKeyID(signature: hotKeySignature, id: 2)
        let readStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_R),
            UInt32(optionKey),
            readID,
            GetApplicationEventTarget(),
            0,
            &readHotKeyRef
        )
        if readStatus != noErr {
            NSLog("Harness Face: no pude registrar Alt+R (%d)", readStatus)
        }

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                let result = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if result == noErr, hotKeyID.id == 2 {
                    delegate.readAloud()
                } else {
                    delegate.hotKeyPressed()
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
    }

    @objc func readAloud() {
        if speaker.isSpeaking {
            speaker.stop()
            return
        }
        speaker.readSelection()
    }

    @objc func openHarness() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: harnessBundleID)
        if let app = running.first {
            app.unhide()
            app.activate(options: [.activateAllWindows])
            restoreWindows(of: app)
            // LaunchServices "open" es lo mismo que el clic en el Dock: restaura la
            // ventana minimizada. Es el fallback cuando no hay permiso de Accesibilidad.
            let url = URL(fileURLWithPath: harnessAppPath)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            config.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
            return
        }
        let url = URL(fileURLWithPath: harnessAppPath)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error {
                NSLog("Harness Face: no pude abrir Harness: %@", error.localizedDescription)
            }
        }
    }

    /// Desminiaturiza las ventanas de Harness. Sin permiso de Accesibilidad las
    /// llamadas AX fallan en silencio y queda el fallback de LaunchServices.
    private func restoreWindows(of app: NSRunningApplication) {
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement], !windows.isEmpty
        else { return }
        for window in windows {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        if let first = windows.first {
            AXUIElementPerformAction(first, kAXRaiseAction as CFString)
        }
    }

    @objc private func hotKeyPressed() {
        openHarness()
        wakeWord.stop()
        // Leave enough time for Harness to take focus before dictating into it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self else { return }
            self.dictation.toggle()
        }
    }

    private func pasteIntoHarness(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        // El micrófono puede devolver la misma frase dos veces (silencio + audio
        // de fondo). Repetirla en el chat no aporta nada: se descarta.
        if clean == lastPasted, Date().timeIntervalSince(lastPastedAt) < 90 {
            NSLog("Harness Face: dictado repetido ignorado")
            return
        }
        lastPasted = clean
        lastPastedAt = Date()
        openHarness()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            // Command-V, without Return: the text stays in the chat for review.
            guard let source = CGEventSource(stateID: .combinedSessionState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            else { return }
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)

            if self.continuous {
                // Send the dictation, then listen again after the reply window.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    guard let source = CGEventSource(stateID: .combinedSessionState),
                          let down = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true),
                          let up = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
                    else { return }
                    down.post(tap: .cghidEventTap)
                    up.post(tap: .cghidEventTap)
                }
            }
        }
    }

    private func scheduleNextDictation() {
        pendingDictation?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.continuous, !self.dictation.isRecording else { return }
            self.openHarness()
            self.dictation.start()
        }
        pendingDictation = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    private func setListeningPaused(_ paused: Bool) {
        listeningPaused = paused
        UserDefaults.standard.set(paused, forKey: pausedKey)
        maskView?.paused = paused
        if paused {
            pendingDictation?.cancel()
            pendingDictation = nil
            wakeWord.stop()
            if dictation.isRecording { dictation.stop() }
        } else if continuous {
            wakeWord.resume()
        }
    }

    private func setContinuous(_ enabled: Bool) {
        continuous = enabled
        UserDefaults.standard.set(enabled, forKey: continuousKey)
        maskView?.continuous = enabled
        if enabled {
            wakeWord.stop()
            scheduleNextDictation()
        } else {
            pendingDictation?.cancel()
            pendingDictation = nil
            wakeWord.stop()
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }
        let defaults = UserDefaults.standard
        defaults.set(panel.frame.origin.x, forKey: originXKey)
        defaults.set(panel.frame.origin.y, forKey: originYKey)
    }

    private func configureLaunchAtLogin() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: loginKey) == nil { defaults.set(true, forKey: loginKey) }
        setLaunchAtLogin(defaults.bool(forKey: loginKey))
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: loginKey)
        maskView?.launchAtLogin = enabled
        guard #available(macOS 13.0, *) else { return }
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled { try service.register() }
            } else if service.status == .enabled {
                try service.unregister()
            }
        } catch {
            NSLog("Harness Face: no pude cambiar el inicio de sesión: %@", error.localizedDescription)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let readHotKeyRef { UnregisterEventHotKey(readHotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
