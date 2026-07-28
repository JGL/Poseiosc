//
//  Skeleton.swift
//  PoseioscShared
//
//  Edge lists for drawing skeletons, shared by the iOS overlay and the macOS
//  visualizer so both render identical geometry. Indices refer to
//  `JointOrder.body17` / `JointOrder.hand21`.
//

public enum Skeleton {
    /// Limb pairs for the 17-joint PoseNet body skeleton.
    public static let body17Edges: [(Int, Int)] = [
        // head
        (0, 1), (0, 2), (1, 3), (2, 4),
        // torso
        (5, 6), (5, 11), (6, 12), (11, 12),
        // left arm (indices 5,7,9)
        (5, 7), (7, 9),
        // right arm (indices 6,8,10)
        (6, 8), (8, 10),
        // left leg (11,13,15)
        (11, 13), (13, 15),
        // right leg (12,14,16)
        (12, 14), (14, 16)
    ]

    /// Finger chains for the 21-joint hand skeleton: wrist → each finger base → tip.
    public static let hand21Edges: [(Int, Int)] = [
        // thumb: wrist → CMC → MP → IP → tip
        (0, 1), (1, 2), (2, 3), (3, 4),
        // index: wrist → MCP → PIP → DIP → tip
        (0, 5), (5, 6), (6, 7), (7, 8),
        // middle
        (0, 9), (9, 10), (10, 11), (11, 12),
        // ring
        (0, 13), (13, 14), (14, 15), (15, 16),
        // pinky
        (0, 17), (17, 18), (18, 19), (19, 20)
    ]
}
