import SwiftUI
import AppKit

struct DuplicatesSheet: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @Environment(\.presentationMode) private var presentationMode
    let groups: [[ImageDocument]]

    @State private var markedForDeletion: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        GroupRow(group: group, markedForDeletion: $markedForDeletion)
                        Divider().padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
            Divider()
            footerRow
        }
        .frame(width: 600, height: 460)
        .onAppear {
            var marked = Set<UUID>()
            for group in groups {
                for doc in group.dropFirst() {
                    marked.insert(doc.id)
                }
            }
            markedForDeletion = marked
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Mögliche Duplikate")
                    .font(.headline)
                let total = groups.reduce(0) { $0 + $1.count } - groups.count
                Text("\(groups.count) \(groups.count == 1 ? "Gruppe" : "Gruppen"), \(total + groups.count) Dateien — gleicher Aufnahmezeitpunkt und gleiche Dateigröße")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Schließen") { presentationMode.wrappedValue.dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var footerRow: some View {
        HStack {
            let count = markedForDeletion.count
            if count == 0 {
                Text("Keine Dateien ausgewählt")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(count) \(count == 1 ? "Datei" : "Dateien") in den Papierkorb verschieben")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("In Papierkorb") {
                let toTrash = groups.flatMap { $0 }.filter { markedForDeletion.contains($0.id) }
                viewModel.moveToAppTrash(toTrash)
                viewModel.duplicateGroups = []
                presentationMode.wrappedValue.dismiss()
            }
            .disabled(markedForDeletion.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private struct GroupRow: View {
    let group: [ImageDocument]
    @Binding var markedForDeletion: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let date = group.first?.metadata.first(where: { $0.key == "exif.DateTimeOriginal" })?.value {
                Text(date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(group) { doc in
                        DocCard(doc: doc, markedForDeletion: $markedForDeletion)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
    }
}

private struct DocCard: View {
    let doc: ImageDocument
    @Binding var markedForDeletion: Set<UUID>

    private var isMarked: Bool { markedForDeletion.contains(doc.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = doc.thumbnailImage ?? doc.placeholderThumbnailImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 82)
                            .clipped()
                    } else {
                        Color.secondary.opacity(0.15)
                            .frame(width: 110, height: 82)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isMarked ? Color.red.opacity(0.7) : Color.secondary.opacity(0.25), lineWidth: isMarked ? 2 : 0.5)
                )

                if isMarked {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white).padding(2))
                        .padding(4)
                }
            }

            Text(doc.filename)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)

            Text(doc.url.deletingLastPathComponent().path
                    .replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(width: 110, alignment: .leading)

            Toggle(isMarked ? "Löschen" : "Behalten", isOn: Binding(
                get: { isMarked },
                set: { v in
                    if v { markedForDeletion.insert(doc.id) }
                    else { markedForDeletion.remove(doc.id) }
                }
            ))
            .toggleStyle(CheckboxToggleStyle())
            .font(.system(size: 10))
            .foregroundColor(isMarked ? .red : .primary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isMarked { markedForDeletion.remove(doc.id) }
            else { markedForDeletion.insert(doc.id) }
        }
    }
}
