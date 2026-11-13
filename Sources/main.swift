import AppKit
import Carbon

private let harnessBundleID = "com.deepseek.dsh"
private let harnessAppPath = "/Applications/DeepSeek Harness.app"

final class MaskView: NSView {
    var onOpen: (() -> Void)?
    var onQuit: (() -> Void)?

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)

        let bounds = self.bounds.insetBy(dx: 4, dy: 4)

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
    }

    override func mouseDown(with event: NSEvent) {
        onOpen?()
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Abrir Harness", action: #selector(openAction), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Salir de Harness Face", action: #selector(quitAction), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func openAction() {
        onOpen?()
    }

    @objc private func quitAction() {
        onQuit?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?
    private var maskView: MaskView?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeySignature = OSType(0x48414E46) // "HANF"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createPanel()
        registerHotKey()
    }

    private func createPanel() {
        let size = NSSize(width: 84, height: 84)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(x: screen.maxX - size.width - 24, y: screen.minY + 24)

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
        panel.contentView = mask

        panel.orderFrontRegardless()
        self.panel = panel
        self.maskView = mask
    }

    private func registerHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            NSLog("Harness Face: no pude registrar Alt+V (%d)", status)
            return
        }

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                delegate.openHarness()
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
    }

    @objc func openHarness() {
        NSApp.activate(ignoringOtherApps: true)
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: harnessBundleID)
        if let app = running.first {
            app.activate(options: [.activateIgnoringOtherApps])
            return
        }
        let url = URL(fileURLWithPath: harnessAppPath)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                NSLog("Harness Face: no pude abrir Harness: %@", error.localizedDescription)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
