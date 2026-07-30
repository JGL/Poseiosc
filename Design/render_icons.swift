// Renders the Poseiosc app icons: a pose skeleton emitting OSC arcs.
// Usage: swift render_icons.swift <outputDir>

import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let size = 1024

// Design-space colors. The receiver uses the blue background; both sender
// apps (iOS and macOS) use the plum variant so sender and receiver are distinct.
var bgTop = NSColor(calibratedRed: 0.05, green: 0.09, blue: 0.13, alpha: 1)
var bgBottom = NSColor(calibratedRed: 0.08, green: 0.19, blue: 0.27, alpha: 1)
let senderBgTop = NSColor(calibratedRed: 0.09, green: 0.05, blue: 0.15, alpha: 1)
let senderBgBottom = NSColor(calibratedRed: 0.21, green: 0.11, blue: 0.32, alpha: 1)
let limbGreen = NSColor(calibratedRed: 0.19, green: 0.82, blue: 0.35, alpha: 1)
let jointGreen = NSColor(calibratedRed: 0.55, green: 0.95, blue: 0.55, alpha: 1)
let arcCyan = NSColor(calibratedRed: 0.39, green: 0.82, blue: 1.0, alpha: 1)

func makeContext(_ pixels: Int) -> CGContext {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // Flip so design coordinates are top-left origin.
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func fillBackground(_ ctx: CGContext, rect: CGRect, rounded radius: CGFloat) {
    ctx.saveGState()
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [bgTop.cgColor, bgBottom.cgColor] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.midX, y: rect.minY),
        end: CGPoint(x: rect.midX, y: rect.maxY),
        options: []
    )
    ctx.restoreGState()
}

enum ArtMode {
    case sending    // arcs radiate outward from the raised hand
    case receiving  // arcs arrive from beyond the corner, with an inbound arrow
}

var artMode = ArtMode.sending

/// Draws the figure + arcs. `rect` is where the 0-1024 design space lands.
func drawArt(_ ctx: CGContext, rect: CGRect) {
    let s = rect.width / 1024.0
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
    }

    // Waving stick figure. Right arm raised toward the signal arcs.
    let neck = pt(430, 350)
    let lShoulder = pt(330, 395), rShoulder = pt(530, 380)
    let lElbow = pt(285, 545), rElbow = pt(625, 300)
    let lWrist = pt(262, 690), rWrist = pt(700, 185)
    let lHip = pt(370, 660), rHip = pt(495, 660)
    let lKnee = pt(330, 810), rKnee = pt(545, 805)
    let lAnkle = pt(315, 950), rAnkle = pt(590, 945)
    let headCenter = pt(430, 245)

    let limbs: [(CGPoint, CGPoint)] = [
        (neck, lShoulder), (neck, rShoulder),
        (lShoulder, lElbow), (lElbow, lWrist),
        (rShoulder, rElbow), (rElbow, rWrist),
        (lShoulder, lHip), (rShoulder, rHip), (lHip, rHip),
        (lHip, lKnee), (lKnee, lAnkle),
        (rHip, rKnee), (rKnee, rAnkle)
    ]

    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Limbs
    ctx.setStrokeColor(limbGreen.cgColor)
    ctx.setLineWidth(34 * s)
    for (a, b) in limbs {
        ctx.move(to: a)
        ctx.addLine(to: b)
    }
    ctx.strokePath()

    // Head
    ctx.setLineWidth(34 * s)
    ctx.strokeEllipse(in: CGRect(
        x: headCenter.x - 68 * s, y: headCenter.y - 68 * s,
        width: 136 * s, height: 136 * s
    ))

    // Joint dots
    ctx.setFillColor(jointGreen.cgColor)
    let joints = [neck, lShoulder, rShoulder, lElbow, rElbow, lWrist, rWrist,
                  lHip, rHip, lKnee, rKnee, lAnkle, rAnkle]
    for joint in joints {
        let r = 27 * s
        ctx.fillEllipse(in: CGRect(x: joint.x - r, y: joint.y - r, width: r * 2, height: r * 2))
    }

    switch artMode {
    case .sending:
        // OSC signal arcs radiating from the raised wrist toward the corner.
        for (index, radius) in [95.0, 155.0, 215.0].enumerated() {
            ctx.setStrokeColor(arcCyan.withAlphaComponent(1.0 - CGFloat(index) * 0.28).cgColor)
            ctx.setLineWidth(26 * s)
            // Angles in flipped (top-left) space: arc opening up-right.
            ctx.addArc(
                center: rWrist, radius: radius * s,
                startAngle: -0.25 * .pi, endAngle: -0.75 * .pi,
                clockwise: true
            )
            ctx.strokePath()
        }

    case .receiving:
        // Waves arriving from a source beyond the top-right corner: arcs
        // centered out there, bowing toward the figure, strongest nearest
        // the hand, plus an inbound arrow.
        let source = pt(1050, -110)
        let towardWrist = atan2(rWrist.y - source.y, rWrist.x - source.x)
        for (index, radius) in [420.0, 340.0, 260.0].enumerated() {
            ctx.setStrokeColor(arcCyan.withAlphaComponent(0.44 + CGFloat(index) * 0.28).cgColor)
            ctx.setLineWidth(26 * s)
            ctx.addArc(
                center: source, radius: radius * s,
                startAngle: towardWrist - 0.22 * .pi,
                endAngle: towardWrist + 0.22 * .pi,
                clockwise: false
            )
            ctx.strokePath()
        }

        // Arrow flying in along the wave direction, tip near the hand.
        let tip = pt(760, 128)
        let tail = CGPoint(
            x: tip.x - cos(towardWrist) * 150 * s,
            y: tip.y - sin(towardWrist) * 150 * s
        )
        ctx.setStrokeColor(arcCyan.cgColor)
        ctx.setLineWidth(30 * s)
        ctx.move(to: tail)
        ctx.addLine(to: tip)
        for side in [towardWrist + .pi * 0.8, towardWrist - .pi * 0.8] {
            ctx.move(to: tip)
            ctx.addLine(to: CGPoint(
                x: tip.x + cos(side) * 62 * s,
                y: tip.y + sin(side) * 62 * s
            ))
        }
        ctx.strokePath()
    }
}

func writePNG(_ image: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

// macOS: Big Sur-style squircle with margin on transparent canvas.
func renderMacIcon(filename: String) {
    let macCtx = makeContext(size)
    let squircle = CGRect(x: 100, y: 100, width: 824, height: 824)
    // Soft shadow under the squircle for the traditional mac look.
    macCtx.saveGState()
    macCtx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24,
                     color: NSColor.black.withAlphaComponent(0.35).cgColor)
    macCtx.setFillColor(bgBottom.cgColor)
    macCtx.addPath(CGPath(roundedRect: squircle, cornerWidth: 185, cornerHeight: 185, transform: nil))
    macCtx.fillPath()
    macCtx.restoreGState()
    fillBackground(macCtx, rect: squircle, rounded: 185)
    macCtx.saveGState()
    macCtx.addPath(CGPath(roundedRect: squircle, cornerWidth: 185, cornerHeight: 185, transform: nil))
    macCtx.clip()
    drawArt(macCtx, rect: squircle.insetBy(dx: 30, dy: 30))
    macCtx.restoreGState()
    writePNG(macCtx.makeImage()!, to: "\(outputDir)/\(filename)")
}

// Receiver icon: blue background, INBOUND waves + arrow.
artMode = .receiving
renderMacIcon(filename: "AppIcon-macOS-1024.png")

// Mac sender icon: plum background, outbound waves.
artMode = .sending
bgTop = senderBgTop
bgBottom = senderBgBottom
renderMacIcon(filename: "AppIcon-macOS-sender-1024.png")

// iOS sender icon: same plum palette, full-bleed square (system applies its own mask).
let iosCtx = makeContext(size)
fillBackground(iosCtx, rect: CGRect(x: 0, y: 0, width: size, height: size), rounded: 0)
drawArt(iosCtx, rect: CGRect(x: 0, y: 0, width: size, height: size))
writePNG(iosCtx.makeImage()!, to: "\(outputDir)/AppIcon-iOS-1024.png")
