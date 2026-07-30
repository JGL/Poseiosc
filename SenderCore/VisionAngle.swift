//
//  VisionAngle.swift
//  Poseiosc Sender (shared)
//
//  Rotation-angle helpers shared by the iOS and macOS camera managers.
//  Angles are AVFoundation video rotation degrees; buffers are sensor-native.
//

import ImageIO

enum VisionAngle {
    /// CGImagePropertyOrientation Vision needs for a buffer captured at the
    /// given rotation angle. 90° = portrait = .right (device-verified).
    static func orientation(forDegrees angle: Int32) -> CGImagePropertyOrientation {
        switch angle {
        case 90: .right
        case 180: .down
        case 270: .left
        default: .up
        }
    }

    /// 90°/270° rotations swap the oriented frame dimensions.
    static func isQuarterTurn(_ angle: Int32) -> Bool {
        angle == 90 || angle == 270
    }
}
