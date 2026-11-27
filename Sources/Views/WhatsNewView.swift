import SwiftUI

struct WhatsNewItem: Codable {
    let icon: String
    let color: String
    let title: String
    let description: String
}

struct WhatsNewData: Codable {
    let version: String
    let releaseType: String?   // "major", "minor", "patch" — nil treated as "minor"
    let items: [WhatsNewItem]
}

struct WhatsNewView: View {
    let data: WhatsNewData
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            featureList
            bottomBar
        }
        .frame(width: 500, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            .padding(.top, 32)

            Text(headerTitle)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 40)
    }

    private var headerTitle: String {
        let type = data.releaseType ?? "minor"
        switch type {
        case "major": return "Willkommen in Photo α \(majorVersion)"
        default:      return "Neu in Photo α"
        }
    }

    private var subtitle: String {
        let type = data.releaseType ?? "minor"
        switch type {
        case "major": return "Alle neuen Funktionen auf einen Blick"
        case "patch": return "Version \(data.version) — Verbesserungen & Fehlerbehebungen"
        default:      return "Version \(data.version)"
        }
    }

    private var majorVersion: String {
        data.version.components(separatedBy: ".").first ?? data.version
    }

    // MARK: - Feature list

    private var featureList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 22) {
                ForEach(data.items, id: \.title) { item in
                    WhatsNewRow(item: item)
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: onDismiss) {
                Text("Weiter")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.accentColor)
                    .cornerRadius(9)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 36)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Feature row

private struct WhatsNewRow: View {
    let item: WhatsNewItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            iconBubble
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var iconBubble: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(rowColor)
                .frame(width: 52, height: 52)
            Image(systemName: item.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private var rowColor: Color {
        switch item.color {
        case "blue":   return .blue
        case "green":  return .green
        case "orange": return .orange
        case "red":    return .red
        case "purple": return Color(red: 0.55, green: 0.27, blue: 0.80)
        case "pink":   return Color(red: 0.96, green: 0.33, blue: 0.56)
        case "teal":   return Color(red: 0.18, green: 0.68, blue: 0.59)
        case "yellow": return Color(red: 0.98, green: 0.73, blue: 0.10)
        default:       return .accentColor
        }
    }
}

// MARK: - Loader helper

enum WhatsNewLoader {
    static func load() -> WhatsNewData? {
        guard let url = Bundle.main.url(forResource: "WhatsNew", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WhatsNewData.self, from: data)
    }

    static func shouldShow(_ data: WhatsNewData) -> Bool {
        let type = data.releaseType ?? "minor"
        guard type != "patch" else { return false }
        let lastSeen = UserDefaults.standard.string(forKey: "whatsNew.lastSeenVersion") ?? ""
        return data.version != lastSeen
    }

    static func markSeen(_ version: String) {
        UserDefaults.standard.set(version, forKey: "whatsNew.lastSeenVersion")
    }
}
