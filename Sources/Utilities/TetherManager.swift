import AVFoundation
import Foundation

final class TetherManager: NSObject, ObservableObject {
    static let shared = TetherManager()

    @Published var permissionGranted: Bool = false
    @Published var isSessionRunning: Bool = false
    @Published var isRecording: Bool = false
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var activeDevice: AVCaptureDevice? = nil
    @Published var statusMessage: String = ""

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var currentInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "tether.session", qos: .userInitiated)
    private var onCapture: ((URL) -> Void)?

    private override init() {
        super.init()
        session.sessionPreset = .photo
        setupNotificationObservers()
        checkPermission()
    }

    // MARK: - Permissions

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.permissionGranted = true }
            refreshDevices()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted { self?.refreshDevices() }
                }
            }
        default:
            DispatchQueue.main.async { self.permissionGranted = false }
        }
    }

    // MARK: - Device Discovery

    func refreshDevices() {
        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 13.0, *) {
            types.append(AVCaptureDevice.DeviceType(rawValue: "AVCaptureDeviceTypeContinuityCamera"))
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types, mediaType: .video, position: .unspecified)
        let devices = discovery.devices
        DispatchQueue.main.async { self.availableDevices = devices }
    }

    // MARK: - Session

    func startSession(device: AVCaptureDevice, onCapture: @escaping (URL) -> Void) {
        self.onCapture = onCapture
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let ok = self.configureSession(device: device)
            guard ok else { return }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
                self.activeDevice = device
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async {
                self.isSessionRunning = false
                self.activeDevice = nil
                self.isRecording = false
            }
        }
    }

    // Returns false if no valid input could be added — caller must not start the session.
    @discardableResult
    private func configureSession(device: AVCaptureDevice) -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let old = currentInput { session.removeInput(old) }
        currentInput = nil

        if session.outputs.isEmpty {
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                DispatchQueue.main.async { self.statusMessage = "Kamera kann nicht hinzugefügt werden" }
                return false
            }
            session.addInput(input)
            currentInput = input
            return true
        } catch {
            DispatchQueue.main.async {
                self.statusMessage = "Kamerafehler: \(error.localizedDescription)"
                self.isSessionRunning = false
            }
            return false
        }
    }

    // MARK: - Notifications (runtime errors, interruptions, disconnect)

    private func setupNotificationObservers() {
        let nc = NotificationCenter.default

        nc.addObserver(self, selector: #selector(sessionRuntimeError(_:)),
                       name: .AVCaptureSessionRuntimeError, object: session)
        nc.addObserver(self, selector: #selector(sessionWasInterrupted(_:)),
                       name: .AVCaptureSessionWasInterrupted, object: session)
        nc.addObserver(self, selector: #selector(sessionInterruptionEnded(_:)),
                       name: .AVCaptureSessionInterruptionEnded, object: session)
        nc.addObserver(self, selector: #selector(sessionDidStopRunning(_:)),
                       name: .AVCaptureSessionDidStopRunning, object: session)
        nc.addObserver(self, selector: #selector(deviceWasDisconnected(_:)),
                       name: NSNotification.Name.AVCaptureDeviceWasDisconnected, object: nil)
    }

    @objc private func sessionRuntimeError(_ notification: Notification) {
        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error
        Log.error("TetherManager: session runtime error: \(error?.localizedDescription ?? "unknown")")
        DispatchQueue.main.async {
            self.isSessionRunning = false
            self.isRecording = false
            self.statusMessage = "Kamera-Fehler: \(error?.localizedDescription ?? "unbekannt")"
        }
        // Attempt reconnect once for media-services-reset errors.
        // AVError.Code 107 = AVErrorMediaServicesWereReset (not available as Swift enum on macOS 11)
        if let err = error as? AVError, err.code.rawValue == 107 {
            sessionQueue.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self = self, let device = self.activeDevice else { return }
                let ok = self.configureSession(device: device)
                guard ok else { return }
                self.session.startRunning()
                DispatchQueue.main.async { self.isSessionRunning = self.session.isRunning }
            }
        }
    }

    @objc private func sessionWasInterrupted(_ notification: Notification) {
        Log.info("TetherManager: session interrupted")
        DispatchQueue.main.async {
            self.isSessionRunning = false
            self.isRecording = false
            self.statusMessage = "Kamera unterbrochen"
        }
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        Log.info("TetherManager: session interruption ended")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.isSessionRunning = self.session.isRunning }
        }
    }

    @objc private func sessionDidStopRunning(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isSessionRunning = false
            self.isRecording = false
        }
    }

    @objc private func deviceWasDisconnected(_ notification: Notification) {
        guard let disconnected = notification.object as? AVCaptureDevice,
              disconnected == activeDevice else { return }
        Log.info("TetherManager: active device disconnected — stopping session")
        DispatchQueue.main.async {
            self.isSessionRunning = false
            self.isRecording = false
            self.activeDevice = nil
            self.statusMessage = "Kamera getrennt"
        }
        refreshDevices()
    }

    // MARK: - Capture

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  self.session.isRunning,
                  let conn = self.photoOutput.connection(with: .video),
                  conn.isActive, conn.isEnabled else {
                DispatchQueue.main.async { self?.statusMessage = "Kamera nicht bereit" }
                return
            }
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  !self.movieOutput.isRecording,
                  self.session.isRunning,
                  let conn = self.movieOutput.connection(with: .video),
                  conn.isActive, conn.isEnabled else {
                DispatchQueue.main.async { self?.statusMessage = "Kamera nicht bereit" }
                return
            }
            DispatchQueue.main.async { self.isRecording = true }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
            let name = "TETHER_\(formatter.string(from: Date())).mov"
            let url = TetherManager.tetherDir.appendingPathComponent(name)
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        movieOutput.stopRecording()
    }

    // MARK: - Storage

    private static let tetherDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/iPhoto Tethered")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func savePhoto(_ data: Data) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let name = "TETHER_\(formatter.string(from: Date())).jpg"
        let url = TetherManager.tetherDir.appendingPathComponent(name)
        do {
            try data.write(to: url)
            Log.info("EVENT tether-capture filename=\(name) bytes=\(data.count)")
            return url
        } catch {
            Log.error("Tether-Foto speichern fehlgeschlagen '\(url.lastPathComponent)': \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Photo delegate

extension TetherManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(),
              let url = savePhoto(data) else {
            DispatchQueue.main.async { self.statusMessage = "Aufnahme fehlgeschlagen" }
            return
        }
        DispatchQueue.main.async {
            self.statusMessage = "Gespeichert: \(url.lastPathComponent)"
            self.onCapture?(url)
        }
    }
}

// MARK: - Movie delegate

extension TetherManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            if let error = error {
                self.statusMessage = "Videofehler: \(error.localizedDescription)"
            } else {
                // Videos (.mov) are not in ImageDocument.supportedExtensions — don't pass to
                // onCapture. Report save location in status so the user knows where to find it.
                self.statusMessage = "Video gespeichert: \(outputFileURL.lastPathComponent)"
            }
        }
    }
}
