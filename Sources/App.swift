import SwiftUI
import WebKit

@main
struct DiscordTokenHelperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class TokenManager: ObservableObject {
    @Published var token: String? = nil
    @Published var showCopiedBanner: Bool = false
    @Published var statusText: String = "Войдите в свой аккаунт Discord"
    
    func setToken(_ t: String) {
        DispatchQueue.main.async {
            self.token = t
            self.statusText = "Токен успешно получен!"
            UIPasteboard.general.string = t
            self.showCopiedBanner = true
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

struct ContentView: View {
    @StateObject private var tokenManager = TokenManager()
    @State private var webViewWrapper = WKWebViewWrapper()
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                webViewWrapper
                    .environmentObject(tokenManager)
                    .edgesIgnoringSafeArea(.bottom)
                
                VStack(spacing: 12) {
                    if let token = tokenManager.token {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Токен готов!")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    UIPasteboard.general.string = token
                                    tokenManager.showCopiedBanner = true
                                }) {
                                    Label("Скопировать", systemImage: "doc.on.doc")
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            Text(token)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground).opacity(0.95))
                        .cornerRadius(14)
                        .shadow(radius: 8)
                        .padding(.horizontal)
                    } else {
                        HStack {
                            Button(action: {
                                webViewWrapper.manualExtractToken()
                            }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                    Text("Скопировать токен")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                webViewWrapper.reload()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.headline)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle("Discord Token Helper")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $tokenManager.showCopiedBanner) {
                Alert(
                    title: Text("Успешно!"),
                    message: Text("Discord-токен скопирован в буфер обмена! Теперь можете вставить его в игру."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct WKWebViewWrapper: UIViewRepresentable {
    private let webView: WKWebView
    private let coordinator: Coordinator
    
    init() {
        let contentController = WKUserContentController()
        
        let scriptSource = """
        (function() {
            const origFetch = window.fetch;
            window.fetch = async function(...args) {
                const response = await origFetch.apply(this, args);
                try {
                    const url = args[0] ? (typeof args[0] === 'string' ? args[0] : args[0].url) : '';
                    if (url && (url.includes('/api/v9/auth/login') || url.includes('/api/v9/auth/mfa/totp') || url.includes('/api/v9/users/@me'))) {
                        const clone = response.clone();
                        clone.json().then(data => {
                            if (data && data.token) {
                                window.webkit.messageHandlers.tokenHandler.postMessage(data.token);
                            }
                        }).catch(()=>{});
                    }
                } catch(e) {}
                return response;
            };
            
            const origOpen = XMLHttpRequest.prototype.open;
            const origSend = XMLHttpRequest.prototype.send;
            XMLHttpRequest.prototype.open = function(method, url) {
                this._url = url;
                return origOpen.apply(this, arguments);
            };
            XMLHttpRequest.prototype.send = function() {
                this.addEventListener('load', function() {
                    try {
                        if (this._url && (this._url.includes('/api/v9/auth/login') || this._url.includes('/api/v9/auth/mfa/totp'))) {
                            const data = JSON.parse(this.responseText);
                            if (data && data.token) {
                                window.webkit.messageHandlers.tokenHandler.postMessage(data.token);
                            }
                        }
                    } catch(e) {}
                });
                return origSend.apply(this, arguments);
            };
        })();
        """
        
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        
        self.webView = wv
        self.coordinator = Coordinator(webView: wv)
        contentController.add(self.coordinator, name: "tokenHandler")
    }
    
    func makeCoordinator() -> Coordinator {
        return coordinator
    }
    
    func makeUIView(context: Context) -> WKWebView {
        coordinator.tokenManager = context.environment[TokenManagerKey.self]
        webView.navigationDelegate = coordinator
        
        if let url = URL(string: "https://discord.com/login") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        coordinator.tokenManager = context.environment[TokenManagerKey.self]
    }
    
    func reload() {
        if let url = URL(string: "https://discord.com/login") {
            webView.load(URLRequest(url: url))
        }
    }
    
    func manualExtractToken() {
        let js = """
        (function() {
            try {
                let webpackReq;
                if (typeof webpackChunkdiscord_app !== 'undefined') {
                    webpackChunkdiscord_app.push([[''], {}, e => { webpackReq = e; }]);
                    if (webpackReq && webpackReq.c) {
                        for (let id in webpackReq.c) {
                            let m = webpackReq.c[id];
                            if (m && m.exports && m.exports.default && typeof m.exports.default.getToken === 'function') {
                                let tok = m.exports.default.getToken();
                                if (tok) return tok;
                            }
                            if (m && m.exports && typeof m.exports.getToken === 'function') {
                                let tok = m.exports.getToken();
                                if (tok) return tok;
                            }
                        }
                    }
                }
                let iframe = document.createElement('iframe');
                document.body.appendChild(iframe);
                let tok = iframe.contentWindow.localStorage.getItem('token');
                iframe.remove();
                if (tok) return tok.replace(/^\"|\"$/g, '');
            } catch(e) {}
            return null;
        })();
        """
        webView.evaluateJavaScript(js) { result, _ in
            if let token = result as? String, !token.isEmpty {
                coordinator.tokenManager?.setToken(token)
            }
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var tokenManager: TokenManager?
        
        init(webView: WKWebView) {
            self.webView = webView
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "tokenHandler", let token = message.body as? String, !token.isEmpty {
                tokenManager?.setToken(token)
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url?.absoluteString, url.contains("discord.com/channels") || url.contains("discord.com/app") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let js = """
                    (function() {
                        try {
                            let webpackReq;
                            if (typeof webpackChunkdiscord_app !== 'undefined') {
                                webpackChunkdiscord_app.push([[''], {}, e => { webpackReq = e; }]);
                                if (webpackReq && webpackReq.c) {
                                    for (let id in webpackReq.c) {
                                        let m = webpackReq.c[id];
                                        if (m && m.exports && m.exports.default && typeof m.exports.default.getToken === 'function') {
                                            let tok = m.exports.default.getToken();
                                            if (tok) return tok;
                                        }
                                        if (m && m.exports && typeof m.exports.getToken === 'function') {
                                            let tok = m.exports.getToken();
                                            if (tok) return tok;
                                        }
                                    }
                                }
                            }
                        } catch(e) {}
                        return null;
                    })();
                    """
                    guard let wv = self.webView else { return }
                    wv.evaluateJavaScript(js) { [weak self] result, _ in
                        if let token = result as? String, !token.isEmpty {
                            self?.tokenManager?.setToken(token)
                        }
                    }
                }
            }
        }
    }
}

private struct TokenManagerKey: EnvironmentKey {
    static let defaultValue: TokenManager? = nil
}

extension EnvironmentValues {
    var tokenManager: TokenManager? {
        get { self[TokenManagerKey.self] }
        set { self[TokenManagerKey.self] = newValue }
    }
}
