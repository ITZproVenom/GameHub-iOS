import UIKit
import Metal
import QuartzCore

/// Window-hosted CAMetalLayer (Madeira MetalHostView pattern).
/// Register with `MadeiraBootSequence.attachMetalLayer` before Wine/DXMT present.
final class MetalHostView: UIView {
    static let shared = MetalHostView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))

    override class var layerClass: AnyClass { CAMetalLayer.self }

    var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .black
        contentScaleFactor = UIScreen.main.scale
        metalLayer.device = MTLCreateSystemDefaultDevice()
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func install(on window: UIWindow, frame: CGRect) {
        if superview !== window {
            removeFromSuperview()
            window.addSubview(self)
        }
        self.frame = frame
        MadeiraBootSequence.attachMetalLayer(metalLayer)
    }
}
