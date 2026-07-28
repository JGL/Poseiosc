//
//  Models.swift
//  PoseioscShared
//
//  Plain value types describing one frame of detections, in wire coordinates:
//  pixels, origin top-left, unmirrored.
//

import Foundation

/// A single keypoint in pixel coordinates (origin top-left).
/// `confidence` carries Vision's per-point confidence — except for face points,
/// where it carries the per-point precision estimate, matching VisionOSC.
public struct WirePoint: Sendable, Equatable {
    public var x: Float
    public var y: Float
    public var confidence: Float

    public init(x: Float, y: Float, confidence: Float) {
        self.x = x
        self.y = y
        self.confidence = confidence
    }

    /// VisionOSC's "missing joint" value: vision-space (0,0) run through the
    /// top-left flip, i.e. `(0, frameHeight, 0)`. Consumers filter on confidence == 0.
    public static func missing(frameHeight: Float) -> WirePoint {
        WirePoint(x: 0, y: frameHeight, confidence: 0)
    }
}

/// An axis-aligned bounding box in pixel coordinates (origin top-left).
public struct WireRect: Sendable, Equatable {
    public var left: Float
    public var top: Float
    public var width: Float
    public var height: Float

    public init(left: Float, top: Float, width: Float, height: Float) {
        self.left = left
        self.top = top
        self.width = width
        self.height = height
    }
}

/// One detected body pose: overall confidence + exactly 17 joints in `JointOrder.body17` order.
public struct PoseDetection: Sendable, Equatable {
    public var confidence: Float
    public var joints: [WirePoint]

    public init(confidence: Float, joints: [WirePoint]) {
        precondition(joints.count == WireCounts.bodyJoints, "PoseDetection requires exactly \(WireCounts.bodyJoints) joints")
        self.confidence = confidence
        self.joints = joints
    }
}

/// One detected hand: overall confidence + exactly 21 joints in `JointOrder.hand21` order.
public struct HandDetection: Sendable, Equatable {
    public var confidence: Float
    public var joints: [WirePoint]

    public init(confidence: Float, joints: [WirePoint]) {
        precondition(joints.count == WireCounts.handJoints, "HandDetection requires exactly \(WireCounts.handJoints) joints")
        self.confidence = confidence
        self.joints = joints
    }
}

/// One detected face: overall confidence + exactly 76 landmark points in Vision's
/// constellation order. Each point's `confidence` is Vision's precision estimate.
public struct FaceDetection: Sendable, Equatable {
    public var confidence: Float
    public var points: [WirePoint]

    public init(confidence: Float, points: [WirePoint]) {
        precondition(points.count == WireCounts.facePoints, "FaceDetection requires exactly \(WireCounts.facePoints) points")
        self.confidence = confidence
        self.points = points
    }
}

/// One detected text region or animal: confidence + bounding box + string payload
/// (recognized text, or animal label "Cat"/"Dog").
public struct BoxDetection: Sendable, Equatable {
    public var confidence: Float
    public var box: WireRect
    public var label: String

    public init(confidence: Float, box: WireRect, label: String) {
        self.confidence = confidence
        self.box = box
        self.label = label
    }
}

/// A full frame of detections of one kind, with the camera frame dimensions
/// (oriented pixels) that all coordinates are expressed in.
public struct DetectionFrame<Detection: Sendable & Equatable>: Sendable, Equatable {
    public var width: Int32
    public var height: Int32
    public var detections: [Detection]

    public init(width: Int32, height: Int32, detections: [Detection]) {
        self.width = width
        self.height = height
        self.detections = detections
    }
}

/// A decoded incoming message, dispatched by OSC address.
public enum DecodedFrame: Sendable {
    case poses(DetectionFrame<PoseDetection>)
    case hands(DetectionFrame<HandDetection>)
    case faces(DetectionFrame<FaceDetection>)
    case texts(DetectionFrame<BoxDetection>)
    case animals(DetectionFrame<BoxDetection>)

    /// The OSC address this frame kind corresponds to.
    public var address: String {
        switch self {
        case .poses: OSCAddress.poses
        case .hands: OSCAddress.hands
        case .faces: OSCAddress.faces
        case .texts: OSCAddress.texts
        case .animals: OSCAddress.animals
        }
    }
}
