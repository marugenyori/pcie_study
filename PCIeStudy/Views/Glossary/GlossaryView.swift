import SwiftUI

struct GlossaryView: View {
    @State private var query = ""
    @State private var category: GlossaryTerm.Category? = nil

    private var filtered: [GlossaryTerm] {
        GlossaryData.all.filter { term in
            let matchesCategory = category == nil || term.category == category
            let q = query.trimmingCharacters(in: .whitespaces)
            let matchesQuery = q.isEmpty
                || term.term.localizedCaseInsensitiveContains(q)
                || term.fullName.localizedCaseInsensitiveContains(q)
                || term.description.localizedCaseInsensitiveContains(q)
            return matchesCategory && matchesQuery
        }
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip(title: "すべて", isOn: category == nil) { category = nil }
                        ForEach(GlossaryTerm.Category.allCases) { c in
                            chip(title: c.rawValue, isOn: category == c) { category = c }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }

            Section("\(filtered.count) 語") {
                ForEach(filtered) { term in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(term.description)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(term.category.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(term.term).font(.body.bold())
                            if term.fullName != term.term {
                                Text(term.fullName).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "用語を検索（例：TLP、クレジット）")
        .navigationTitle("用語集")
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private func chip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isOn ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(isOn ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { GlossaryView() }
}
