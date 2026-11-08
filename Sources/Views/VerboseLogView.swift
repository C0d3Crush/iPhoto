import SwiftUI

// MARK: - Verbose Log + Console (Für Geeks)

private enum GeekTab { case log, console }

struct VerboseLogView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @AppStorage("settings.geekMode") private var geekMode = false
    @State private var activeTab: GeekTab = .log
    @State private var panelHeight: CGFloat = 160
    @State private var dragStartHeight: CGFloat = 160
    private let minHeight: CGFloat = 60
    private let maxHeight: CGFloat = 400

    var body: some View {
        if geekMode {
            VStack(spacing: 0) {
                // Resize handle — drag up/down to change panel height
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(NSColor.tertiaryLabelColor))
                        .frame(width: 28, height: 3)
                    Spacer()
                }
                .frame(height: 10)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(Divider(), alignment: .top)
                .gesture(
                    DragGesture()
                        .onChanged { val in
                            let newH = dragStartHeight - val.translation.height
                            panelHeight = max(minHeight, min(maxHeight, newH))
                        }
                        .onEnded { _ in dragStartHeight = panelHeight }
                )
                .onHover { inside in
                    if inside { NSCursor.resizeUpDown.push() }
                    else      { NSCursor.pop() }
                }

                // Tab bar
                HStack(spacing: 0) {
                    geekTabButton(tab: .log,     icon: "ant",      label: "Log")
                    geekTabButton(tab: .console, icon: "terminal", label: "Konsole")
                    Spacer()
                }
                .background(Color(NSColor.windowBackgroundColor))

                // Content
                Group {
                    if activeTab == .log     { LogPanelView() }
                    else                     { ConsolePanelView() }
                }
                .frame(height: panelHeight)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func geekTabButton(tab: GeekTab, icon: String, label: String) -> some View {
        Button(action: { activeTab = tab }) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(activeTab == tab ? .accentColor : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Log panel

private struct LogPanelView: View {
    @State private var lines: [String] = []
    @State private var lastKnownSize: UInt64 = 0
    private let ticker = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(lineColor(line))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 1)
                            .id(idx)
                    }
                }
                .padding(.vertical, 4)
            }
            .background(Color(NSColor.textBackgroundColor))
            .onChange(of: lines) { newLines in
                withAnimation { proxy.scrollTo(newLines.count - 1, anchor: .bottom) }
            }
        }
        .onReceive(ticker) { _ in reload() }
        .onAppear { reload() }
    }

    private func lineColor(_ line: String) -> Color {
        if line.contains("[ERROR]") { return Color(NSColor.systemRed) }
        if line.contains("[WARN ]") { return Color(NSColor.systemOrange) }
        if line.contains("PERF")   { return Color(NSColor.systemGreen) }
        return Color(NSColor.secondaryLabelColor)
    }

    private func reload() {
        let url = Log.shared.fileURL
        DispatchQueue.global(qos: .utility).async {
            guard let handle = try? FileHandle(forReadingFrom: url) else { return }
            let size = handle.seekToEndOfFile()
            // Skip read if file hasn't grown since last tick
            guard size != lastKnownSize else { handle.closeFile(); return }
            let readBytes: UInt64 = min(size, 8192)
            handle.seek(toFileOffset: size - readBytes)
            let data = handle.readDataToEndOfFile()
            handle.closeFile()
            // Use lossless decoding (replaces invalid bytes with U+FFFD instead of returning nil),
            // then drop the first line which may be a truncated multi-byte character.
            let parsed = String(decoding: data, as: UTF8.self)
                .components(separatedBy: "\n")
                .dropFirst()
                .filter { !$0.isEmpty && !$0.contains(Log.sessionMarker) }
                .suffix(50).map { String($0) }
            DispatchQueue.main.async {
                self.lastKnownSize = size
                self.lines = parsed
            }
        }
    }
}

// MARK: - Console panel

private struct ConsoleLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let kind: Kind
    enum Kind: Equatable { case command, output, error }
}

private struct ConsolePanelView: View {
    @State private var input: String = ""
    @State private var output: [ConsoleLine] = [
        ConsoleLine(text: "iphoto-cli Konsole — Befehle ohne 'iphoto-cli' eingeben", kind: .output)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(output) { line in
                            Text(line.text)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(lineColor(line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .id(line.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: output) { lines in
                    if let last = lines.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()
            HStack(spacing: 6) {
                Text(">").font(.system(size: 10, design: .monospaced)).foregroundColor(.accentColor)
                TextField("Befehl…", text: $input, onCommit: runInput)
                    .font(.system(size: 10, design: .monospaced))
                    .textFieldStyle(PlainTextFieldStyle())
                Button(action: runInput) {
                    Image(systemName: "return").font(.system(size: 9))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    private func lineColor(_ line: ConsoleLine) -> Color {
        switch line.kind {
        case .command: return Color.accentColor
        case .error:   return Color(NSColor.systemRed)
        case .output:  return Color(NSColor.secondaryLabelColor)
        }
    }

    private func runInput() {
        let cmd = input.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }
        output.append(ConsoleLine(text: "> " + cmd, kind: .command))
        input = ""

        let args = tokenize(cmd)
        let cliURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("iphoto-cli")

        guard FileManager.default.fileExists(atPath: cliURL.path) else {
            output.append(ConsoleLine(text: "Fehler: iphoto-cli nicht gefunden bei \(cliURL.path)", kind: .error))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = cliURL
            proc.arguments = args
            let outPipe = Pipe(); proc.standardOutput = outPipe
            let errPipe = Pipe(); proc.standardError  = errPipe
            do {
                try proc.run()
                // Drain pipes before waitUntilExit to prevent deadlock on >64 KB output.
                let outStr = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let errStr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let timeout = DispatchWorkItem { proc.terminate() }
                DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeout)
                proc.waitUntilExit()
                timeout.cancel()
                let outLines = outStr.components(separatedBy: "\n").filter { !$0.isEmpty }.map { ConsoleLine(text: $0, kind: .output) }
                let errLines = errStr.components(separatedBy: "\n").filter { !$0.isEmpty }.map { ConsoleLine(text: $0, kind: .error) }
                DispatchQueue.main.async {
                    self.output.append(contentsOf: outLines)
                    self.output.append(contentsOf: errLines)
                }
            } catch {
                DispatchQueue.main.async {
                    self.output.append(ConsoleLine(text: "Fehler: \(error.localizedDescription)", kind: .error))
                }
            }
        }
    }

    // Shell-like tokenizer: splits on whitespace, honours single/double quotes.
    private func tokenize(_ s: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quoteChar: Character? = nil
        for ch in s {
            if let q = quoteChar {
                if ch == q { quoteChar = nil } else { current.append(ch) }
            } else if ch == "\"" || ch == "'" {
                quoteChar = ch
            } else if ch == " " || ch == "\t" {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
