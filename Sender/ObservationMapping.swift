//
//  ObservationMapping.swift
//  Poseiosc Sender (iOS)
//
//  Vision observations → wire models. All VisionOSC fidelity decisions live
//  here: joint ordering, coordinate flips, missing-joint sentinels.
//

import Foundation
import Vision
import PoseioscShared

enum ObservationMapping {
    // MARK: - Body poses

    /// The 17 joints of the wire format, in PoseNet order (JointOrder.body17).
    private static let bodyJointNames: [HumanBodyPoseObservation.JointName] = [
        .nose, .leftEye, .rightEye, .leftEar, .rightEar,
        .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
        .leftWrist, .rightWrist, .leftHip, .rightHip,
        .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
    ]

    static func mapBodyPoses(
        _ observations: [HumanBodyPoseObservation],
        width: Int32,
        height: Int32
    ) -> DetectionFrame<PoseDetection> {
        let w = Float(width), h = Float(height)
        let detections = observations.prefix(WireCounts.maxDetections).map { observation in
            let joints = observation.allJoints()
            let points = bodyJointNames.map { name -> WirePoint in
                guard let joint = joints[name], joint.confidence > 0 else {
                    return .missing(frameHeight: h)
                }
                return CoordinateMapper.point(
                    normalizedX: joint.location.x,
                    normalizedY: joint.location.y,
                    confidence: joint.confidence,
                    frameWidth: w,
                    frameHeight: h
                )
            }
            return PoseDetection(confidence: observation.confidence, joints: points)
        }
        return DetectionFrame(width: width, height: height, detections: Array(detections))
    }

    // MARK: - Hands

    /// The 21 joints of the wire format (JointOrder.hand21). Apple names the
    /// fifth finger "little"; the wire format calls it "pinky" (VisionOSC).
    private static let handJointNames: [HumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip
    ]

    static func mapHands(
        _ observations: [HumanHandPoseObservation],
        width: Int32,
        height: Int32
    ) -> DetectionFrame<HandDetection> {
        let w = Float(width), h = Float(height)
        let detections = observations.prefix(WireCounts.maxDetections).map { observation in
            let joints = observation.allJoints()
            let points = handJointNames.map { name -> WirePoint in
                guard let joint = joints[name], joint.confidence > 0 else {
                    return .missing(frameHeight: h)
                }
                return CoordinateMapper.point(
                    normalizedX: joint.location.x,
                    normalizedY: joint.location.y,
                    confidence: joint.confidence,
                    frameWidth: w,
                    frameHeight: h
                )
            }
            return HandDetection(confidence: observation.confidence, joints: points)
        }
        return DetectionFrame(width: width, height: height, detections: Array(detections))
    }

    // MARK: - Faces

    static func mapFaces(
        _ observations: [FaceObservation],
        width: Int32,
        height: Int32
    ) -> DetectionFrame<FaceDetection> {
        let w = Float(width), h = Float(height)
        let detections = observations.prefix(WireCounts.maxDetections).compactMap { observation -> FaceDetection? in
            guard let allPoints = observation.landmarks?.allPoints else { return nil }
            let landmarkPoints = allPoints.points
            guard landmarkPoints.count == WireCounts.facePoints else { return nil }

            let precisions = allPoints.precisionEstimatesPerPoint
            let boundingBox = observation.boundingBox.cgRect

            let points = landmarkPoints.enumerated().map { index, point in
                CoordinateMapper.faceLandmarkPoint(
                    pointInBox: CGPoint(x: point.x, y: point.y),
                    boundingBox: boundingBox,
                    precision: precisions.flatMap { index < $0.count ? Float($0[index]) : nil } ?? observation.confidence,
                    frameWidth: w,
                    frameHeight: h
                )
            }
            return FaceDetection(confidence: observation.confidence, points: points)
        }
        return DetectionFrame(width: width, height: height, detections: Array(detections))
    }

    // MARK: - Text

    static func mapTexts(
        _ observations: [RecognizedTextObservation],
        width: Int32,
        height: Int32
    ) -> DetectionFrame<BoxDetection> {
        let w = Float(width), h = Float(height)
        let detections = observations.prefix(WireCounts.maxDetections).compactMap { observation -> BoxDetection? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return BoxDetection(
                confidence: candidate.confidence,
                box: CoordinateMapper.rect(
                    normalized: observation.boundingBox.cgRect,
                    frameWidth: w,
                    frameHeight: h
                ),
                label: candidate.string
            )
        }
        return DetectionFrame(width: width, height: height, detections: Array(detections))
    }

    // MARK: - Animals

    static func mapAnimals(
        _ observations: [RecognizedObjectObservation],
        width: Int32,
        height: Int32
    ) -> DetectionFrame<BoxDetection> {
        let w = Float(width), h = Float(height)
        let detections = observations.prefix(WireCounts.maxDetections).compactMap { observation -> BoxDetection? in
            guard let label = observation.labels.first else { return nil }
            return BoxDetection(
                confidence: observation.confidence,
                box: CoordinateMapper.rect(
                    normalized: observation.boundingBox.cgRect,
                    frameWidth: w,
                    frameHeight: h
                ),
                label: label.identifier
            )
        }
        return DetectionFrame(width: width, height: height, detections: Array(detections))
    }
}
