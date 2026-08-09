#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EvidenceExportPreviewView: View {
    @ObservedObject var analytics: HistoricalAnalyticsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .json
    @State private var saveMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export evidence")
                        .font(.title2.bold())
                    Text("Preview exactly what will be written. Export is local and user-initiated.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
            }

            Picker("Format", selection: $format) {
                ForEach(ExportFormat.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            GroupBox("Included") {
                Text("Selected period, aggregate totals, observed coverage, evidence quality, network identity/display name, connection type, download/upload/total bytes, expensive-network flag, app version and schema version.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            ScrollView([.horizontal, .vertical]) {
                Text(preview)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            .frame(minHeight: 300)

            HStack {
                if let saveMessage {
                    Text(saveMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Save \(format.title)…") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 760, height: 610)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
    }

    private var preview: String {
        switch format {
        case .json:
            return (try? analytics.jsonExport(appVersion: appVersion)) ?? "Unable to generate JSON preview."
        case .csv:
            return analytics.csvExport(appVersion: appVersion)
        }
    }

    private func save() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "traffic-monitoring-evidence.\(format.fileExtension)"
        panel.canCreateDirectories = true
        if let type = UTType(filenameExtension: format.fileExtension) {
            panel.allowedContentTypes = [type]
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = Data(preview.utf8)
            try data.write(to: url, options: .atomic)
            saveMessage = "Saved \(url.lastPathComponent)"
        } catch {
            saveMessage = "Could not save: \(error.localizedDescription)"
        }
    }
}

private enum ExportFormat: String, CaseIterable, Identifiable {
    case json
    case csv

    var id: Self { self }
    var title: String { rawValue.uppercased() }
    var fileExtension: String { rawValue }
}
#endif
