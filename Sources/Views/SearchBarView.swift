import SwiftUI

// MARK: - Search Bar

struct SearchBarView: View {
    @Binding var query: String
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isEditing = false

    private var currentWord: String { query.components(separatedBy: " ").last ?? "" }
    private var activeFilters: [SearchToken] { SearchQuery.parse(query).filters }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("Suchen…", text: $query, onEditingChanged: { editing in
                    withAnimation(.easeInOut(duration: 0.1)) { isEditing = editing }
                })
                .font(.system(size: 12))
                .textFieldStyle(PlainTextFieldStyle())
                if !query.isEmpty {
                    Button(action: { query = ""; isEditing = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(isEditing ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1))
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if !activeFilters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(activeFilters, id: \.key) { filterChip($0) }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.bottom, 2)
                if let summary = viewModel.searchResultSummary {
                    Text(summary)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 4)
                }
            }

            if isEditing { dropdownView }
        }
    }

    @ViewBuilder
    private var dropdownView: some View {
        let word = currentWord
        if let ci = word.firstIndex(of: ":"), ci != word.startIndex {
            let key = String(word[..<ci]).lowercased()
            let partial = String(word[word.index(after: ci)...]).lowercased()
            if let def = FilterDefinition.all.first(where: { $0.key == key }) {
                let staticVals = def.valueSuggestions.filter { partial.isEmpty || $0.hasPrefix(partial) }
                let dynVals = dynamicValues(key: key, partial: partial)
                let allVals = Array((staticVals + dynVals).prefix(8))
                if !allVals.isEmpty {
                    valueDropdown(def: def, values: allVals, key: key)
                }
            }
        } else {
            let matchDefs: [FilterDefinition] = word.isEmpty
                ? FilterDefinition.all
                : FilterDefinition.all.filter { $0.key.hasPrefix(word.lowercased()) || $0.label.lowercased().hasPrefix(word.lowercased()) }
            let textSuggs = textSuggestions
            if !matchDefs.isEmpty || !textSuggs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(matchDefs.prefix(6)), id: \.key) { def in
                        filterKeyRow(def)
                        if def.key != matchDefs.prefix(6).last?.key { Divider() }
                    }
                    if !textSuggs.isEmpty && !word.isEmpty {
                        if !matchDefs.isEmpty { Divider() }
                        ForEach(textSuggs.prefix(4), id: \.self) { textSuggRow($0) }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
    }

    private func filterKeyRow(_ def: FilterDefinition) -> some View {
        Button(action: {
            var parts = query.components(separatedBy: " ")
            if let li = parts.indices.last, !parts[li].contains(":") {
                parts[li] = def.key + ":"
            } else {
                parts.append(def.key + ":")
            }
            query = parts.joined(separator: " ")
        }) {
            HStack(spacing: 8) {
                Image(systemName: def.icon)
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(def.key + ":")
                        .font(.system(size: 11, weight: .medium))
                    Text(def.hint)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func valueDropdown(def: FilterDefinition, values: [String], key: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: def.icon).font(.system(size: 10)).foregroundColor(.accentColor)
                Text(key + ":").font(.system(size: 10, weight: .semibold)).foregroundColor(.accentColor)
                Text(def.hint).font(.system(size: 10)).foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            Divider()
            ForEach(values, id: \.self) { value in
                Button(action: {
                    var parts = query.components(separatedBy: " ")
                    if let li = parts.indices.last { parts[li] = key + ":" + value }
                    query = parts.joined(separator: " ") + " "
                }) {
                    HStack {
                        Text(value).font(.system(size: 11))
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4).contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 8).padding(.bottom, 4)
    }

    private func textSuggRow(_ s: String) -> some View {
        Button(action: {
            let filters = query.components(separatedBy: " ").filter { $0.contains(":") }
            query = (filters + [s]).joined(separator: " ")
            isEditing = false
        }) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundColor(.secondary).frame(width: 16)
                Text(s).font(.system(size: 11)).lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 4).contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func filterChip(_ token: SearchToken) -> some View {
        HStack(spacing: 3) {
            Text(token.key + ":").font(.system(size: 10, weight: .semibold)).foregroundColor(.accentColor)
            Text(token.value).font(.system(size: 10))
            Button(action: {
                let parts = query.components(separatedBy: " ").filter { !$0.hasPrefix(token.key + ":") }
                query = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            }) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.12))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor.opacity(0.25), lineWidth: 0.5))
    }

    private var textSuggestions: [String] {
        let q = SearchQuery.parse(query).freeText.lowercased()
        guard q.count >= 2 else { return [] }
        var results = Set<String>()
        for doc in viewModel.collection.documents.prefix(500) {
            let name = doc.url.lastPathComponent
            if name.lowercased().contains(q) { results.insert(name) }
        }
        return Array(results.sorted()).prefix(6).map { $0 }
    }

    private func dynamicValues(key: String, partial: String) -> [String] {
        switch key {
        case "kamera":
            var set = Set<String>()
            for doc in viewModel.collection.documents.prefix(300) {
                for e in doc.metadata where e.category == .camera && !e.value.isEmpty { set.insert(e.value) }
            }
            return set.filter { partial.isEmpty || $0.lowercased().hasPrefix(partial) }.sorted().prefix(6).map { $0 }
        case "album":
            return viewModel.library.albums.map { $0.name }
                .filter { partial.isEmpty || $0.lowercased().hasPrefix(partial) }.sorted().prefix(6).map { $0 }
        case "motiv":
            var set = Set<String>()
            for doc in viewModel.collection.documents.prefix(300) {
                for t in doc.motifTags ?? [] { set.insert(t) }
            }
            return set.filter { partial.isEmpty || $0.lowercased().hasPrefix(partial) }.sorted().prefix(6).map { $0 }
        default: return []
        }
    }
}
