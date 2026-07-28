//
//  OverlayView.swift
//  Poseiosc Sender (iOS)
//
//  Draws the latest detections over the camera preview. Wire coordinates are
//  pixels in the oriented frame; the preview uses aspect-fill, so the same
//  scale/offset math is applied here to keep the overlay registered.
//

import SwiftUI
import PoseioscShared

struct OverlayView: View {
    let snapshot: OverlaySnapshot

    var body: some View {
        Canvas { context, size in
            guard snapshot.width > 0, snapshot.height > 0 else { return }
            let frameW = CGFloat(snapshot.width)
            let frameH = CGFloat(snapshot.height)

            // Aspect-fill: scale up so the frame covers the view, centered.
            let scale = max(size.width / frameW, size.height / frameH)
            let offsetX = (size.width - frameW * scale) / 2
            let offsetY = (size.height - frameH * scale) / 2

            func map(_ p: WirePoint) -> CGPoint {
                CGPoint(x: offsetX + CGFloat(p.x) * scale, y: offsetY + CGFloat(p.y) * scale)
            }
            func map(_ r: WireRect) -> CGRect {
                CGRect(
                    x: offsetX + CGFloat(r.left) * scale,
                    y: offsetY + CGFloat(r.top) * scale,
                    width: CGFloat(r.width) * scale,
                    height: CGFloat(r.height) * scale
                )
            }

            for pose in snapshot.poses {
                drawSkeleton(context: context, points: pose.joints, edges: Skeleton.body17Edges, color: .green, map: map)
            }
            for hand in snapshot.hands {
                drawSkeleton(context: context, points: hand.joints, edges: Skeleton.hand21Edges, color: .orange, map: map)
            }
            for face in snapshot.faces {
                for point in face.points where point.confidence > 0 {
                    let p = map(point)
                    context.fill(
                        Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)),
                        with: .color(.cyan)
                    )
                }
            }
            drawBoxes(context: context, boxes: snapshot.texts, color: .yellow, map: map)
            drawBoxes(context: context, boxes: snapshot.animals, color: .pink, map: map)
        }
        .allowsHitTesting(false)
    }

    private func drawSkeleton(
        context: GraphicsContext,
        points: [WirePoint],
        edges: [(Int, Int)],
        color: Color,
        map: (WirePoint) -> CGPoint
    ) {
        var path = Path()
        for (a, b) in edges {
            guard a < points.count, b < points.count else { continue }
            let pa = points[a], pb = points[b]
            guard pa.confidence > 0, pb.confidence > 0 else { continue }
            path.move(to: map(pa))
            path.addLine(to: map(pb))
        }
        context.stroke(path, with: .color(color), lineWidth: 2)
        for point in points where point.confidence > 0 {
            let p = map(point)
            context.fill(
                Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)),
                with: .color(color.opacity(0.9))
            )
        }
    }

    private func drawBoxes(
        context: GraphicsContext,
        boxes: [BoxDetection],
        color: Color,
        map: (WireRect) -> CGRect
    ) {
        for box in boxes {
            let rect = map(box.box)
            context.stroke(Path(rect), with: .color(color), lineWidth: 2)
            let label = Text(box.label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
            context.draw(label, at: CGPoint(x: rect.minX + 4, y: max(rect.minY - 10, 8)), anchor: .leading)
        }
    }
}
