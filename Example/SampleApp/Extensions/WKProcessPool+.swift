import WebKit

extension WKProcessPool {
    static var shared = WKProcessPool()
    
    func reset() {
        WKProcessPool.shared = WKProcessPool()
    }
}
