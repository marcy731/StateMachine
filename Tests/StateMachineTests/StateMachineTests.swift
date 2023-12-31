import XCTest
@testable import StateMachine

final class StateMachineTests: XCTestCase {
    
    
    // MARK: - Properties
    

    var stateMachine: StateMachine<State, Event, SideEffect>!
    

    // MARK: - Define StateMachine

    
    enum State: StateHashable {
        case stopped, playing, paused
    }
    
    enum Event: EventHashable {
        case play, pause, stop
    }
    
    enum SideEffect: SideEffectHashable {
        case logPlay, logPause, logStop
    }
    
    let transitions: [Transition<State, Event, SideEffect>] = [
        // from State.stopped
        .init(from: .stopped, to: .playing, on: .play, with: .logPlay),
        
        // from State.playing
        .init(from: .playing, to: .paused, on: .pause, with: .logPause),
        .init(from: .playing, to: .stopped, on: .stop, with: .logStop),
        
        // from State.
        .init(from: .paused, to: .playing, on: .play, with: .logPlay),
        .init(from: .paused, to: .stopped, on: .stop, with: .logStop),
    ]

    
    // MARK: - Setup
    
    
    override func setUp() {
        super.setUp()
        stateMachine = StateMachine(initialState: .stopped, transitions: transitions)
    }
    

    // MARK: - Tests
    
    
    func testInitialState() {
        XCTAssertEqual(stateMachine.state, State.stopped)
    }
    
    func testValidTransition() {
        stateMachine.apply(.play)
        stateMachine.apply(.stop)
        XCTAssertEqual(stateMachine.state, State.stopped)
    }
    
    func testInvalidTransition() {
        var errorOccurred = false
        stateMachine = StateMachine(initialState: .stopped, transitions: transitions) { result in
            if case .failure(let error) = result, case .undefinedTransition = error {
                errorOccurred = true
            }
        }
        stateMachine.apply(.stop)
        XCTAssertEqual(stateMachine.state, State.stopped)
        XCTAssertTrue(errorOccurred, "An error should have occurred for an undefined transition")
    }
    
    func testSideEffect() {
        var sideEffectOccurred = false
        stateMachine = StateMachine(initialState: .stopped, transitions: transitions) { result in
            if case .success(let transition) = result, transition.sideEffect == .logPlay {
                sideEffectOccurred = true
            }
        }
        stateMachine.apply(.play)
        XCTAssertTrue(sideEffectOccurred)
    }
}
