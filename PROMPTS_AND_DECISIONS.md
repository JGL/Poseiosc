# Poseiosc — Prompts and Decisions

A running record of the prompts that drove this project and the technical
decisions made along the way, as requested in the original brief.

## Original prompt (2026-07-28)

> This is a project inspired by: https://github.com/LingDong-/VisionOSC which
> was inspired by: https://github.com/LingDong-/PoseOSC which was inspired by
> https://github.com/kylemcdonald/ofxFaceTracker/releases. I'd like you to make
> a new iOS app that uses SwiftUI for the interface, the Vision framework
> (https://developer.apple.com/documentation/vision) for computer vision and
> https://github.com/orchetect/swift-osc as the OSC library. As well as an iOS
> "sender" app, I'd also like you to build a macOS "receiver" app, so that
> users can download and build the app for their iPhone but then show that is
> working on a macOS device on the same wifi network. I'd like you to make sure
> to record all prompts and decisions in a Markdown file, as well as updating
> README.md to make it easy for users to set up on their own iPhone/macOS
> systems. The plan isn't to release on the iOS and macOS app stores as yet,
> just to begin with users that have their own developer.apple.com licenses,
> building on their own machines. I'd like you to copy the formating of OSC
> messages from the https://github.com/LingDong-/VisionOSC project, as well as
> its functionality - tracking body poses, face poses, hand poses, animal poses
> and text. I think the best idea is to start with a plan.

Follow-up instruction: all external libraries must be consumed as Swift
Packages via Swift Package Manager (as listed on Swift Package Index), never
vendored or manually downloaded.

## Decisions made with the user (planning phase)

1. **Vision API generation: the new Swift-only API (iOS 18+ / macOS 15+).**
   The modern async/await Vision API (`DetectHumanBodyPoseRequest` etc.) was
   chosen over the legacy `VNRequest` API that VisionOSC itself uses. Cleaner
   Swift 6 code; iOS 18 adoption is high. Trade-off: older iPhones can't run it.

2. **Discovery: Bonjour + manual fallback.** The macOS receiver advertises
   `_osc._udp` via Bonjour; the iOS app lists discovered receivers and also
   accepts a manually typed host/port (which lets it target TouchDesigner,
   Max/MSP, Processing, etc. directly).

3. **Receiver UI: visualizer + message log.** The macOS app draws received
   skeletons/landmarks/boxes on a canvas scaled from the transmitted frame
   dimensions, plus per-address message rates and a sampled log.

## Wire format decisions (VisionOSC byte-compatibility)

The OSC format was reverse-engineered from the VisionOSC source
(`src/ofApp.cpp`, `src/constants.h`, `src/*.mm`), not its README (which omits
the leading slash on addresses; the code is authoritative).

- Addresses: `/poses/arr`, `/hands/arr`, `/faces/arr`, `/texts/arr`,
  `/animals/arr`. Messages are unbundled, sent per enabled detector per
  processed frame — including when zero detections (header-only message).
- Every message starts `int32 width, int32 height, int32 count`, followed per
  detection by the payloads documented in README.md.
- **Coordinates are pixels, origin top-left** (`y = (1 − visionY) × height`),
  unmirrored. Vision's normalized bottom-left coordinates are converted in
  `PoseioscShared/Sources/PoseioscShared/CoordinateMapper.swift`.
- **Body joint order is PoseNet order** (nose, eyes, ears, shoulders, elbows,
  wrists, hips, knees, ankles — left before right), NOT the order Vision
  returns. Hand order is wrist, then thumb→pinky, 4 joints per finger
  (Apple's "little" finger = VisionOSC's "pinky").
- **Face**: 76 landmark points in Vision's own constellation order. Vision
  provides them normalized to the face bounding box, so they are double-mapped
  into image pixels exactly as VisionOSC does. The per-point third value is
  the precision estimate (not confidence), falling back to the observation
  confidence if Vision omits estimates.
- **Missing joints** are sent as `(0, frameHeight, 0)` — the exact values
  VisionOSC emits (vision-space origin run through the y-flip). Consumers
  filter on `confidence == 0`.
- **Animals** uses `RecognizeAnimalsRequest` (bounding box + "Cat"/"Dog"
  label), matching VisionOSC's animal *detection* — not animal body pose.
- **OSC types are strictly int32/float32/string**, pinned by a golden-bytes
  unit test that asserts the raw packet encoding (type tags, big-endian
  layout) so drift from VisionOSC compatibility fails CI-style.
- VisionOSC bugs deliberately **not** replicated: its detection counter wraps
  to 0 at exactly 32 bodies/hands (`n_det = (n_det+1) % MAX_DET`), and its
  face/text/animal arrays are unbounded. Poseiosc caps all detection lists at
  32 cleanly.

## Architecture decisions

- **One Xcode project, two app targets, one shared local Swift package.**
  `PoseioscShared` holds the wire format (models, codec, skeleton edge lists,
  coordinate mapping) so the sender's encoder and receiver's decoder cannot
  drift apart, plus two CLI tools (`poseiosc-testsend`, `poseiosc-testlisten`)
  that allow full end-to-end testing without an iPhone.
- **XcodeGen generates the project.** `project.yml` is the source of truth;
  the generated `Poseiosc.xcodeproj` is committed so end users only need
  Xcode. Contributors adding files run `xcodegen generate`.
- **Dependencies via SPM only**: [swift-osc](https://swiftpackageindex.com/orchetect/swift-osc)
  `from: 3.1.0` (which pulls swift-osc-core and the SwiftNIO-based
  swift-osc-io-nio). No vendored code.
- **Signing**: `CODE_SIGN_STYLE = Automatic` with an intentionally empty
  `DEVELOPMENT_TEAM` — each user selects their own team in Xcode.

### iOS sender pipeline

- `AVCaptureVideoDataOutput` at 720p, `alwaysDiscardsLateVideoFrames`, buffers
  delivered sensor-native (no pixel rotation). Vision is told the buffer
  orientation instead: `.right` for **both** cameras in the portrait-locked
  UI. (Initially the front camera was assumed to need `.left`; on-device
  testing 2026-07-28 showed all front-camera detections rotated 180°, so both
  sensors are mounted identically and `.right` is correct everywhere.)
  Transmitted frame dimensions are the *oriented* dims (e.g. 720×1280).
- The sender defaults to the **front (selfie) camera** on first launch —
  pointing the phone at yourself is the natural first test.
- **Selfie-mirror option** (user request after on-device testing, default ON):
  in front-camera mode the preview is flipped with a display transform and the
  overlay flips its own x-coordinates (keeping label text readable), so the
  screen feels like a mirror. Strictly display-only — OSC output remains
  unmirrored regardless of the toggle (Settings → Preview).
- **Frame policy: latest-frame-wins.** One Vision batch in flight; newer
  frames overwrite a single pending slot (`FrameConveyor`). Latency stays
  bounded when all five detectors run.
- **Detectors run concurrently per frame** (async let inside
  `VisionProcessor`); each request's OSC message is sent as soon as that
  request completes, matching VisionOSC's per-request cadence.
- **Front camera preview and data are unmirrored** (preview mirroring
  disabled) so preview, overlay, and OSC coordinates all agree with
  VisionOSC's unmirrored convention. The selfie preview therefore looks
  "un-selfie-like" — deliberate. Implementation note (found on device
  2026-07-28): the preview layer's connection doesn't exist until the session
  has inputs and is recreated — with mirroring re-enabled by default — on
  every camera switch, so disabling mirroring from the SwiftUI view was
  ineffective. `CameraManager` owns the preview layer and re-disables
  mirroring inside every session reconfiguration instead.
- **Text recognition uses `.fast`** level, prioritizing frame rate, matching
  VisionOSC's philosophy (its text detector ran ~10 fps).
- The new Vision API has **no constellation setting** for face landmarks
  (revision 3 always yields 76 points) — discovered at build time; the
  request is used as-is and the mapper asserts the 76-point count.
- Default detector toggles: body/hand/face ON, text/animal OFF (running all
  five at once costs frame rate, as VisionOSC's README also notes).

### macOS receiver

- SwiftOSC's `OSCUDPServer` owns the UDP socket (default port 9527 —
  VisionOSC's default). Bonjour advertising therefore uses the **`dnssd` C API
  (`DNSServiceRegister`)**, which registers the mDNS record without needing to
  own the socket. `NetService` would work but is deprecated; an `NWListener`
  can't bind the same port.
- Receiver is sandboxed with `network.server` + `network.client` entitlements.
- The OSC handler can fire hundreds of times per second, so decoded frames are
  accumulated behind a lock and the SwiftUI model pulls snapshots at 30 Hz;
  the log samples at most one entry per address per 250 ms.
- Frames older than 0.5 s are dropped from the canvas (sender stopped or
  detector toggled off).

## Networking fixes from on-device testing (2026-07-28)

- Bonjour tap-to-select reported "could not resolve" even though the
  advertisement was correct (`dns-sd -L` showed `MB-C4654-2.local.:9527`).
  Two bugs in the sender's resolver: (1) after a successful resolve it
  cancelled the throwaway connection, and the resulting `.cancelled` state
  fired the completion a second time with `nil`, surfacing the error UI;
  (2) no result pinning to IPv4 — the receiver's OSC server binds IPv4-only
  (SwiftOSC default), so an IPv6/link-local resolution would silently fail.
  Rewritten as a one-shot async resolve with a 4-second timeout and forced
  IPv4.

## App icons (2026-07-28)

- Both icons show a waving pose-skeleton (green joints/limbs, echoing the
  overlay colors) emitting cyan signal arcs from the raised hand — pose
  tracking + OSC broadcast in one image. iOS gets the full-bleed square;
  macOS gets the same art inside the traditional margin + squircle + shadow.
- Icons are rendered programmatically with CoreGraphics —
  `Design/render_icons.swift` regenerates both 1024px masters
  (`swift Design/render_icons.swift <outputDir>`), and `sips` downscales the
  macOS size set. No binary-only design sources.

## v1.1 — Beta feedback round from Golan Levin (2026-07-29)

Golan's TestFlight feedback (paraphrased): (1) wants a software option to
declare the expected camera orientation — trackers do much better without a
90° rotation to compensate — and the OSC should communicate orientation and
dimensions; (2) uses LingDong-'s Processing receiver because he has no Xcode
toolchain, suggested forking it; (3) general coordinate friction (orientation,
the mirror option, unknown dimensions — he reported a puzzling "2436×1126").

Decisions (with Joel):

- **Orientation**: auto-rotating UI via `AVCaptureDevice.RotationCoordinator`
  plus a manual lock (Portrait/Landscape Left/Landscape Right) in Settings.
  The lock exists because gravity-based auto-detection fails when the phone
  is mounted flat — precisely the installation rig case. Locked mode also
  drives the preview rotation, so a mounted phone previews upright.
  Angle → Vision mapping extends the verified portrait case (90° = .right;
  0 = .up, 180 = .down, 270 = .left) — to be confirmed on device.
- **`/camerainfo` message** (additive; VisionOSC receivers ignore unknown
  addresses): `int32 width, height, orientationDegrees (0/90/180/270),
  facing (0 back / 1 front)`, sent every processed frame. Pinned by its own
  golden-bytes test. The five VisionOSC messages are untouched.
- **Distribution**: rather than forking the Processing receiver, the macOS
  receiver is distributed as a **signed + notarized** zip on GitHub Releases
  (`Scripts/release-receiver.sh`: archive → Developer ID export → notarytool
  → staple → `gh release create`). Notarization chosen over unsigned-zip +
  quarantine-removal instructions: zero Gatekeeper friction for students.
  Local script now; a GitHub Actions workflow (needs cert + ASC API key as
  repo secrets) can come later.
- **Coordinate friction**: README gains a coordinate-system section with
  diagram and Processing snippet; the receiver canvas draws origin/axes/dims/
  orientation; the sender status capsule shows the transmitted dims. A
  normalized-coordinates mode was considered and **rejected** (diverges from
  VisionOSC's format).
- Golan's "2436×1126" doesn't match any capture format we request (720p);
  with dims now visible on sender, receiver, and wire, he can re-check —
  if a device really reports it, investigate session-preset fallback then.
- Versions bumped to 1.1.0 (build 2), now shared project-wide settings.

### v1.1 on-device fix round (2026-07-29)

Joel's first device test: portrait-locked selfie showed the overlay (and the
receiver's skeleton) rotated 90°, with the status capsule reading 1280×720 —
i.e. the lock never reached the capture pipeline; Vision analyzed frames as
landscape while the preview correctly displayed portrait. The lock value had
flowed through cached state + KVO callbacks, where a race could leave the
default landscape angle in place. Fixes:

- The orientation lock is now read **directly in the frame callback** — with
  a lock set, no callback ordering can produce a wrong angle.
- Auto mode caches `videoRotationAngleForHorizonLevelCapture` (not the
  *preview* angle, which can differ for the front camera) via KVO; the
  rotation coordinator is created on the main thread (it observes a CALayer).
- When the camera orientation is locked, the **interface orientation is
  locked to match** (UIApplicationDelegate mask + `requestGeometryUpdate`),
  so the UI can't rotate out from under a locked capture configuration.
- Settings → Statistics now shows the live transmitted frame description
  ("720×1280 · 90° portrait") for at-a-glance diagnosis.

### v1.1 second fix round (2026-07-29)

Joel's retest (screenshots): still 1280×720 landscape in upright portrait
with the system rotation lock on; the in-app orientation picker reportedly
wouldn't change; Mac receiver confirmed landscape data. Simulator
reproduction showed the picker working in the current build, pointing at the
rotation coordinator as the remaining fault: its gravity-fed angles can sit
at 0° (notably with the system rotation lock suppressing orientation
events).

**Decision: drop `AVCaptureDevice.RotationCoordinator` entirely.** Auto mode
now derives the angle from the **interface orientation** (read from the
window scene on every root-view size change): portrait 90°, landscapeRight
0°, landscapeLeft 180°, upside-down 270°. The same value drives the preview
connection rotation and the per-frame Vision interpretation, so what is on
screen and what is sent cannot disagree by construction. With the system
rotation lock on, the UI stays portrait and so does the data — the correct
outcome. Flat-mounted rigs use the manual lock as designed. Settings →
Statistics gained an "App version" row (e.g. "1.1.0 (3)") to make
which-binary-is-this unambiguous during test rounds; build bumped to 3.

### v1.1 third fix round (2026-07-29)

Joel's retest with build 3: data pipeline fully correct (720×1280 portrait
everywhere, receiver perfect, overlay registered) but the sender's *video*
displayed rotated 90° — the explicit `videoRotationAngle` write on the
preview connection did not take effect on device, despite carrying the
correct value.

**Decision: never touch the preview connection's rotation.** Its default
renders upright portrait — verified across every build since v1.0. For
non-portrait orientations the preview is counter-rotated in SwiftUI view
space instead (`rotationEffect` + swapped framing so aspect-fill still covers
the screen); in portrait this applies no transform at all, i.e. exactly the
historically-verified path. Build bumped to 4.

### v1.1 fourth fix round (2026-07-29)

Build 4 on device: portrait fully correct (video, overlay, receiver, mirror
toggle behavior all verified by Joel). Both landscape directions showed video
and overlay consistent with each other but 180° from reality — the tell that
the pipeline was self-consistent and only the interface→angle mapping had
the two landscape cases swapped (Apple's device vs interface landscape
naming crosses over: a device rotated anticlockwise reports interface
.landscapeRight). Fixed: .landscapeRight → 180°, .landscapeLeft → 0°.
Build 5.

## Verification record (2026-07-28)

- `swift test` in `PoseioscShared`: 18 tests green, including round-trips for
  all five message types, malformed-input handling, and the golden-bytes
  encoding test.
- `xcodebuild` clean for both schemes (`PoseioscSender` generic/iOS with
  signing disabled; `PoseioscReceiver` macOS).
- End-to-end on loopback: `poseiosc-testsend` → receiver GUI (animated
  skeleton/hand/face/text/animal rendering confirmed) and → 
  `poseiosc-testlisten` (decoded output verified textually).
- Bonjour: `dns-sd -B _osc._udp local.` shows
  `Poseiosc Receiver (<hostname>)` while the receiver runs.
- On-device iPhone test: pending user hardware (see README checklist).
