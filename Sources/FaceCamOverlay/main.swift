import AppKit
@preconcurrency import AVFoundation

private final class CameraPreviewView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.width / 2
        previewLayer.frame = bounds
    }
}

private final class FaceCamPanel: NSPanel {
    private var dragOrigin: NSPoint?
    private var windowOrigin: NSPoint?

    init(size: CGFloat) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        dragOrigin = NSEvent.mouseLocation
        windowOrigin = frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragOrigin, let windowOrigin else { return }
        let current = NSEvent.mouseLocation
        setFrameOrigin(NSPoint(
            x: windowOrigin.x + current.x - dragOrigin.x,
            y: windowOrigin.y + current.y - dragOrigin.y
        ))
    }

    override func mouseUp(with event: NSEvent) {
        dragOrigin = nil
        windowOrigin = nil
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let session = AVCaptureSession()
    private let previewView = CameraPreviewView(frame: .zero)
    private var panel: FaceCamPanel!
    private var statusItem: NSStatusItem!
    private var currentDeviceID: String?
    private var isMirrored = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMenuBar()
        requestCameraAccess()
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.stopRunning()
    }

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.startCamera() }
                    else { self?.showPermissionAlert() }
                }
            }
        default:
            showPermissionAlert()
        }
    }

    private func startCamera(deviceID: String? = nil) {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        let device = deviceID.flatMap { id in discovery.devices.first { $0.uniqueID == id } }
            ?? discovery.devices.first

        guard let device else {
            showAlert(title: "No camera found", message: "Connect a camera and relaunch FaceCam Overlay.")
            return
        }

        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        session.sessionPreset = .high

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
            session.addInput(input)
            currentDeviceID = device.uniqueID
        } catch {
            session.commitConfiguration()
            showAlert(title: "Camera unavailable", message: error.localizedDescription)
            return
        }

        session.commitConfiguration()
        previewView.previewLayer.session = session
        applyMirroring()

        if panel == nil { showOverlay(size: 240) }
        DispatchQueue.global(qos: .userInitiated).async { [session] in session.startRunning() }
        buildMenuBar()
    }

    private func showOverlay(size: CGFloat) {
        let oldCenter = panel?.frame.center
        panel?.orderOut(nil)

        panel = FaceCamPanel(size: size)
        previewView.frame = NSRect(x: 0, y: 0, width: size, height: size)
        panel.contentView = previewView

        if let oldCenter {
            panel.setFrameOrigin(NSPoint(x: oldCenter.x - size / 2, y: oldCenter.y - size / 2))
        } else if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size - 28, y: visible.minY + 28))
        }
        panel.orderFrontRegardless()
    }

    private func buildMenuBar() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItem.button?.image = NSImage(systemSymbolName: "video.circle.fill", accessibilityDescription: "FaceCam Overlay")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Small", action: #selector(setSmall), keyEquivalent: "1")
        menu.addItem(withTitle: "Medium", action: #selector(setMedium), keyEquivalent: "2")
        menu.addItem(withTitle: "Large", action: #selector(setLarge), keyEquivalent: "3")
        menu.addItem(.separator())

        let mirror = NSMenuItem(title: "Mirror Camera", action: #selector(toggleMirror), keyEquivalent: "m")
        mirror.state = isMirrored ? .on : .off
        menu.addItem(mirror)

        menu.addItem(withTitle: "Retry Camera Access", action: #selector(retryCameraAccess), keyEquivalent: "r")

        let cameras = NSMenuItem(title: "Camera", action: nil, keyEquivalent: "")
        cameras.submenu = cameraMenu()
        menu.addItem(cameras)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit FaceCam Overlay", action: #selector(quit), keyEquivalent: "q")

        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
    }

    private func cameraMenu() -> NSMenu {
        let submenu = NSMenu()
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        ).devices

        for device in devices {
            let item = NSMenuItem(title: device.localizedName, action: #selector(selectCamera(_:)), keyEquivalent: "")
            item.representedObject = device.uniqueID
            item.state = device.uniqueID == currentDeviceID ? .on : .off
            item.target = self
            submenu.addItem(item)
        }
        if devices.isEmpty { submenu.addItem(withTitle: "No cameras found", action: nil, keyEquivalent: "") }
        return submenu
    }

    private func applyMirroring() {
        guard let connection = previewView.previewLayer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isMirrored
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Camera access is required"
        alert.informativeText = "Enable FaceCam Overlay in System Settings → Privacy & Security → Camera, then reopen the app."
        alert.addButton(withTitle: "Open Camera Settings")
        alert.addButton(withTitle: "Keep Running")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
        buildMenuBar()
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    @objc private func setSmall() { showOverlay(size: 160) }
    @objc private func setMedium() { showOverlay(size: 240) }
    @objc private func setLarge() { showOverlay(size: 340) }
    @objc private func toggleMirror() { isMirrored.toggle(); applyMirroring(); buildMenuBar() }
    @objc private func retryCameraAccess() { requestCameraAccess() }
    @objc private func selectCamera(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        startCamera(deviceID: id)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

private enum CameraError: LocalizedError {
    case cannotAddInput
    var errorDescription: String? { "The selected camera could not be added to the capture session." }
}

private extension NSRect {
    var center: NSPoint { NSPoint(x: midX, y: midY) }
}

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
