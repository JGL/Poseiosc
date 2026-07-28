//
//  CameraPreviewView.swift
//  Poseiosc Sender (iOS)
//
//  Hosts the AVCaptureVideoPreviewLayer. Mirroring is disabled even for the
//  front camera so the preview matches the unmirrored coordinates sent over OSC.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        disableMirroring(view.previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        disableMirroring(uiView.previewLayer)
    }

    private func disableMirroring(_ layer: AVCaptureVideoPreviewLayer) {
        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }
}
