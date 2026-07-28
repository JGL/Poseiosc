//
//  AppModel.swift
//  Poseiosc Sender (iOS)
//
//  Wires camera → conveyor → Vision processor → OSC sender, and holds the
//  overlay state for SwiftUI.
//

import Foundation
import AVFoundation
import Observation

@Observable @MainActor
final class AppModel {
    let settings = SettingsStore()
    let camera = CameraManager()
    let oscSender = OSCSenderService()
    let bonjour = BonjourBrowser()

    private(set) var overlay = OverlaySnapshot()
    private(set) var processedFPS: Double = 0

    var sentCount: UInt64 { oscSender.counters.sent }

    private var processor: VisionProcessor?
    private var recentProcessTimes: [Date] = []

    func start() {
        oscSender.setDestination(host: settings.host, port: settings.port)
        oscSender.start()
        bonjour.start()

        let processor = VisionProcessor(sender: oscSender) { [weak self] snapshot in
            Task { @MainActor in
                self?.acceptSnapshot(snapshot)
            }
        }
        self.processor = processor

        let conveyor = FrameConveyor { frame in
            await processor.process(frame)
        }
        camera.attach(conveyor: conveyor)
        camera.start(position: settings.useFrontCamera ? .front : .back)

        applySettings()
    }

    func stop() {
        camera.stop()
    }

    /// Push current settings into the pipeline. Call after any settings change.
    func applySettings() {
        oscSender.setDestination(host: settings.host, port: settings.port)
        let config = settings.detectorConfig
        Task { [processor] in
            await processor?.setConfig(config)
        }
    }

    func switchCamera() {
        settings.useFrontCamera.toggle()
        camera.switchCamera()
    }

    private func acceptSnapshot(_ snapshot: OverlaySnapshot) {
        overlay = snapshot
        let now = Date.now
        recentProcessTimes.append(now)
        recentProcessTimes.removeAll { now.timeIntervalSince($0) > 1.0 }
        processedFPS = Double(recentProcessTimes.count)
    }
}
