//
//  CameraOrientationSetting.swift
//  Poseiosc Sender (shared)
//
//  The user's declared camera orientation. On iOS, Auto follows the interface
//  orientation; on macOS there is no rotating interface, so the Mac sender
//  uses only the fixed options (for rotated external camera rigs). The
//  rawValue degrees are AVFoundation video rotation angles.
//

enum CameraOrientationSetting: Int, CaseIterable, Identifiable {
    case auto = -1
    case portrait = 90
    case landscapeLeft = 0
    case landscapeRight = 180

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .auto: "Auto (follow device)"
        case .portrait: "Portrait"
        case .landscapeLeft: "Landscape Left"
        case .landscapeRight: "Landscape Right"
        }
    }
}
