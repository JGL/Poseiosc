//
//  MacCameraPreviewView.swift
//  Poseiosc Sender (macOS)
//
//  Hosts the MacCameraManager's AVCaptureVideoPreviewLayer.
//

import SwiftUI
import AVFoundation

struct MacCameraPreviewView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    final class PreviewNSView: NSView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            didSet {
                guard previewLayer !== oldValue else { return }
                oldValue?.removeFromSuperlayer()
                if let previewLayer {
                    wantsLayer = true
                    layer?.addSublayer(previewLayer)
                    needsLayout = true
                }
            }
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer?.frame = bounds
            CATransaction.commit()
        }
    }

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.wantsLayer = true
        view.previewLayer = previewLayer
        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        nsView.previewLayer = previewLayer
    }
}
