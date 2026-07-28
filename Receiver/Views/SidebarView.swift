//
//  SidebarView.swift
//  Poseiosc Receiver (macOS)
//
//  Per-address message rates and a scrolling (sampled) message log.
//

import SwiftUI

struct SidebarView: View {
    @Bindable var model: ReceiverModel

    private static let timeFormat = Date.FormatStyle(date: .omitted, time: .standard)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ratesSection
            Divider()
            logSection
        }
        .background(.background)
    }

    private var ratesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Message rates")
                .font(.headline)
            ForEach(FrameKind.allCases) { kind in
                HStack {
                    Circle().fill(kind.color).frame(width: 8, height: 8)
                    Text(kind.address)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Text("\(Int(model.rates[kind] ?? 0)) Hz")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle((model.rates[kind] ?? 0) > 0 ? .primary : .tertiary)
                }
            }
            HStack {
                Text("Total messages")
                Spacer()
                Text("\(model.totalMessages)")
                    .font(.system(.body, design: .monospaced))
            }
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .padding()
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Log")
                    .font(.headline)
                Text("(sampled)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Pause", isOn: $model.isLogPaused)
                    .toggleStyle(.checkbox)
            }
            .padding([.horizontal, .top])

            List(model.log) { entry in
                HStack(spacing: 8) {
                    Text(entry.time, format: Self.timeFormat)
                        .foregroundStyle(.secondary)
                    Text(entry.address)
                    Text("n=\(entry.detectionCount)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(entry.senderHost)
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 11, design: .monospaced))
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }
}
