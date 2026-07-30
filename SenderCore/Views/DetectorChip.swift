//
//  DetectorChip.swift
//  Poseiosc Sender (shared)
//
//  A colored pill toggle for one detector, used by both sender apps.
//

import SwiftUI

struct DetectorChip: View {
    let label: String
    let color: Color
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isOn ? color.opacity(0.85) : .black.opacity(0.4), in: .capsule)
                .foregroundStyle(isOn ? .black : .white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) detection")
        .accessibilityValue(isOn ? "on" : "off")
    }
}
