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
    @Published var source: String = ""
    @Published var showCopiedBanner: Bool = false
    @Published var debugLogs: [String] = []
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    
    var onManualExtract: (() -> Void)?
    var onReload: (() -> Void)?
    
    func log(_ msg: String) {
        DispatchQueue.main.async {
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            let timestamp = df.string(from: Date())
            let line = "[\(timestamp)] \(msg)"
            self.debugLogs.append(line)
            if self.debugLogs.count > 60 {
                self.debugLogs.removeFirst()
            }
        }
    }
    
    func setToken(_ t: String, from src: String = "Авто") {
        DispatchQueue.main.async {
            guard self.token != t else { return }
            self.token = t
            self.source = src
            UIPasteboard.general.string = t
            self.showCopiedBanner = true
            self.log("✅ УСПЕХ! Токен получен (\(src)): \(t.prefix(12))...\(t.suffix(6))")
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    func showInfo(title: String, message: String) {
        DispatchQueue.main.async {
            self.alertTitle = title
            self.alertMessage = message
            self.showAlert = true
        }
    }
}

struct ContentView: View {
    @StateObject private var tokenManager = TokenManager()
    @State private var showDebugSheet = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                WKWebViewWrapper(tokenManager: tokenManager)
                    .edgesIgnoringSafeArea(.bottom)
                
                VStack(spacing: 10) {
                    if let token = tokenManager.token {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Токен готов!")
                                        .font(.headline)
                                    Text("Источник: \(tokenManager.source)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    UIPasteboard.general.string = token
                                    tokenManager.showInfo(title: "Скопировано!", message: "Токен снова скопирован в буфер обмена.")
                                }) {
                                    Label("Копировать", systemImage: "doc.on.doc")
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                            
                            Text(token)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground).opacity(0.95))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                Button(action: {
                                    tokenManager.onManualExtract?()
                                }) {
                                    HStack {
                                        Image(systemName: "key.fill")
                                        Text("Скопировать токен")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                
                                Button(action: {
                                    tokenManager.onReload?()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.headline)
                                        .padding(14)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .foregroundColor(.primary)
                                        .cornerRadius(12)
                                }
                                
                                Button(action: {
                                    showDebugSheet = true
                                }) {
                                    Image(systemName: "ladybug.fill")
                                        .font(.headline)
                                        .padding(14)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .foregroundColor(.orange)
                                        .cornerRadius(12)
                                }
                            }
                            
                            Text("Войдите в Discord. Токен перехватится автоматически.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground).opacity(0.95))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 8)
            }
            .navigationTitle("Discord Token Helper")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDebugSheet) {
                NavigationView {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            if tokenManager.debugLogs.isEmpty {
                                Text("Логи еще не поступили. Попробуйте обновить страницу.")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                    .padding()
                            } else {
                                ForEach(tokenManager.debugLogs.indices, id: \.self) { idx in
                                    Text(tokenManager.debugLogs[idx])
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding()
                    }
                    .navigationTitle("Отладочный лог")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Закрыть") {
                                showDebugSheet = false
                            }
                        }
                    }
                }
            }
            .alert(isPresented: $tokenManager.showAlert) {
                Alert(
                    title: Text(tokenManager.alertTitle),
                    message: Text(tokenManager.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct WKWebViewWrapper: UIViewRepresentable {
    @ObservedObject var tokenManager: TokenManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(tokenManager: tokenManager)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        
        let scriptSource = """
        (function() {
            function notify(token, source) {
                if (!token || typeof token !== 'string') return;
                token = token.trim().replace(/^"|"$/g, '');
                if (token.length > 25 && !token.includes(' ') && (token.includes('.') || token.startsWith('mfa.'))) {
                    try {
                        window.webkit.messageHandlers.tokenHandler.postMessage({ token: token, source: source });
                    } catch(e) {}
                }
            }

            function logMsg(msg) {
                try {
                    window.webkit.messageHandlers.debugHandler.postMessage(String(msg));
                } catch(e) {}
            }

            logMsg("JS: Инжект скрипта выполнен на " + window.location.href);

            // 1. Hook XMLHttpRequest.setRequestHeader
            try {
                const origSetHeader = XMLHttpRequest.prototype.setRequestHeader;
                XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
                    try {
                        if (header && typeof header === 'string' && header.toLowerCase() === 'authorization') {
                            logMsg("JS: XHR нашел Authorization!");
                            notify(value, "XHR Header");
                        }
                    } catch(e) {}
                    return origSetHeader.apply(this, arguments);
                };
                logMsg("JS: XHR hook активен");
            } catch(e) { logMsg("JS: Ошибка XHR хука: " + e); }

            // 2. Hook window.fetch
            try {
                const origFetch = window.fetch;
                window.fetch = async function(...args) {
                    try {
                        const init = args[1];
                        if (init && init.headers) {
                            if (init.headers instanceof Headers) {
                                const auth = init.headers.get('authorization') || init.headers.get('Authorization');
                                if (auth) {
                                    logMsg("JS: Fetch нашел Authorization (Headers)!");
                                    notify(auth, "Fetch Header (Headers)");
                                }
                            } else if (typeof init.headers === 'object') {
                                for (let k in init.headers) {
                                    if (k.toLowerCase() === 'authorization') {
                                        logMsg("JS: Fetch нашел Authorization (Obj)!");
                                        notify(init.headers[k], "Fetch Header (Obj)");
                                    }
                                }
                            }
                        }
                    } catch(e) {}
                    
                    const response = await origFetch.apply(this, args);
                    try {
                        const url = args[0] ? (typeof args[0] === 'string' ? args[0] : args[0].url) : '';
                        if (url && (url.includes('/api/v9/auth/login') || url.includes('/api/v9/auth/mfa/totp'))) {
                            const clone = response.clone();
                            clone.json().then(data => {
                                if (data && data.token) {
                                    logMsg("JS: Ответ логина вернул токен!");
                                    notify(data.token, "Login Response");
                                }
                            }).catch(()=>{});
                        }
                    } catch(e) {}
                    return response;
                };
                logMsg("JS: Fetch hook активен");
            } catch(e) { logMsg("JS: Ошибка Fetch хука: " + e); }

            // 3. Hook WebSocket
            try {
                const origWS = window.WebSocket;
                window.WebSocket = function(...args) {
                    const ws = new origWS(...args);
                    const origSend = ws.send;
                    ws.send = function(data) {
                        try {
                            if (typeof data === 'string') {
                                const parsed = JSON.parse(data);
                                if (parsed && parsed.d && parsed.d.token) {
                                    logMsg("JS: WebSocket нашел токен в Gateway!");
                                    notify(parsed.d.token, "Gateway WebSocket");
                                }
                            }
                        } catch(e) {}
                        return origSend.apply(this, arguments);
                    };
                    return ws;
                };
                logMsg("JS: WebSocket hook активен");
            } catch(e) { logMsg("JS: Ошибка WS хука: " + e); }

            // 4. Function to scan storage
            window.__checkStorageForToken = async function() {
                let results = [];
                
                // localStorage
                try {
                    for (let i = 0; i < localStorage.length; i++) {
                        let k = localStorage.key(i);
                        let v = localStorage.getItem(k);
                        if (k && k.toLowerCase().includes('token') && v) {
                            notify(v, "localStorage (" + k + ")");
                            results.push("localStorage[" + k + "]");
                        }
                    }
                } catch(e) { results.push("localStorage err"); }

                // IndexedDB (Discord stores token in 'discord' -> 'keyvaluepairs')
                try {
                    let idbToken = await new Promise((resolve) => {
                        let req = indexedDB.open("discord");
                        req.onsuccess = function() {
                            let db = req.result;
                            if (db.objectStoreNames.contains("keyvaluepairs")) {
                                let tx = db.transaction("keyvaluepairs", "readonly");
                                let st = tx.objectStore("keyvaluepairs");
                                let getReq = st.get("token");
                                getReq.onsuccess = () => resolve(getReq.result);
                                getReq.onerror = () => resolve(null);
                            } else resolve(null);
                        };
                        req.onerror = () => resolve(null);
                    });
                    if (idbToken) {
                        notify(idbToken, "IndexedDB");
                        results.push("IndexedDB: OK");
                    } else {
                        results.push("IndexedDB: нет ключа");
                    }
                } catch(e) { results.push("IndexedDB err"); }

                // Webpack
                try {
                    let wpReq;
                    if (typeof webpackChunkdiscord_app !== 'undefined') {
                        webpackChunkdiscord_app.push([[Math.random()], {}, e => { wpReq = e; }]);
                        if (wpReq && wpReq.c) {
                            for (let id in wpReq.c) {
                                let mod = wpReq.c[id]?.exports;
                                if (!mod) continue;
                                if (typeof mod.getToken === 'function') {
                                    let t = mod.getToken();
                                    if (t) { notify(t, "Webpack root"); results.push("Webpack: OK"); break; }
                                }
                                if (typeof mod.default?.getToken === 'function') {
                                    let t = mod.default.getToken();
                                    if (t) { notify(t, "Webpack default"); results.push("Webpack default: OK"); break; }
                                }
                                for (let k in mod) {
                                    if (typeof mod[k]?.getToken === 'function') {
                                        let t = mod[k].getToken();
                                        if (t) { notify(t, "Webpack mod." + k); results.push("Webpack " + k + ": OK"); break; }
                                    }
                                }
                            }
                        }
                    } else {
                        results.push("webpackChunk: нет");
                    }
                } catch(e) { results.push("Webpack err"); }

                let resStr = results.join(" | ");
                logMsg("JS: Сканирование -> " + resStr);
                return resStr;
            };

            setInterval(() => {
                if (window.__checkStorageForToken) window.__checkStorageForToken();
            }, 2500);
        })();
        """
        
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        
        wv.navigationDelegate = context.coordinator
        context.coordinator.webView = wv
        contentController.add(context.coordinator, name: "tokenHandler")
        contentController.add(context.coordinator, name: "debugHandler")
        
        tokenManager.onReload = { [weak wv] in
            if let url = URL(string: "https://discord.com/login") {
                wv?.load(URLRequest(url: url))
            }
        }
        
        tokenManager.onManualExtract = { [weak wv, weak tokenManager] in
            tokenManager?.log("UI: Нажата кнопка ручного извлечения...")
            let js = "if (window.__checkStorageForToken) { window.__checkStorageForToken(); } else { 'Скрипт еще не внедрен'; }"
            wv?.evaluateJavaScript(js) { result, error in
                if let err = error {
                    tokenManager?.log("UI: Ошибка JS: \(err.localizedDescription)")
                    tokenManager?.showInfo(title: "Ошибка", message: err.localizedDescription)
                } else if let res = result as? String {
                    tokenManager?.log("UI: Результат проверки: \(res)")
                    if tokenManager?.token == nil {
                        tokenManager?.showInfo(
                            title: "Поиск токена",
                            message: "Результат проверки: \(res).\n\nЕсли вы уже вошли в Discord, просто откройте любой чат или отправьте сообщение — токен перехватится автоматически."
                        )
                    }
                }
            }
        }
        
        if let url = URL(string: "https://discord.com/login") {
            wv.load(URLRequest(url: url))
        }
        
        return wv
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        let tokenManager: TokenManager
        
        init(tokenManager: TokenManager) {
            self.tokenManager = tokenManager
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "tokenHandler" {
                if let dict = message.body as? [String: Any],
                   let token = dict["token"] as? String, !token.isEmpty {
                    let source = dict["source"] as? String ?? "Неизвестно"
                    tokenManager.setToken(token, from: source)
                } else if let token = message.body as? String, !token.isEmpty {
                    tokenManager.setToken(token, from: "Авто")
                }
            } else if message.name == "debugHandler" {
                if let msg = message.body as? String {
                    tokenManager.log(msg)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tokenManager.log("WebView: Страница загружена (\(webView.url?.absoluteString ?? ""))")
            let js = "if (window.__checkStorageForToken) { window.__checkStorageForToken(); }"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
