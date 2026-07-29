//
//  CameraManager.swift
//  Poseiosc Sender (iOS)
//
//  Owns the AVCaptureSession. Frames go to the FrameConveyor; the preview
//  layer is exposed for the SwiftUI preview view.
//
//  Orientation: buffers are delivered sensor-native (landscape) and
//  unmirrored (mirroring is disabled on the connection). Instead of rotating
//  pixels, we tell Vision how the buffer is oriented, derived from an
//  AVCaptureDevice.RotationCoordinator in Auto mode or from the user's
//  orientation lock (for mounted rigs, where gravity-based detection is
//  unreliable — e.g. a phone lying flat). Angle → Vision mapping: 90° =
//  .right (the empirically verified portrait case for both cameras), 0° =
//  .up, 180° = .down, 270° = .left.
//
//  Coordinates stay unmirrored, matching VisionOSC's convention; the preview
//  is forced unmirrored too so overlay, preview, and OSC data all agree.
//

@preconcurrency import AVFoundation
import ImageIO
import os.lock

final class CameraManager: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    /// Owned here (not by the SwiftUI view) so mirroring can be re-disabled
    /// inside every session reconfiguration — the layer's connection does not
    /// exist until the session has inputs, and it is recreated (with
    /// mirroring re-enabled by default) on every camera switch.
    let previewLayer: AVCaptureVideoPreviewLayer

    private let sessionQueue = DispatchQueue(label: "poseiosc.camera.session")
    private let videoQueue = DispatchQueue(label: "poseiosc.camera.video")
    private let output = AVCaptureVideoDataOutput()
    private var conveyor: FrameConveyor?
    private(set) var position: AVCaptureDevice.Position = .back

    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    /// The rotation angle frames are currently interpreted with. Written from
    /// the KVO callback / settings changes, read on the video queue per frame.
    private let effectiveAngle = OSAllocatedUnfairLock<Int32>(initialState: 90)

    /// The user's orientation setting (nil-equivalent: .auto follows device).
    private let orientationLock = OSAllocatedUnfairLock<CameraOrientationSetting>(initialState: .auto)

    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        super.init()
    }

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

    func setOrientationLock(_ setting: CameraOrientationSetting) {
        orientationLock.withLock { $0 = setting }
        applyRotation()
    }

    private func configure(position newPosition: AVCaptureDevice.Position) {
        session.beginConfiguration()

        for input in session.inputs {
            session.removeInput(input)
        }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        position = newPosition

        if session.sessionPreset != .hd1280x720, session.canSetSessionPreset(.hd1280x720) {
            // 720p is plenty for Vision and keeps all-detectors latency down.
            session.sessionPreset = .hd1280x720
        }

        if !session.outputs.contains(output) {
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: videoQueue)
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                return
            }
            session.addOutput(output)
        }

        // Deliver sensor-native buffers; no rotation, no mirroring.
        if let connection = output.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }

        // The preview connection now exists (session has an input) and was
        // recreated with automatic mirroring; force it unmirrored so the
        // preview matches the coordinates sent over OSC.
        if let preview = previewLayer.connection, preview.isVideoMirroringSupported {
            preview.automaticallyAdjustsVideoMirroring = false
            preview.isVideoMirrored = false
        }

        session.commitConfiguration()

        // Recreate the rotation coordinator for the new device and follow its
        // angle updates. (Created after commit; it needs the live device.)
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        rotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            self?.applyRotation()
        }
    }

    /// Recomputes the effective angle from the lock setting (or the rotation
    /// coordinator in Auto) and applies it to the preview connection.
    private func applyRotation() {
        let lock = orientationLock.withLock { $0 }
        let angle: Int32
        if lock == .auto {
            let coordinatorAngle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview ?? 90
            angle = Int32(coordinatorAngle.rounded())
        } else {
            angle = Int32(lock.rawValue)
        }
        effectiveAngle.withLock { $0 = angle }

        DispatchQueue.main.async { [self] in
            if let connection = previewLayer.connection,
               connection.isVideoRotationAngleSupported(CGFloat(angle)) {
                connection.videoRotationAngle = CGFloat(angle)
            }
        }
    }

    private static func visionOrientation(forAngle angle: Int32) -> CGImagePropertyOrientation {
        switch angle {
        case 90: .right
        case 180: .down
        case 270: .left
        default: .up
        }
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

        let angle = effectiveAngle.withLock { $0 }
        let orientation = Self.visionOrientation(forAngle: angle)
        let bufferWidth = Int32(CVPixelBufferGetWidth(pixelBuffer))
        let bufferHeight = Int32(CVPixelBufferGetHeight(pixelBuffer))

        // 90°/270° rotations swap the oriented dimensions.
        let swapped = angle == 90 || angle == 270
        conveyor.submit(FrameBox(
            pixelBuffer: pixelBuffer,
            orientation: orientation,
            orientedWidth: swapped ? bufferHeight : bufferWidth,
            orientedHeight: swapped ? bufferWidth : bufferHeight,
            rotationDegrees: angle,
            isFrontCamera: position == .front
        ))
    }
}
