# Poseiosc

A Swift app for iOS that outputs (almost) all Apple Vision framework detection
results via OSC — body poses, hand poses, face landmarks, text, and animals —
plus a macOS receiver app that visualizes the incoming data, so you can point
your iPhone at the world and watch the tracking arrive on your Mac.

Poseiosc is a native-Swift successor to
[VisionOSC](https://github.com/LingDong-/VisionOSC) by LingDong-
(itself a successor to [PoseOSC](https://github.com/LingDong-/PoseOSC)) and
speaks **exactly the same OSC wire format**, so existing VisionOSC/PoseOSC
receivers (Processing, TouchDesigner, Max/MSP, openFrameworks…) work unchanged.

- **PoseioscSender** (iOS 18+, SwiftUI): live camera → Vision → OSC over UDP,
  with on-screen tracking overlays, per-detector toggles, front/back camera
  switch, and Bonjour discovery of receivers.
- **PoseioscReceiver** (macOS 15+, SwiftUI): listens on UDP (default port
  9527), draws skeletons/landmarks/boxes, shows per-address message rates and
  a log, and advertises itself on the local network so the phone can find it.

Not on the App Store — you build it yourself with a free or paid Apple
developer account.

## Quick start without building anything

- **Mac receiver**: download `PoseioscReceiver-<version>-macOS.zip` from the
  [Releases page](https://github.com/JGL/Poseiosc/releases), unzip, and open.
  The app is signed and notarized, so there are no Gatekeeper hoops — just
  allow the **Local Network** prompt on first launch.
- **iPhone sender**: install via the TestFlight link (ask the maintainer),
  using the free [TestFlight app](https://apps.apple.com/app/testflight/id899247664).

Everything below is only needed if you want to build from source.

## Requirements

- Xcode 16 or newer (with the iOS 18 and macOS 15 SDKs)
- An iPhone running iOS 18 or newer
- A Mac running macOS 15 (Sequoia) or newer
- An [Apple developer account](https://developer.apple.com) (the free tier works)
- iPhone and Mac on the same Wi-Fi network (guest/hotel networks often block
  device-to-device traffic — see Troubleshooting)

All dependencies are Swift Packages resolved automatically by Xcode
([swift-osc](https://swiftpackageindex.com/orchetect/swift-osc) and the local
`PoseioscShared` package). Nothing else to install.

## Building the macOS receiver

1. Open `Poseiosc.xcodeproj` in Xcode.
2. Select the **PoseioscReceiver** scheme, destination **My Mac**.
3. Signing: Xcode may ask you to pick a team — go to the target's
   **Signing & Capabilities** tab and select your team (personal is fine).
4. Run (⌘R).
5. First launch: macOS asks for **Local Network** permission — allow it, or
   the receiver can't be discovered (and on some setups can't receive at all).
   If the macOS firewall prompts about incoming connections, allow those too.

The toolbar shows the listening port (default **9527**) and the Bonjour name
it's advertising. You can change the port and press **Restart**.

## Building the iOS sender

1. In the same project, select the **PoseioscSender** scheme and your iPhone
   as the destination (connect it by cable the first time).
2. In the **PoseioscSender** target's **Signing & Capabilities** tab, select
   your team. If you're building from source (rather than installing via
   TestFlight), also change the bundle identifier prefix
   `com.joelgethinlewis` to something of your own (e.g.
   `com.yourname.poseiosc`) — either in Signing & Capabilities, or by
   editing `bundleIdPrefix` in `project.yml` and running
   `xcodegen generate`.
3. Run (⌘R). With a free developer account the app must be re-signed every
   7 days; paid accounts get a year.
4. On the iPhone, if the app won't launch: **Settings → General →
   VPN & Device Management** → trust your developer certificate.
5. First launch prompts: allow **Camera**, and allow **Local Network**
   (needed both for Bonjour discovery and for sending UDP to your Mac).
   If you decline Local Network by accident: Settings → Privacy & Security →
   Local Network → enable Poseiosc.

## Using it

1. Start the receiver on the Mac.
2. Start the sender on the iPhone. Tap the gear icon — your Mac should appear
   under **Discovered receivers** within a second or two; tap it. (Or type the
   Mac's IP and port manually — the sender can also target TouchDesigner,
   Max/MSP, Processing, etc. on any port.)
3. Point the camera at a person: a skeleton appears on the phone overlay and,
   mirrored live, on the Mac's canvas.
4. Toggle detectors with the chips along the bottom (Body / Hand / Face /
   Text / Animal). More detectors = lower frame rate; body+hand+face is the
   comfortable default. The status capsule shows destination and processed fps.
5. In selfie mode the phone screen shows a mirror image (like the Camera app)
   so it feels natural — but the OSC coordinates sent to receivers are
   **always unmirrored**, matching VisionOSC. Turn the mirror off in
   Settings → Preview if you want the screen to match the receiver exactly.

### Camera orientation

The sender works in portrait **and landscape**. Tracking quality is best when
the declared orientation matches how the camera is actually held, because
Vision then analyzes unrotated frames.

- **Auto (default)**: follows the device as you rotate it; the transmitted
  frame dimensions swap accordingly (e.g. 720×1280 ↔ 1280×720).
- **Portrait / Landscape Left / Landscape Right** (Settings → Camera): locks
  the assumed orientation. Use this when the phone is **mounted** — on a
  tripod, clamped sideways, or lying flat — because automatic detection
  relies on gravity and fails when the phone is flat. If a locked landscape
  preview appears upside down, pick the other landscape option.

The current orientation and dimensions are always broadcast in the
`/camerainfo` OSC message and shown in the sender's status capsule and the
receiver's canvas.

### Testing without an iPhone

The shared package includes two CLI tools (run from `PoseioscShared/`):

```bash
swift run poseiosc-testsend 127.0.0.1 9527
```

sends synthetic animated frames of all message types — point it at the
receiver and you should see a walking stick figure, a waving hand, a face
ring, a "HELLO" text box, and a "Cat" box. Add `--landscape` to send
landscape-oriented frames instead of portrait.

```bash
swift run poseiosc-testlisten 9527
```

is a headless decoder that prints one line per received message (quit the
receiver app first — only one process can bind the port).

## Distributing the iOS sender via TestFlight

If you have a **paid** Apple Developer Program membership, you can put the
sender on TestFlight so testers (e.g. students) install it from a link —
no Xcode needed on their side.

One-time setup:

1. Sign in at [App Store Connect](https://appstoreconnect.apple.com) →
   **Apps → ＋ → New App**: platform iOS, a name (e.g. "Poseiosc"), your
   bundle ID (register it under **Certificates, IDs & Profiles** or let
   Xcode's signing pane register it first), any SKU string.
2. In Xcode, select the **PoseioscSender** scheme with your team set.

Per release:

1. Bump `CURRENT_PROJECT_VERSION` in `project.yml` (every upload needs a
   higher build number) and run `xcodegen generate` — or edit the build
   number in Xcode's target General tab.
2. Select destination **Any iOS Device (arm64)** → **Product → Archive**.
3. In the Organizer window: **Distribute App → TestFlight & App Store →
   Upload** (accept the defaults).
4. In App Store Connect → your app → **TestFlight** tab: wait a few minutes
   for processing, then either
   - add **Internal Testers** (up to 100 App Store Connect users — instant), or
   - create an **External** group and enable a **public link** (up to 10,000
     testers — ideal for a class; the first build needs a one-off Beta App
     Review, usually a day or two).
5. Testers install the **TestFlight** app from the App Store and open your
   public link on the iPhone. Builds expire after 90 days — upload a new one
   before term ends!

The project already sets `ITSAppUsesNonExemptEncryption` to false (the app
contains no custom cryptography), so uploads skip the export-compliance
question.

## Releasing the receiver (maintainers)

`Scripts/release-receiver.sh` archives the macOS receiver, signs it with your
Developer ID, notarizes and staples it, and publishes the zip as a GitHub
Release — so end users can download and double-click with no Gatekeeper
friction.

One-time setup:

1. A **Developer ID Application** certificate: Xcode → Settings → Accounts →
   your team → Manage Certificates → ＋.
2. Notary credentials in your keychain (use an
   [app-specific password](https://appleid.apple.com)):

```bash
xcrun notarytool store-credentials poseiosc-notary --apple-id you@example.com --team-id YOURTEAMID --password your-app-specific-password
```

3. The [GitHub CLI](https://cli.github.com) authenticated (`gh auth login`).

Then, per release — bump `MARKETING_VERSION` in `project.yml`, run
`xcodegen generate`, commit, and:

```bash
POSEIOSC_TEAM_ID=YOURTEAMID Scripts/release-receiver.sh
```

Add `--dry-run` to build/notarize without publishing.

## Coordinate system

Everything on the wire uses one convention — the same one VisionOSC uses:

```
(0,0) ──────────► x                width
  │  ┌───────────────────────────────┐
  │  │                               │
  ▼  │        pixels, y down         │ height
  y  │                               │
     └───────────────────────────(w,h)
```

- **Pixels**, not normalized: divide by the frame width/height from the
  message header (or `/camerainfo`) to normalize.
- **Origin top-left, y grows downward** (screen convention, not math
  convention).
- **Never mirrored.** The selfie-mirror option only flips the phone's
  *display*; wire coordinates are always the unmirrored scene.
- **Dimensions follow orientation**: portrait sends 720×1280, landscape
  1280×720. Listen to `/camerainfo` and your mapping code needs no
  special-casing:

```java
// Processing: map a Poseiosc point into your sketch window
float sx = x / frameW * width;   // frameW/frameH from the message header
float sy = y / frameH * height;
```

- A keypoint that wasn't detected arrives as `x=0, y=frameHeight,
  confidence=0` — always filter on `confidence == 0`.

## OSC wire format

Byte-compatible with VisionOSC. All messages are sent unbundled over UDP, one
per enabled detector per processed frame, **including when nothing is
detected** (header-only). Coordinates are as described above.

**`/camerainfo`** (Poseiosc addition; VisionOSC receivers ignore it) —
sent with every processed frame:

| # | Type | Value |
|---|------|-------|
| 0 | int32 | frame width in pixels |
| 1 | int32 | frame height in pixels |
| 2 | int32 | orientation: 0 = landscape, 90 = portrait, 180 = landscape flipped, 270 = portrait upside-down |
| 3 | int32 | camera facing: 0 = back, 1 = front |

Every message begins with the same header:

| # | Type | Value |
|---|------|-------|
| 0 | int32 | frame width (oriented pixels, e.g. 720) |
| 1 | int32 | frame height (e.g. 1280) |
| 2 | int32 | number of detections `n` (capped at 32) |

Then, per detection:

**`/poses/arr`** — `float` confidence, then 17 joints × (`float` x, `float` y,
`float` confidence). Joint order (PoseNet order): nose, leftEye, rightEye,
leftEar, rightEar, leftShoulder, rightShoulder, leftElbow, rightElbow,
leftWrist, rightWrist, leftHip, rightHip, leftKnee, rightKnee, leftAnkle,
rightAnkle.

**`/hands/arr`** — `float` confidence, then 21 joints × (x, y, confidence).
Order: wrist; thumb CMC, MP, IP, tip; index MCP, PIP, DIP, tip; middle …;
ring …; pinky … .

**`/faces/arr`** — `float` confidence, then 76 landmark points ×
(x, y, precisionEstimate), in Vision's constellation order.

**`/texts/arr`** — `float` confidence, `float` left, `float` top,
`float` width, `float` height, `string` recognized text.

**`/animals/arr`** — `float` confidence, `float` left, `float` top,
`float` width, `float` height, `string` label (`"Cat"` or `"Dog"`).

A joint/point that wasn't detected is sent as `x=0, y=frameHeight,
confidence=0` (VisionOSC's convention) — filter on `confidence == 0`.

## Project layout

```
project.yml            XcodeGen spec (source of truth for the Xcode project)
Poseiosc.xcodeproj     Generated project (committed; users just open it)
PoseioscShared/        Swift package: wire format codec, models, skeleton
                       edge lists, coordinate mapping, CLI test tools, tests
Sender/                iOS app (camera, Vision pipeline, overlays, Bonjour browse)
Receiver/              macOS app (OSC server, visualizer, log, Bonjour advertise)
PROMPTS_AND_DECISIONS.md   Running record of prompts and design decisions
```

Contributing: source files added/removed? Run `brew install xcodegen` once,
then `xcodegen generate` and commit both `project.yml` and the regenerated
project. Wire-format changes must keep the golden-bytes test in
`PoseioscShared/Tests` green — that test *is* the VisionOSC compatibility
contract. Run tests with `cd PoseioscShared && swift test`.

## Troubleshooting

- **Receiver never appears on the phone** — both devices on the same Wi-Fi?
  Many guest/campus/hotel networks enable *client isolation*, which blocks
  device-to-device traffic entirely; use a private network or a personal
  hotspot. Check Local Network permission on **both** devices, and that the
  Mac's firewall allowed PoseioscReceiver. Verify the Mac is advertising:
  `dns-sd -B _osc._udp local.`
- **Discovered receiver won't resolve** — enter the Mac's IP manually
  (System Settings → Wi-Fi → Details → IP address).
- **Data sends but nothing draws** — confirm the port matches the receiver
  toolbar; check the receiver's total-message counter is climbing.
- **Overlay/receiver skeleton is rotated or flipped** — the sender assumes a
  portrait phone; keep the phone upright. (If it's still wrong on your device,
  please open an issue naming the iPhone model.)
- **Low frame rate** — disable Text/Animal (they're the slow ones), good
  lighting helps every detector.
- **Port 9527 already in use** — Protokol, OSC DataMonitor, or another
  receiver may be bound to it; only one process can listen per port.

## Lineage & license

Inspired by [VisionOSC](https://github.com/LingDong-/VisionOSC) and
[PoseOSC](https://github.com/LingDong-/PoseOSC) by LingDong-, which grew out
of [ofxFaceTracker](https://github.com/kylemcdonald/ofxFaceTracker) by Kyle
McDonald. OSC via [swift-osc](https://github.com/orchetect/swift-osc) by
Steffan Andrews.

MIT — see [LICENSE](LICENSE).
