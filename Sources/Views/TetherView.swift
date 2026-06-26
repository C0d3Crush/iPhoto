import SwiftUI
import AVFoundation

struct TetherView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @ObservedObject private var tether = TetherManager.shared
    @Binding var isPresented: Bool

    @State private var selectedDeviceID: String? = nil

    private var selectedDevice: AVCaptureDevice? {
        tether.availableDevices.first { $0.uniqueID == selectedDeviceID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if !tether.permissionGranted {
                permissionView
            } else {
                VStack(spacing: 0) {
                    deviceBar
                    Divider()
                    previewArea
                    Divider()
                    controlBar
                }
            }
        }
        .frame(minWidth: 720, minHeight: 540)
        .onAppear {
            tether.refreshDevices()
            autoSelectDevice()
        }
        .onDisappear {
            tether.stopSession()
        }
        .onChange(of: tether.availableDevices) { _ in
            if selectedDeviceID == nil { autoSelectDevice() }
        }
        .onChange(of: selectedDeviceID) { id in
            if let dev = tether.availableDevices.first(where: { $0.uniqueID == id }) {
                tether.startSession(device: dev) { url in
                    viewModel.importFiles([url])
                }
            } else {
                tether.stopSession()
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Image(systemName: "camera.fill")
                .foregroundColor(.accentColor)
            Text("Live-Vorschau")
                .font(.headline)
            Spacer()
            if tether.isSessionRunning {
                HStack(spacing: 5) {
                    Circle()
                        .fill(tether.isRecording ? Color.red : Color.green)
                        .frame(width: 7, height: 7)
                    Text(tether.isRecording ? "REC" : "LIVE")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(tether.isRecording ? .red : .green)
                }
            }
            Spacer()
            Button("Schließen") {
                tether.stopSession()
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var deviceBar: some View {
        HStack(spacing: 10) {
            Text("Kamera:")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("", selection: $selectedDeviceID) {
                Text("— Keine —").tag(nil as String?)
                ForEach(tether.availableDevices, id: \.uniqueID) { dev in
                    Text(dev.localizedName).tag(dev.uniqueID as String?)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 280)

            Button(action: {
                tether.refreshDevices()
                if selectedDeviceID == nil { autoSelectDevice() }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .help("Geräte aktualisieren")

            Spacer()

            if tether.availableDevices.isEmpty {
                Label("Kein Gerät gefunden", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private var previewArea: some View {
        if tether.isSessionRunning {
            CameraPreviewView(session: tether.session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ZStack {
                Color.black
                VStack(spacing: 14) {
                    Image(systemName: selectedDeviceID == nil ? "camera.slash" : "camera")
                        .font(.system(size: 52))
                        .foregroundColor(.gray)
                    Text(selectedDeviceID == nil
                         ? "Kamera oben auswählen"
                         : "Verbinde…")
                        .font(.callout)
                        .foregroundColor(.gray)
                    if selectedDeviceID == nil {
                        VStack(spacing: 4) {
                            Text("Fujifilm X-T4: Kamera-Menü → PC-Verbindung → USB-Webcam")
                                .font(.caption)
                                .foregroundColor(Color(NSColor.darkGray))
                            Text("iPhone: WLAN + Bluetooth einschalten, Mac entsperren — erscheint automatisch")
                                .font(.caption)
                                .foregroundColor(Color(NSColor.darkGray))
                        }
                        .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            if !tether.statusMessage.isEmpty {
                Text(tether.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()

            // Video button
            Button(action: {
                if tether.isRecording { tether.stopRecording() }
                else { tether.startRecording() }
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(tether.isRecording ? Color.red : Color(NSColor.tertiaryLabelColor))
                        .frame(width: 8, height: 8)
                    Text(tether.isRecording ? "Stopp" : "Video")
                        .font(.callout)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .disabled(!tether.isSessionRunning)
            .help("Videoaufnahme starten / stoppen")

            // Photo button
            Button(action: { tether.capturePhoto() }) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.shutter.button.fill")
                    Text("Auslösen")
                        .font(.callout.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!tether.isSessionRunning || tether.isRecording)
            .buttonStyle(PlainButtonStyle())
            .help("Foto aufnehmen  (Leertaste)")
            .keyboardShortcut(" ", modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("Kamerazugriff erforderlich")
                .font(.headline)
            Text("iPhoto benötigt Zugriff auf die Kamera.")
                .foregroundColor(.secondary)
            Button("Systemeinstellungen öffnen") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func autoSelectDevice() {
        // Prefer Fujifilm, then iPhone, then first available
        let name: (AVCaptureDevice) -> String = { $0.localizedName.lowercased() }
        let preferred = tether.availableDevices.first { name($0).contains("fuji") || name($0).contains("x-t") }
            ?? tether.availableDevices.first { name($0).contains("iphone") || name($0).contains("continuity") }
            ?? tether.availableDevices.first
        selectedDeviceID = preferred?.uniqueID
    }
}
