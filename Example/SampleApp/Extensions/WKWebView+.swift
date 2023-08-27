import WebKit

extension WKWebView {
    public static func removeCookies() {
        WKWebsiteDataStore.default().removeData(
            ofTypes: [WKWebsiteDataTypeCookies],
            modifiedSince: Date(timeIntervalSince1970: 0),
            completionHandler: {
                WKProcessPool.shared.reset()
            }
        )
    }
}
