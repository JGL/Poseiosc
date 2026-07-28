//
//  ContentView.swift
//  Poseiosc Sender (iOS)
//

import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()
    @State private var showSettings = false

    /// Selfie-mirror is display-only: the preview is flipped with a scale
    /// transform and the overlay flips its own coordinates (keeping label
    /// text readable). OSC output is unaffected.
    private var isMirrored: Bool {
        model.settings.useFrontCamera && model.settings.mirrorFrontPreview
    }

    var body: some View {
        ZStack {
            CameraPreviewView(previewLayer: model.camera.previewLayer)
                .scaleEffect(x: isMirrored ? -1 : 1, y: 1)
                .ignoresSafeArea()
            OverlayView(snapshot: model.overlay, mirrored: isMirrored)
                .ignoresSafeArea()

            VStack {
                StatusBarView(model: model)
                Spacer()
                ControlBarView(model: model, showSettings: $showSettings)
            }
        }
        .statusBarHidden()
        .task {
            model.start()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(model: model)
        }
    }
}
