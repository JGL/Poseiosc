//
//  PoseioscSenderApp.swift
//  Poseiosc Sender (iOS)
//
//  Live camera → Apple Vision detections → OSC, in the VisionOSC wire format.
//

import SwiftUI

/// Exists to constrain interface rotation: when the user locks the camera
/// orientation, the UI is locked to match, so the interface can never rotate
/// out from under a locked capture configuration.
final class SenderAppDelegate: NSObject, UIApplicationDelegate {
    static let orientationMask = OSAllocatedUnfairLockedMask()

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationMask.value
    }
}

/// Tiny thread-safe holder (the delegate callback can arrive off-main).
final class OSAllocatedUnfairLockedMask: @unchecked Sendable {
    private let lock = NSLock()
    private var mask: UIInterfaceOrientationMask = .allButUpsideDown

    var value: UIInterfaceOrientationMask {
        get { lock.withLock { mask } }
        set { lock.withLock { mask = newValue } }
    }
}

@main
struct PoseioscSenderApp: App {
    @UIApplicationDelegateAdaptor(SenderAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
