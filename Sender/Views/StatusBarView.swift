//
//  StatusBarView.swift
//  Poseiosc Sender (iOS)
//
//  Destination and processing-rate readout over the camera preview.
//

import SwiftUI

struct StatusBarView: View {
    var model: AppModel

    var body: some View {
        HStack {
            Text(destinationLabel)
                .font(.system(.footnote, design: .monospaced))
            Spacer()
            Text("\(model.processedFPS, format: .number.precision(.fractionLength(0))) fps")
                .font(.system(.footnote, design: .monospaced))
        }
        .padding(8)
        .background(.black.opacity(0.5), in: .capsule)
        .foregroundStyle(.white)
        .padding(.horizontal)
    }

    private var destinationLabel: String {
        let host = model.settings.host.isEmpty ? "—" : model.settings.host
        return "→ \(host):\(String(model.settings.port))"
    }
}
