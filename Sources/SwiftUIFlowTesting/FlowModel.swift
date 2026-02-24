import SwiftUI

/// A model that drives a SwiftUI screen or flow under test.
///
/// Conforming types must be `Observable` reference types whose properties
/// are tracked by the Observation framework (`@Observable` macro). The
/// tester mutates the model in-place via intent methods, then renders
/// the corresponding view to capture snapshots and run assertions.
///
/// Example:
/// ```swift
/// @Observable
/// final class CheckoutModel: FlowModel {
///     var screen: Screen = .cart
///     var isSubmitEnabled = true
///
///     func proceedToPayment() { screen = .payment }
///     func confirmOrder() { screen = .confirmation }
/// }
/// ```
public protocol FlowModel: AnyObject, Observable {}
