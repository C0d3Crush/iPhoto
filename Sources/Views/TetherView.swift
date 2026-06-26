import SwiftUI
import AVFoundation

// Inline live-preview shown inside DetailView when tetherMode == true
struct TetherInlineView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @ObservedObject private var tether = TetherManager.shared

    @State private var selectedDeviceID: String? = nil
    @State private var showDevicePicker = false

    private var selectedDevice: AVCaptureDevice? {
        tether.availableDevices.first { $0.uniqueID == selectedDeviceID }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if tether.isSessionRunning {
                CameraPreviewView(session: tether.session)
                    .ignoresSafeArea()
            } else {
                placeholderView
            }

            // Bottom control bar
            VStack {
                Spacer()
                controlBar
            }
        }
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

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 52))
                .foregroundColor(.gray)
            if !tether.permissionGranted {
                Text("Kamerazugriff erforderlich")
                    .foregroundColor(.gray)
                Button("Systemeinstellungen öffnen") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .foregroundColor(.accentColor)
            } else if selectedDeviceID == nil {
                Text("Kamera auswählen")
                    .foregroundColor(.gray)
                hintText
            } else {
                Text("Verbinde…")
                    .foregroundColor(.gray)
            }
        }
    }

    private var hintText: some View {
        VStack(spacing: 3) {
            Text("Fujifilm X-T4: Kamera-Menü → PC-Verbindung → USB-Webcam")
                .font(.caption)
                .foregroundColor(Color(NSColor.darkGray))
            Text("iPhone: WLAN + Bluetooth an, Mac entsperrt → erscheint automatisch (macOS 13+)")
                .font(.caption)
                .foregroundColor(Color(NSColor.darkGray))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 16) {
            // Device picker
            devicePickerButton

            Spacer()

            // Status
            if !tether.statusMessage.isEmpty {
                Text(tether.statusMessage)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Record
            Button(action: {
                if tether.isRecording { tether.stopRecording() }
                else { tether.startRecording() }
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(tether.isRecording ? Color.red : Color.white.opacity(0.7))
                        .frame(width: 8, height: 8)
                    Text(tether.isRecording ? "Stopp" : "Video")
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.15))
                .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!tether.isSessionRunning)

            // Shutter
            shutterButton

            // Close
            Button(action: {
                tether.stopSession()
                viewModel.tetherMode = false
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.8))
                    .padding(8)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .help("Kamera-Modus beenden")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.6)]),
                startPoint: .top, endPoint: .bottom)
        )
    }

    private var shutterButton: some View {
        Button(action: { tether.capturePhoto() }) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 56, height: 56)
                Circle()
                    .fill(Color.white)
                    .frame(width: 46, height: 46)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!tether.isSessionRunning || tether.isRecording)
        .help("Foto aufnehmen (Leertaste)")
        .keyboardShortcut(" ", modifiers: [])
    }

    private var devicePickerButton: some View {
        Menu {
            if tether.availableDevices.isEmpty {
                Text("Kein Gerät gefunden").foregroundColor(.secondary)
            }
            ForEach(tether.availableDevices, id: \.uniqueID) { dev in
                Button(action: { selectedDeviceID = dev.uniqueID }) {
                    HStack {
                        Text(dev.localizedName)
                        if dev.uniqueID == selectedDeviceID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button("Aktualisieren") {
                tether.refreshDevices()
                if selectedDeviceID == nil { autoSelectDevice() }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "camera")
                    .foregroundColor(.white)
                Text(selectedDevice?.localizedName ?? "Kamera wählen")
                    .foregroundColor(.white)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.15))
            .cornerRadius(20)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .fixedSize()
    }

    // MARK: - Helpers

    private func autoSelectDevice() {
        let n: (AVCaptureDevice) -> String = { $0.localizedName.lowercased() }
        let preferred = tether.availableDevices.first { n($0).contains("fuji") || n($0).contains("x-t") }
            ?? tether.availableDevices.first { n($0).contains("iphone") || n($0).contains("continuity") }
            ?? tether.availableDevices.first
        selectedDeviceID = preferred?.uniqueID
    }
}
