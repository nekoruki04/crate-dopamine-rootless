// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// One license text and who it covers: crate itself, or the components of
/// THIRD_PARTY_NOTICES.md that share it word for word.
struct Acknowledgement: Identifiable {
    let id: Int
    let names: [String]
    let text: String

    /// crate's own license, then every text from the notices, both bundled
    /// with the app (Scripts/third-party-notices.py writes the notices).
    static let all: [Acknowledgement] = {
        var entries: [Acknowledgement] = []
        if let license = bundled("LICENSE", ext: nil) {
            entries.append(Acknowledgement(id: 0, names: ["crate (MPL-2.0)"], text: license))
        }
        guard let notices = bundled("THIRD_PARTY_NOTICES", ext: "md"),
              let start = notices.range(of: "\n## License texts\n") else { return entries }
        // Each text is a "### names" heading (separated by "; "), then the text
        // in a ```` fence; headings inside a fence belong to the text.
        var names: [String] = []
        var lines: [Substring] = []
        var inText = false
        for line in notices[start.upperBound...].split(separator: "\n", omittingEmptySubsequences: false) {
            if inText {
                if line == "````" {
                    inText = false
                    entries.append(Acknowledgement(id: entries.count, names: names,
                                                   text: lines.joined(separator: "\n")))
                    lines = []
                } else {
                    lines.append(line)
                }
            } else if line.hasPrefix("### ") {
                names = line.dropFirst(4).components(separatedBy: "; ")
            } else if line.hasPrefix("````") {
                inText = true
            }
        }
        return entries
    }()

    private static func bundled(_ name: String, ext: String?) -> String? {
        Bundle.main.url(forResource: name, withExtension: ext)
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }
}

/// Settings > Acknowledgements: the licenses of crate and of everything it
/// carries from other projects.
struct AcknowledgementsScreen: View {
    @State private var search = ""

    private var shown: [Acknowledgement] {
        guard !search.isEmpty else { return Acknowledgement.all }
        return Acknowledgement.all.filter { entry in
            entry.names.contains { $0.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(shown) { entry in
                    NavigationLink {
                        LicenseText(entry: entry)
                    } label: {
                        Text(entry.names.joined(separator: "; "))
                            .lineLimit(3)
                    }
                }
            } footer: {
                if search.isEmpty {
                    Text("crate is MPL-2.0. It carries code from these projects, each under its own license.")
                }
            }
        }
        .navigationTitle("Acknowledgements")
        .searchable(text: $search, prompt: "Projects")
    }
}

private struct LicenseText: View {
    let entry: Acknowledgement

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if entry.names.count > 1 {
                    Text(entry.names.joined(separator: "; "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(entry.text)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(entry.names.count > 1 ? "\(entry.names[0]) and \(entry.names.count - 1) more" : entry.names[0])
        .navigationBarTitleDisplayMode(.inline)
    }
}
