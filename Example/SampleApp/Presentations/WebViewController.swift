import UIKit
import WebKit
import Combine

final class WebViewController: UIViewController {

    private var webView: WKWebView!
    private let refreshControl = UIRefreshControl()
    private let viewModel: WebViewModelProtocol = WebViewModel()
    private let loadUrl = URL(string: "https://marcy731.stores.jp")
    private var subscriptions = Set<AnyCancellable>()
    private let loginTrigger = "login"
    private let exitTrigger = "exit"
    private var postLoadingScript: String {
        """
            document.querySelector('.login_form').closest('form')?.addEventListener("submit", () => {
                const email = document.querySelector('input[name="email"]')?.value ?? ""
                const object = {
                    "email": email,
                }
                webkit.messageHandlers.\(loginTrigger).postMessage(object)
            })
        
            if (window.location.pathname === '/mypage/settings/exit') {
                document.querySelector('.btn_send')?.addEventListener("click", () => {
                    webkit.messageHandlers.\(exitTrigger).postMessage({})
                })
            }
        """
    }
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        bind()
        load()
    }

}

private extension WebViewController {

    func setupViews() {
        view.backgroundColor = .white
        
        webView = {
            let userContentController = WKUserContentController()
            let userScript = WKUserScript(
                source: postLoadingScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            userContentController.addUserScript(userScript)
            userContentController.add(self, name: loginTrigger)
            userContentController.add(self, name: exitTrigger)
            
            let configuration = WKWebViewConfiguration()
            configuration.processPool = WKProcessPool.shared
            configuration.userContentController = userContentController
            
            let webView = WKWebView(frame: self.view.bounds, configuration: configuration)
            webView.navigationDelegate = self
            webView.uiDelegate = self
            webView.translatesAutoresizingMaskIntoConstraints = false
            webView.allowsBackForwardNavigationGestures = true
            return webView
        }()
        view.addSubview(webView)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            webView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        ])
        
        webView.scrollView.addSubview(refreshControl)
        refreshControl.addAction(.init { [weak self] _ in
            guard let self else { return }
            reload()
            refreshControl.endRefreshing()
        }, for: .valueChanged)
    }
    
    func bind() {
        viewModel.showAlertSubject
            .filter { !$0.isEmpty }
            .sink { [weak self] message in
                guard let self else { return }
                showAlert(message)
            }
            .store(in: &subscriptions)
        
        viewModel.logoutSubject
            .sink { [weak self] message in
                guard let self else { return }
                logout()
            }
            .store(in: &subscriptions)
        
        webView.publisher(for: \.url, options: .new)
            .sink { url in
                guard let url else { return }
                print("url: \(url.absoluteString)")
            }
            .store(in: &subscriptions)
    }
    
    func load() {
        if let loadUrl {
            webView.load(URLRequest(url: loadUrl))
        }
    }
    
    func reload() {
        if webView.url != nil {
            webView.reload()
        } else {
            load()
        }
    }
    
    func showAlert(_ message: String) {
        let alert = UIAlertController(
            title: "",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func logout() {
        let message = "Logout"
        let alert = UIAlertController(
            title: "",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "OK", style: .default) { _ in 
            WKWebView.removeCookies()
        })
        present(alert, animated: true)
    }

}

// MARK: WKNavigationDelegate
extension WebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        
        if url.path == "/logout" {
            viewModel.apply(on: .logoutButtonTapped)
        }
        
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView.url?.path() == "/" {
            viewModel.apply(on: .topPageLoadCompleted)
        } else if webView.url?.path() == "/login" {
            viewModel.apply(on: .loginPageLoadCompleted)
        } else if webView.url?.path() == "/mypage" {
            viewModel.apply(on: .myPageLoadCompleted)
        }
    }

}

// MARK: WKUIDelegate
extension WebViewController: WKUIDelegate {

    func webView(_: WKWebView, createWebViewWith _: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures _: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "OK", style: .default) { _ in
            completionHandler(true)
        })
        alert.addAction(.init(title: "CANCEL", style: .cancel) { _ in
            completionHandler(false)
        })
        present(alert, animated: true)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(
            title: "",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "OK", style: .default) { _ in
            completionHandler()
        })
        present(alert, animated: true)
    }

}

// MARK: WKScriptMessageHandler
extension WebViewController: WKScriptMessageHandler {

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == loginTrigger {
            guard let body = message.body as? [String: String] else { return }
            print("email: \(body["email"] ?? "no email")")
            viewModel.apply(on: .loginButtonTapped)
        } else if message.name == exitTrigger {
            viewModel.apply(on: .exitButtonTapped)
        }
    }

}
