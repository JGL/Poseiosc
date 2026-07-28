//
//  VisualizerView.swift
//  Poseiosc Receiver (macOS)
//
//  Draws the most recent frame of each kind on a canvas, letterboxed to the
//  frame dimensions carried in the OSC messages. Uses the shared Skeleton edge
//  lists so geometry matches the iOS sender's overlay exactly.
//

import SwiftUI
import PoseioscShared

struct VisualizerView: View {
    var model: ReceiverModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

                let now = Date.now
                let fresh = model.latest.filter {
                    now.timeIntervalSince($0.value.receivedAt) < ReceiverModel.staleInterval
                }

                guard let reference = fresh.values.first else {
                    drawPlaceholder(context: context, size: size)
                    return
                }

                let (frameW, frameH) = frameDimensions(of: reference.decoded)
                guard frameW > 0, frameH > 0 else { return }

                // Aspect-fit the sent frame into the view.
                let scale = min(size.width / CGFloat(frameW), size.height / CGFloat(frameH))
                let offsetX = (size.width - CGFloat(frameW) * scale) / 2
                let offsetY = (size.height - CGFloat(frameH) * scale) / 2

                // Frame outline
                let frameRect = CGRect(x: offsetX, y: offsetY, width: CGFloat(frameW) * scale, height: CGFloat(frameH) * scale)
                context.stroke(Path(frameRect), with: .color(.gray.opacity(0.5)), lineWidth: 1)

                func mapPoint(_ p: WirePoint) -> CGPoint {
                    CGPoint(x: offsetX + CGFloat(p.x) * scale, y: offsetY + CGFloat(p.y) * scale)
                }
                func mapRect(_ r: WireRect) -> CGRect {
                    CGRect(
                        x: offsetX + CGFloat(r.left) * scale,
                        y: offsetY + CGFloat(r.top) * scale,
                        width: CGFloat(r.width) * scale,
                        height: CGFloat(r.height) * scale
                    )
                }

                for (kind, frame) in fresh {
                    switch frame.decoded {
                    case .poses(let f):
                        for pose in f.detections {
                            drawSkeleton(
                                context: context, points: pose.joints, edges: Skeleton.body17Edges,
                                color: kind.color, map: mapPoint
                            )
                        }
                    case .hands(let f):
                        for hand in f.detections {
                            drawSkeleton(
                                context: context, points: hand.joints, edges: Skeleton.hand21Edges,
                                color: kind.color, map: mapPoint
                            )
                        }
                    case .faces(let f):
                        for face in f.detections {
                            for point in face.points where point.confidence > 0 {
                                let p = mapPoint(point)
                                context.fill(
                                    Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)),
                                    with: .color(kind.color)
                                )
                            }
                        }
                    case .texts(let f), .animals(let f):
                        for box in f.detections {
                            let rect = mapRect(box.box)
                            context.stroke(Path(rect), with: .color(kind.color), lineWidth: 2)
                            let label = Text("\(box.label) \(box.confidence, format: .number.precision(.fractionLength(2)))")
                                .font(.footnote.weight(.semibold).monospaced())
                                .foregroundStyle(kind.color)
                            context.draw(label, at: CGPoint(x: rect.minX + 4, y: max(rect.minY - 10, 8)), anchor: .leading)
                        }
                    }
                }
            }
        }
        .accessibilityLabel("OSC tracking visualizer")
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
            // Skip limbs with a missing endpoint (VisionOSC sentinel has confidence 0).
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

    private func frameDimensions(of decoded: DecodedFrame) -> (Int32, Int32) {
        switch decoded {
        case .poses(let f): (f.width, f.height)
        case .hands(let f): (f.width, f.height)
        case .faces(let f): (f.width, f.height)
        case .texts(let f): (f.width, f.height)
        case .animals(let f): (f.width, f.height)
        }
    }

    private func drawPlaceholder(context: GraphicsContext, size: CGSize) {
        let text = Text("Waiting for OSC messages…")
            .font(.title3)
            .foregroundStyle(.gray)
        context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
    }
}
