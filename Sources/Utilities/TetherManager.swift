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
        // "AVCaptureDeviceTypeContinuityCamera" is the raw value for .continuityCamera (macOS 13+).
        // We inject it via raw string so this file compiles against older SDKs too.
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
            self.configureSession(device: device)
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
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

    private func configureSession(device: AVCaptureDevice) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let old = currentInput { session.removeInput(old) }

        if session.outputs.isEmpty {
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
            }
        } catch {
            DispatchQueue.main.async { self.statusMessage = "Kamerafehler: \(error.localizedDescription)" }
        }
    }

    // MARK: - Capture

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func startRecording() {
        guard !isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tether_\(Int(Date().timeIntervalSince1970)).mov")
        movieOutput.startRecording(to: url, recordingDelegate: self)
        DispatchQueue.main.async { self.isRecording = true }
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
        do { try data.write(to: url); return url } catch { return nil }
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
            if error == nil {
                self.statusMessage = "Video gespeichert: \(outputFileURL.lastPathComponent)"
                self.onCapture?(outputFileURL)
            } else {
                self.statusMessage = "Videofehler: \(error!.localizedDescription)"
            }
        }
    }
}
