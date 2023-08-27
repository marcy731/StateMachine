import Foundation
import Combine
import StateMachine

protocol WebViewModelProtocol {
    var showAlertSubject: PassthroughSubject<String, Never> { get }
    var logoutSubject: PassthroughSubject<Void, Never> { get }
    func apply(on event: WebViewModel.Event)
}

@MainActor
final class WebViewModel {
    enum State: StateHashable {
        case initial                // 初期State
        case displayingTopPage      // トップページ表示中
        case displayingLoginPage    // ログインページ表示中
        case displayingMyPage       // マイページ表示中
        case processingEcLogin      // ECログイン処理中
        case processingAppLogin     // APPログイン処理中
        case processingExit         // 退会処理中
    }
    
    enum Event: EventHashable {
        case topPageLoadCompleted   // トップページ読み込み完了
        case loginPageLoadCompleted // ログインページ読み込み完了
        case myPageLoadCompleted    // マイページ読み込み完了
        case loginButtonTapped      // ログインボタン押下
        case exitButtonTapped       // 退会ボタン押下
        case logoutButtonTapped     // ログアウトボタン押下
        case loginAPISucceeded      // ログインAPI成功
        case loginAPIFailed         // ログインAPI失敗
    }
    
    enum SideEffect: SideEffectHashable {
        case showLoginSuccessAlert  // ログイン成功アラート表示
        case showLoginErrorAlert    // ログインエラーアラート表示
        case triggerLoginAPI        // ログインAPI実行
        case logout                 // ログアウト処理（ログインセッション破棄）
    }

    private var stateMachine: StateMachine<State, Event, SideEffect>!
    private let transitions: [Transition<State, Event, SideEffect>] = [
        .init(from: .initial,             to: .displayingTopPage,     on: .topPageLoadCompleted),
        .init(from: .initial,             to: .displayingLoginPage,   on: .loginPageLoadCompleted),
        .init(from: .initial,             to: .displayingMyPage,      on: .myPageLoadCompleted),
        
        .init(from: .displayingTopPage,   to: .displayingTopPage,     on: .topPageLoadCompleted),
        .init(from: .displayingTopPage,   to: .displayingLoginPage,   on: .loginPageLoadCompleted),
        .init(from: .displayingTopPage,   to: .displayingMyPage,      on: .myPageLoadCompleted),
        .init(from: .displayingTopPage,   to: .displayingTopPage,     on: .logoutButtonTapped,      with: .logout),
        
        .init(from: .displayingLoginPage, to: .displayingTopPage,     on: .topPageLoadCompleted),
        .init(from: .displayingLoginPage, to: .processingEcLogin,     on: .loginButtonTapped),
        
        .init(from: .processingEcLogin,   to: .processingEcLogin,     on: .loginButtonTapped),
        .init(from: .processingEcLogin,   to: .displayingLoginPage,   on: .loginPageLoadCompleted,  with: .showLoginErrorAlert),
        .init(from: .processingEcLogin,   to: .processingAppLogin,    on: .topPageLoadCompleted,    with: .triggerLoginAPI),
        
        .init(from: .processingAppLogin,  to: .displayingTopPage,     on: .loginAPISucceeded,       with: .showLoginSuccessAlert),
        .init(from: .processingAppLogin,  to: .displayingTopPage,     on: .loginAPIFailed,          with: .logout),
        
        .init(from: .displayingMyPage,    to: .processingExit,        on: .exitButtonTapped),
        .init(from: .displayingMyPage,    to: .displayingTopPage,     on: .logoutButtonTapped,      with: .logout),
        
        .init(from: .processingExit,      to: .displayingMyPage,      on: .myPageLoadCompleted),
        .init(from: .processingExit,      to: .displayingTopPage,     on: .topPageLoadCompleted,    with: .logout),
    ]
    
    private(set) var showAlertSubject = PassthroughSubject<String, Never>()
    private(set) var logoutSubject = PassthroughSubject<Void, Never>()
    
    init() {
        self.stateMachine = StateMachine(initialState: .initial, transitions: transitions) { [weak self] result in
            guard let self else { return }

            if case .failure(let error) = result, case .undefinedTransition = error {
                print(error.description)
            }
            
            if case .success(let transition) = result {
                print(transition.description)

                if let sideEffect = transition.sideEffect {
                    switch sideEffect {
                    case .showLoginSuccessAlert:
                        let message = "Login Success"
                        showAlert(message)
                    case .showLoginErrorAlert:
                        let message = "Login Error"
                        showAlert(message)
                    case .triggerLoginAPI:
                        login()
                    case .logout:
                        logout()
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
    
    @MainActor func logout() {
        logoutSubject.send(())
    }
}

