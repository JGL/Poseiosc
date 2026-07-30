//
//  MacAppModel.swift
//  Poseiosc Sender (macOS)
//
//  Wires camera → conveyor → Vision processor → OSC sender, mirroring the
//  iOS AppModel without the interface-orientation machinery.
//

import Foundation
import Observation

@Observable @MainActor
final class MacAppModel {
    let settings = MacSettingsStore()
    let camera = MacCameraManager()
    let oscSender = OSCSenderService()
    let bonjour = BonjourBrowser()

    private(set) var overlay = OverlaySnapshot()
    private(set) var processedFPS: Double = 0
    private(set) var cameras: [CameraOption] = []

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

        refreshCameras()
        camera.start(deviceID: settings.cameraID)
        applySettings()
    }

    func stop() {
        camera.stop()
    }

    func applySettings() {
        oscSender.setDestination(host: settings.host, port: settings.port)
        camera.setRotation(Int32(settings.rotationDegrees))
        let config = settings.detectorConfig
        Task { [processor] in
            await processor?.setConfig(config)
        }
    }

    func refreshCameras() {
        cameras = MacCameraManager.availableCameras()
    }

    func selectCamera(id: String) {
        settings.cameraID = id
        camera.start(deviceID: id)
    }

    private func acceptSnapshot(_ snapshot: OverlaySnapshot) {
        overlay = snapshot
        let now = Date.now
        recentProcessTimes.append(now)
        recentProcessTimes.removeAll { now.timeIntervalSince($0) > 1.0 }
        processedFPS = Double(recentProcessTimes.count)
    }
}
