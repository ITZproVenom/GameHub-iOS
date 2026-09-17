import SwiftUI
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
        isUserInteractionEnabled = true
        backgroundColor = .black
        contentScaleFactor = UIScreen.main.scale
        metalLayer.device = MTLCreateSystemDefaultDevice()
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.presentsWithTransaction = false
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
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.bringSubviewToFront(self)
        MadeiraBootSequence.attachMetalLayer(metalLayer)
        metalLayer.drawableSize = CGSize(
            width: bounds.width * contentScaleFactor,
            height: bounds.height * contentScaleFactor
        )
    }

    func uninstall() {
        removeFromSuperview()
    }
}

/// Close overlay only. The CAMetalLayer stays on the key window so DXMT can
/// present as soon as Wine creates a swapchain (before SwiftUI covers appear).
struct MetalPlayView: View {
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .ignoresSafeArea()
                .allowsHitTesting(false)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(16)
            }
            .accessibilityLabel("Close session")
        }
        .background(BackgroundClearView())
        .statusBarHidden(true)
        .onAppear {
            MadeiraBootSequence.bindPresentationLayerIfPossible()
        }
    }
}

private struct BackgroundClearView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        DispatchQueue.main.async {
            v.superview?.superview?.backgroundColor = .clear
        }
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
