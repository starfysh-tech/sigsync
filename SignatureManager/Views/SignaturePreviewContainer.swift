import SwiftUI
import WebKit

struct SignaturePreviewContainer: View {
    let htmlContent: String
    @State private var webView = WKWebView()
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Preview")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .controlSize(.small)
                }
            }
            
            WebViewRepresentable(
                webView: webView,
                htmlContent: htmlContent,
                isLoading: $isLoading
            )
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    let htmlContent: String
    @Binding var isLoading: Bool
    
    func makeNSView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        let wrappedHTML = createWrappedHTML(htmlContent)
        nsView.loadHTMLString(wrappedHTML, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createWrappedHTML(_ content: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    margin: 16px;
                    padding: 0;
                    background-color: #ffffff;
                    color: #333333;
                    line-height: 1.4;
                }
                
                /* Reset some common email styles */
                table {
                    border-collapse: collapse;
                    border-spacing: 0;
                }
                
                img {
                    max-width: 100%;
                    height: auto;
                }
                
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                
                a:hover {
                    text-decoration: underline;
                }
                
                /* Signature container */
                .signature-container {
                    max-width: 600px;
                    margin: 0;
                }
            </style>
        </head>
        <body>
            <div class="signature-container">
                \(content)
            </div>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewRepresentable
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow only the initial load, block all other navigation
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
            } else {
                // Open external links in default browser
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
            }
        }
    }
}

#Preview {
    SignaturePreviewContainer(htmlContent: """
        <div style="font-family: Arial, sans-serif; font-size: 14px; color: #333;">
            <p><strong>John Doe</strong><br>
            Software Engineer<br>
            Example Company</p>
            
            <p>📧 john.doe@example.com<br>
            📱 +1 (555) 123-4567<br>
            🌐 <a href="https://example.com">example.com</a></p>
        </div>
        """)
        .frame(height: 200)
        .padding()
}