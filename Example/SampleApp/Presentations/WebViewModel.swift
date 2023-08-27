import Foundation
import Combine
import StateMachine

protocol WebViewModelProtocol {
    var showAlertSubject: PassthroughSubject<String, Never> { get }
    var purgeLoginSessionSubject: PassthroughSubject<Void, Never> { get }
    func apply(on event: Event)
}

@MainActor
final class WebViewModel {
    private(set) var showAlertSubject = PassthroughSubject<String, Never>()
    private(set) var purgeLoginSessionSubject = PassthroughSubject<Void, Never>()

    private var stateMachine: StateMachine<State, Event, SideEffect>!
    private let transitions: [Transition<State, Event, SideEffect>] = [
        // From State.notLoggedIn
        .init(from: .notLoggedIn, to: .displayingTopPage, on: .topPageLoadCompleted),
        
        // From State.displayingTopPage
        .init(from: .displayingTopPage, to: .displayingTopPage, on: .topPageLoadCompleted),
        .init(from: .displayingTopPage, to: .displayingLoginPage, on: .loginPageLoadCompleted),
        
        // From State.displayingLoginPage
        .init(from: .displayingLoginPage, to: .displayingTopPage, on: .topPageLoadCompleted),
        .init(from: .displayingLoginPage, to: .processingLogin, on: .loginButtonTapped),
        
        // From State.processingLogin
        .init(from: .processingLogin, to: .processingLogin, on: .loginButtonTapped),
        .init(from: .processingLogin, to: .displayingLoginPage, on: .loginPageLoadCompleted, with: .displayLoginErrorAlert),
        .init(from: .processingLogin, to: .loggedInToEC, on: .topPageLoadCompleted, with: .triggerLoginAPI),
        
        // from State.loggedInToEC
        .init(from: .loggedInToEC, to: .loggedInToApp, on: .loginAPISucceeded, with: .displayLoginSuccessAlert),
        .init(from: .loggedInToEC, to: .displayingTopPage, on: .loginAPIFailed, with: .purgeLoginSession),
    ]
    
    init() {
        self.stateMachine = StateMachine(initialState: .notLoggedIn, transitions: transitions) { [weak self] result in
            guard let self else { return }

            if case .failure(let error) = result, case .undefinedTransition = error {
                print(error.description)
            }
            
            if case .success(let transition) = result {
                print(transition.description)

                if let sideEffect = transition.sideEffect {
                    switch sideEffect {
                    case .displayLoginSuccessAlert:
                        let message = "Login Success"
                        showAlert(message)
                    case .displayLoginErrorAlert:
                        let message = "Login Error"
                        showAlert(message)
                    case .triggerLoginAPI:
                        login()
                    case .purgeLoginSession:
                        purgeLoginSession()
                    }
                }
            }
        }
    }
}

extension WebViewModel: WebViewModelProtocol {
    func apply(on event: Event) {
        stateMachine.apply(event)
    }
}

private extension WebViewModel {
    func login() {
        if Bool.random() {
            stateMachine.apply(.loginAPISucceeded)
        } else {
            stateMachine.apply(.loginAPIFailed)
        }
    }
    
    @MainActor func showAlert(_ message: String) {
        showAlertSubject.send(message)
    }
    
    @MainActor func purgeLoginSession() {
        purgeLoginSessionSubject.send(())
    }
}

enum State: StateHashable {
    case notLoggedIn            // 未ログイン
    case displayingTopPage      // トップページ表示中
    case displayingLoginPage    // ログインページ表示中
    case processingLogin        // ログイン処理中
    case loggedInToEC           // ECサイトログイン済
    case loggedInToApp          // Appログイン済
}

enum Event: EventHashable {
    case topPageLoadCompleted   // トップページ読み込み完了
    case loginPageLoadCompleted // ログインページ読み込み完了
    case loginButtonTapped      // ログインボタン押下
    case loginAPISucceeded      // ログインAPI成功
    case loginAPIFailed         // ログインAPI失敗
}

enum SideEffect: SideEffectHashable {
    case displayLoginSuccessAlert   // ログイン成功アラート表示
    case displayLoginErrorAlert     // ログインエラーアラート表示
    case triggerLoginAPI            // ログインAPI実行
    case purgeLoginSession          // ログインセッション破棄
}
