import SwiftUI
import WebKit

/// Practical play path while Madeira/Wine binaries are not bundled:
/// open Xbox Cloud Gaming in an in-app WebView (same idea as GameStream).
struct CloudPlayView: View {
    @State private var urlString = "https://www.xbox.com/play"
    @State private var reloadToken = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CloudWebView(urlString: urlString, reloadToken: reloadToken)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Cloud Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        urlString = "https://www.xbox.com/play"
                        reloadToken += 1
                    } label: {
                        Image(systemName: "house")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reloadToken += 1
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

struct CloudWebView: UIViewRepresentable {
    let urlString: String
    let reloadToken: Int

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.scrollView.contentInsetAdjustmentBehavior = .never
        if let url = URL(string: urlString) {
            web.load(URLRequest(url: url))
        }
        return web
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            if let url = URL(string: urlString) {
                webView.load(URLRequest(url: url))
            } else {
                webView.reload()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastReloadToken = -1
    }
}
