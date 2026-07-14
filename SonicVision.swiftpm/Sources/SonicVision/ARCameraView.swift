import SwiftUI
import ARKit
import SceneKit

/// UIViewRepresentable wrapping ARSCNView, sharing the ARSession from ARSessionManager.
struct ARCameraView: UIViewRepresentable {
    @ObservedObject var viewModel: SonicViewModel

    /// Capture a direct reference to the ARSession and ARSessionManager
    /// outside of the @MainActor-isolated ViewModel to avoid concurrency issues.
    private let session: ARSession
    private let sessionManager: ARSessionManager

    init(viewModel: SonicViewModel) {
        self.viewModel = viewModel
        self.session = viewModel.arSessionManager.arSession
        self.sessionManager = viewModel.arSessionManager
    }

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.delegate = context.coordinator
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        sceneView.backgroundColor = .black

        // Share the ARSession from ARSessionManager so depth data flows through one pipeline
        sceneView.session = session
        session.delegate = context.coordinator

        context.coordinator.sceneView = sceneView
        context.coordinator.viewModel = viewModel

        print("[SonicVision] ARCameraView: created and connected to ARSessionManager")
        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Ensure session stays connected after SwiftUI view updates
        if uiView.session !== session {
            uiView.session = session
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sessionManager: sessionManager)
    }

    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        let sessionManager: ARSessionManager
        weak var viewModel: SonicViewModel?
        weak var sceneView: ARSCNView?

        private var activeLabelNodes: [String: ARLabelNode] = [:]
        private var labelLastSeen: [String: TimeInterval] = [:]
        private static let maxLabels = 3
        private static let staleTimeout: TimeInterval = 1.5

        init(sessionManager: ARSessionManager) {
            self.sessionManager = sessionManager
            super.init()
        }

        // MARK: - ARSessionDelegate

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            sessionManager.session(session, didUpdate: frame)

            Task { @MainActor [weak self] in
                self?.reconcileLabels(frame: frame)
            }
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            sessionManager.session(session, didFailWithError: error)
        }

        func sessionWasInterrupted(_ session: ARSession) {
            sessionManager.sessionWasInterrupted(session)
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            sessionManager.sessionInterruptionEnded(session)
        }

        // MARK: - 3D Label Reconciliation

        @MainActor
        private func reconcileLabels(frame: ARFrame) {
            guard let viewModel = viewModel, let sceneView = sceneView else { return }

            let now = frame.timestamp
            let cameraTransform = frame.camera.transform
            let objects = viewModel.detectedObjects

            // Track which labels are present this frame
            var seenLabels = Set<String>()

            // Sort by distance (closest first) and cap at maxLabels
            let sortedObjects = objects.sorted { $0.distance < $1.distance }
            let visibleObjects = Array(sortedObjects.prefix(Self.maxLabels))

            for object in visibleObjects {
                let key = object.label
                seenLabels.insert(key)
                labelLastSeen[key] = now

                // Convert camera-relative position to world space
                let localPos = SIMD4<Float>(
                    object.position.x,
                    object.position.y + 0.08, // offset above object
                    object.position.z,
                    1.0
                )
                let worldPos = cameraTransform * localPos
                let targetPosition = SCNVector3(worldPos.x, worldPos.y, worldPos.z)

                if let existingNode = activeLabelNodes[key] {
                    // Smooth position update
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.3
                    existingNode.position = targetPosition
                    SCNTransaction.commit()
                    existingNode.updateDistance(object.distance)
                } else {
                    // Create new label node with fade-in
                    let node = ARLabelNode(label: key, distance: object.distance)
                    node.position = targetPosition
                    node.opacity = 0
                    sceneView.scene.rootNode.addChildNode(node)
                    activeLabelNodes[key] = node

                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.25
                    node.opacity = 1
                    SCNTransaction.commit()
                }
            }

            // Remove stale labels
            for (key, lastSeen) in labelLastSeen {
                if !seenLabels.contains(key), now - lastSeen > Self.staleTimeout {
                    if let node = activeLabelNodes[key] {
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = 0.3
                        SCNTransaction.completionBlock = {
                            node.removeFromParentNode()
                        }
                        node.opacity = 0
                        SCNTransaction.commit()
                        activeLabelNodes.removeValue(forKey: key)
                    }
                    labelLastSeen.removeValue(forKey: key)
                }
            }
        }
    }
}
