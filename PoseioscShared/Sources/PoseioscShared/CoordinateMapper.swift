//
//  CoordinateMapper.swift
//  PoseioscShared
//
//  Vision-space → wire-space conversion, matching VisionOSC exactly:
//  Vision uses normalized coordinates with origin bottom-left;
//  the wire format uses pixels with origin top-left.
//

import Foundation

public enum CoordinateMapper {
    /// Convert a Vision normalized point (origin bottom-left) to wire pixels (origin top-left).
    public static func point(
        normalizedX x: CGFloat,
        normalizedY y: CGFloat,
        confidence: Float,
        frameWidth: Float,
        frameHeight: Float
    ) -> WirePoint {
        WirePoint(
            x: Float(x) * frameWidth,
            y: (1 - Float(y)) * frameHeight,
            confidence: confidence
        )
    }

    /// Convert a Vision normalized bounding box (origin bottom-left) to a wire rect
    /// (pixels, origin top-left).
    public static func rect(
        normalized box: CGRect,
        frameWidth: Float,
        frameHeight: Float
    ) -> WireRect {
        WireRect(
            left: Float(box.origin.x) * frameWidth,
            top: (1 - Float(box.origin.y) - Float(box.size.height)) * frameHeight,
            width: Float(box.size.width) * frameWidth,
            height: Float(box.size.height) * frameHeight
        )
    }

    /// Convert a face landmark point that is normalized *to the face bounding box*
    /// (as Vision provides them) to wire pixels, replicating VisionOSC's double mapping.
    /// `boundingBox` is the face box in Vision normalized image space (origin bottom-left).
    public static func faceLandmarkPoint(
        pointInBox point: CGPoint,
        boundingBox: CGRect,
        precision: Float,
        frameWidth: Float,
        frameHeight: Float
    ) -> WirePoint {
        let boxLeft = Float(boundingBox.origin.x) * frameWidth
        let boxTop = (1 - Float(boundingBox.origin.y) - Float(boundingBox.size.height)) * frameHeight
        let boxWidth = Float(boundingBox.size.width) * frameWidth
        let boxHeight = Float(boundingBox.size.height) * frameHeight
        return WirePoint(
            x: Float(point.x) * boxWidth + boxLeft,
            y: (1 - Float(point.y)) * boxHeight + boxTop,
            confidence: precision
        )
    }
}
