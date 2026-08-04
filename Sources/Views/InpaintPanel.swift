import SwiftUI

struct InpaintPanel: View {
    @EnvironmentObject var viewModel: ImageViewModel

    @State private var cmtDir:   String = ""
    @State private var ckptPath: String = ""
    @State private var py3Path:  String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.currentImage == nil {
                HStack {
                    Spacer()
                    Text("Kein Bild geladen")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    setupSection
                    Divider()
                    brushSection
                    Divider()
                    actionSection
                    statusSection
                }
                .padding(10)
            }
        }
        .onAppear { loadSettings() }
    }

    // MARK: - Setup

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            label("Python 3")
            TextField("/usr/bin/python3", text: $py3Path, onCommit: saveSettings)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(RoundedBorderTextFieldStyle())

            label("CMT-Verzeichnis")
            TextField("~/.iPhoto/CMT", text: $cmtDir, onCommit: saveSettings)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(RoundedBorderTextFieldStyle())

            label("Checkpoint (.pth)")
            TextField("~/.iPhoto/CMT/checkpoints/places2.pth", text: $ckptPath, onCommit: saveSettings)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    // MARK: - Brush

    private var brushSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                label("Pinselgröße")
                Spacer()
                Text("\(Int(viewModel.inpaint.brushRadius)) px")
                    .font(.caption2).foregroundColor(.secondary)
            }
            Slider(value: $viewModel.inpaint.brushRadius, in: 5...200, step: 1)
        }
    }

    // MARK: - Actions

    private var actionSection: some View {
        VStack(spacing: 6) {
            // Mask-drawing toggle
            Button(action: { viewModel.inpaint.isMaskingMode.toggle() }) {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.inpaint.isMaskingMode
                          ? "circle.fill" : "pencil.tip.crop.circle")
                        .foregroundColor(viewModel.inpaint.isMaskingMode ? .red : .accentColor)
                    Text(viewModel.inpaint.isMaskingMode
                         ? "Zeichnen aktiv — beenden"
                         : "Maske zeichnen")
                        .foregroundColor(viewModel.inpaint.isMaskingMode ? .red : .primary)
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(viewModel.inpaint.isMaskingMode
                                ? Color.red.opacity(0.6) : Color(NSColor.separatorColor),
                                lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.inpaint.isRunning)

            HStack(spacing: 6) {
                inlineButton(
                    label: "Maske löschen",
                    icon: "trash",
                    disabled: viewModel.inpaint.isRunning
                ) {
                    viewModel.inpaint.pendingMaskBitmap = nil
                    viewModel.inpaint.statusMessage     = nil
                    viewModel.inpaint.errorMessage      = nil
                    NotificationCenter.default.post(name: .inpaintClearMask, object: nil)
                }

                if viewModel.inpaint.resultImage != nil {
                    inlineButton(
                        label: "Zurücksetzen",
                        icon: "arrow.uturn.backward",
                        disabled: viewModel.inpaint.isRunning
                    ) {
                        viewModel.clearInpaint()
                    }
                }
            }

            // Primary run button
            Button(action: { saveSettings(); viewModel.startInpaint() }) {
                HStack(spacing: 5) {
                    if viewModel.inpaint.isRunning {
                        ProgressView().scaleEffect(0.65)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(viewModel.inpaint.isRunning ? "Läuft…" : "Inpaint ausführen")
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.inpaint.isRunning)
            .opacity(viewModel.inpaint.isRunning ? 0.5 : 1)
        }
    }

    private func inlineButton(
        label: String, icon: String, disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(NSColor.controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(NSColor.separatorColor), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        if let msg = viewModel.inpaint.statusMessage {
            HStack(spacing: 4) {
                if viewModel.inpaint.isRunning { ProgressView().scaleEffect(0.6) }
                Text(msg).font(.caption2).foregroundColor(.secondary).lineLimit(2)
            }
        }
        if let err = viewModel.inpaint.errorMessage {
            Text(err).font(.caption2).foregroundColor(.red).lineLimit(4)
        }
        if viewModel.inpaint.resultImage != nil, !viewModel.inpaint.isRunning {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text("Ergebnis bereit — wird angezeigt")
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func label(_ text: String) -> some View {
        Text(text).font(.caption2).foregroundColor(.secondary)
    }

    private func loadSettings() {
        cmtDir   = viewModel.inpaint.cmtDirectory
        ckptPath = viewModel.inpaint.checkpointPath
        py3Path  = viewModel.inpaint.python3Path
    }

    private func saveSettings() {
        viewModel.inpaint.cmtDirectory   = cmtDir
        viewModel.inpaint.checkpointPath = ckptPath
        viewModel.inpaint.python3Path    = py3Path
    }
}
