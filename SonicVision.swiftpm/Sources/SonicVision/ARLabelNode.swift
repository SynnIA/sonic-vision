import SceneKit
import UIKit

/// A 3D floating label node that renders above detected objects in AR space.
/// Uses SCNPlane with a rendered texture for crisp text at any distance.
final class ARLabelNode: SCNNode {

    private static let planeWidth: CGFloat = 0.12
    private static let planeHeight: CGFloat = 0.045
    private static let textureScale: CGFloat = 4.0 // retina sharpness

    let label: String

    init(label: String, distance: Float) {
        self.label = label
        super.init()

        let plane = SCNPlane(width: Self.planeWidth, height: Self.planeHeight)
        plane.cornerRadius = 0.006

        let material = SCNMaterial()
        material.diffuse.contents = Self.renderTexture(label: label, distance: distance)
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.writesToDepthBuffer = false

        plane.materials = [material]

        let planeNode = SCNNode(geometry: plane)
        planeNode.renderingOrder = 100
        addChildNode(planeNode)

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        constraints = [billboard]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Updates the texture with a new distance value.
    func updateDistance(_ distance: Float) {
        guard let plane = childNodes.first?.geometry as? SCNPlane else { return }
        plane.materials.first?.diffuse.contents = Self.renderTexture(label: label, distance: distance)
    }

    // MARK: - Texture Rendering

    private static func urgencyColor(for distance: Float) -> UIColor {
        if distance < 0.5 { return UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0) }
        if distance < 1.5 { return UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1.0) }
        return UIColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
    }

    private static func renderTexture(label: String, distance: Float) -> UIImage {
        let w = planeWidth * 1000 * textureScale
        let h = planeHeight * 1000 * textureScale
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)

            // Background pill
            let bgPath = UIBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: h * 0.3)
            UIColor(white: 0.0, alpha: 0.7).setFill()
            bgPath.fill()

            let color = urgencyColor(for: distance)

            // Colored dot
            let dotSize: CGFloat = h * 0.25
            let dotRect = CGRect(x: h * 0.25, y: (h - dotSize) / 2, width: dotSize, height: dotSize)
            color.setFill()
            UIBezierPath(ovalIn: dotRect).fill()

            // Label text
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: h * 0.38, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let labelStr = label.uppercased()
            let labelSize = labelStr.size(withAttributes: labelAttrs)
            let labelX = dotRect.maxX + h * 0.12
            let labelY = (h - labelSize.height) / 2
            labelStr.draw(at: CGPoint(x: labelX, y: labelY), withAttributes: labelAttrs)

            // Distance text
            let distStr = String(format: "%.1fm", distance)
            let distAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: h * 0.28, weight: .medium),
                .foregroundColor: color
            ]
            let distSize = distStr.size(withAttributes: distAttrs)
            let distX = w - distSize.width - h * 0.25
            let distY = (h - distSize.height) / 2
            distStr.draw(at: CGPoint(x: distX, y: distY), withAttributes: distAttrs)
        }
    }
}
