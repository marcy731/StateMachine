import Foundation


// MARK: Protocols


/// Protocol representing a hashable state
public protocol StateHashable: Hashable {}

/// Protocol representing a hashable event
public protocol EventHashable: Hashable {}

/// Protocol representing a hashable side effect
public protocol SideEffectHashable: Hashable {}


// MARK: Transitions


/// Structure to represent a state transition
public struct Transition<S: StateHashable, E: EventHashable, SE: SideEffectHashable> {

    /// The state from which the transition originates
    public let fromState: S

    /// The event that triggers the transition
    public let event: E
    
    /// The state to which the transition leads
    public let toState: S

    /// An optional side effect that is associated with this transition
    public let sideEffect: SE?
    
    /// Initializes a transition
    /// - Parameters:
    ///   - fromState: The starting state
    ///   - event: The event causing the transition
    ///   - toState: The ending state
    ///   - sideEffect: An optional side effect of the transition
    public init(
        from fromState: S,
        on event: E,
        to toState: S,
        with sideEffect: SE? = nil
    ) {
        self.fromState = fromState
        self.event = event
        self.toState = toState
        self.sideEffect = sideEffect
    }
    
    /// Description for the transition, including the from state, to state, event, and any associated side effect.
    public var description: String {
        var description = "State.\(fromState) -> Stete.\(toState) on Event.\(event)"
        if let sideEffect {
            description += " with SideEffect.\(sideEffect)"
        }
        return description
    }
}


// MARK: Errors


/// Enum representing errors in the state machine
public enum StateMachineError<S: StateHashable, E: EventHashable>: Error, CustomStringConvertible {

    /// An error case indicating that a transition was attempted from the given state with the given event, but no such transition was defined.
    case undefinedTransition(currentState: S, event: E)
    
    public var description: String {
        switch self {
        case .undefinedTransition(let currentState, let event):
            return "Undefined transition was attempted from state \(currentState) with event \(event)."
        }
    }

}


// MARK: StateMachine


/// Generic state machine class
open class StateMachine<S: StateHashable, E: EventHashable, SE: SideEffectHashable> {

    /// Structure to represent a unique key for a transition
    /// This key is used to map an event in a particular state to a specific transition
    private struct TransitionKey<S: StateHashable, E: EventHashable>: Hashable {
        let state: S
        let event: E
    }

    /// Represents the current state of the state machine.
    private var currentState: S
    
    /// A mapping from a combination of state and event to the transition that should be taken.
    private var transitionMapping: [TransitionKey<S, E>: Transition<S, E, SE>] = [:]

    /// A callback invoked when a transition is applied. Returns either a successful transition or an error.
    private var onTransition: ((Result<Transition<S, E, SE>, StateMachineError<S, E>>) -> Void)?
    
    /// Initializes the state machine
    /// - Parameters:
    ///   - initialState: The initial state
    ///   - transitions: An array of transitions
    ///   - onTransition: A callback for handling transition results
    public init(
        initialState: S,
        transitions: [Transition<S, E, SE>],
        onTransition: ((Result<Transition<S, E, SE>, StateMachineError<S, E>>) -> Void)? = nil
    ) {
        self.currentState = initialState
        self.onTransition = onTransition
        for transition in transitions {
            let key = TransitionKey(state: transition.fromState, event: transition.event)
            self.transitionMapping[key] = transition
        }
    }
    
    /// Applies an event to the state machine, causing a state transition
    /// - Parameter event: The event to apply
    public func apply(_ event: E) {
        let key = TransitionKey(state: currentState, event: event)
        if let transition = transitionMapping[key] {
            currentState = transition.toState
            onTransition?(.success(transition))
        } else {
            let error = StateMachineError.undefinedTransition(currentState: currentState, event: event)
            onTransition?(.failure(error))
        }
    }
    
    /// Property to get the current state
    public var state: S {
        currentState
    }

}
