//
//  PoseioscReceiverApp.swift
//  Poseiosc Receiver (macOS)
//
//  Listens for Poseiosc/VisionOSC OSC messages, visualizes them, and advertises
//  itself via Bonjour so the iOS sender can discover it.
//

import SwiftUI

@main
struct PoseioscReceiverApp: App {
    @State private var model = ReceiverModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 900, minHeight: 560)
        }
    }
}
