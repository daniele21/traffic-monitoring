#if os(macOS)
import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var viewModel: DiagnosticsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Measurement diagnostics")
                        .font(.title2.weight(.semibold))
                    Text("Raw interface counters and 2-second deltas. Excluded interfaces remain visible for verification.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let lastUpdated = viewModel.lastUpdated {
                    Text(lastUpdated, style: .time)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            Table(viewModel.rows) {
                TableColumn("Interface") { row in
                    Text(row.interfaceName).monospaced()
                }
                TableColumn("Class") { row in
                    Text(row.classification)
                }
                TableColumn("Network") { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.networkName)
                        if row.isExpensive || row.isConstrained {
                            Text(metadataLabel(row))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                TableColumn("Raw ↓") { row in
                    Text(ByteCountFormatter.string(fromByteCount: Int64(clamping: row.rawReceivedBytes), countStyle: .decimal))
                        .monospacedDigit()
                }
                TableColumn("Raw ↑") { row in
                    Text(ByteCountFormatter.string(fromByteCount: Int64(clamping: row.rawTransmittedBytes), countStyle: .decimal))
                        .monospacedDigit()
                }
                TableColumn("Δ ↓") { row in
                    Text(ByteCountFormatter.string(fromByteCount: Int64(clamping: row.deltaReceivedBytes), countStyle: .decimal))
                        .monospacedDigit()
                }
                TableColumn("Δ ↑") { row in
                    Text(ByteCountFormatter.string(fromByteCount: Int64(clamping: row.deltaTransmittedBytes), countStyle: .decimal))
                        .monospacedDigit()
                }
            }
            .frame(minHeight: 320)
        }
        .padding(20)
    }

    private func metadataLabel(_ row: DiagnosticInterfaceRow) -> String {
        [row.isExpensive ? "expensive" : nil, row.isConstrained ? "constrained" : nil]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
#endif
