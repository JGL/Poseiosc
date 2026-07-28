//
//  ContentView.swift
//  Poseiosc Sender (iOS)
//

import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: model.camera.session)
                .ignoresSafeArea()
            OverlayView(snapshot: model.overlay)
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
