//
//  CameraManager.swift
//  Poseiosc Sender (iOS)
//
//  Owns the AVCaptureSession. Frames go to the FrameConveyor; the preview
//  layer is exposed for the SwiftUI preview view.
//
//  Orientation: buffers are delivered sensor-native (landscape). Instead of
//  rotating pixels, we tell Vision how the buffer is oriented. The app is
//  locked to portrait, so the mapping is fixed per camera position:
//    back camera:  .right
//    front camera: .left   (upright but UNMIRRORED, matching VisionOSC's
//                           convention; the preview is forced unmirrored too
//                           so overlay, preview, and OSC data all agree)
//

@preconcurrency import AVFoundation
import ImageIO

final class CameraManager: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "poseiosc.camera.session")
    private let videoQueue = DispatchQueue(label: "poseiosc.camera.video")
    private let output = AVCaptureVideoDataOutput()
    private var conveyor: FrameConveyor?
    private(set) var position: AVCaptureDevice.Position = .back

    func attach(conveyor: FrameConveyor) {
        self.conveyor = conveyor
    }

    func start(position: AVCaptureDevice.Position) {
        sessionQueue.async { [self] in
            configure(position: position)
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = position == .back ? .front : .back
        sessionQueue.async { [self] in
            configure(position: newPosition)
        }
    }

    private func configure(position newPosition: AVCaptureDevice.Position) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        for input in session.inputs {
            session.removeInput(input)
        }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }

        session.addInput(input)
        position = newPosition

        if session.sessionPreset != .hd1280x720, session.canSetSessionPreset(.hd1280x720) {
            // 720p is plenty for Vision and keeps all-detectors latency down.
            session.sessionPreset = .hd1280x720
        }

        if !session.outputs.contains(output) {
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: videoQueue)
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
        }

        // Deliver sensor-native buffers; no rotation, no mirroring.
        if let connection = output.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
    }

    /// Vision orientation for the current camera in portrait UI.
    private var visionOrientation: CGImagePropertyOrientation {
        position == .front ? .left : .right
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard
            let conveyor,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }

        let orientation = visionOrientation
        let bufferWidth = Int32(CVPixelBufferGetWidth(pixelBuffer))
        let bufferHeight = Int32(CVPixelBufferGetHeight(pixelBuffer))

        // .left/.right rotate 90°, so oriented dims are swapped buffer dims.
        conveyor.submit(FrameBox(
            pixelBuffer: pixelBuffer,
            orientation: orientation,
            orientedWidth: bufferHeight,
            orientedHeight: bufferWidth
        ))
    }
}
