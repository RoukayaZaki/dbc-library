/// Use this annotation to declare a class as a contract.
///
/// A contract is a set of rules (invariants) that the class must adhere to.
/// These invariants are conditions that must always hold true before and after
/// each call to any public method or during object creation.
///
/// [invariantAsserts] is an optional map where:
/// - **Key**: A string representing a condition (a valid Dart expression).
/// - **Value**: A string containing an assertion message that describes what the condition enforces.
///
/// Users should define private methods (e.g., `_methodName`)
/// with relevant annotations (`@Precondition`, `@Postcondition`, or `@Invariant`).
/// Public methods are generated by the package, which enforce the specified contract checks.
///
/// Example:
/// ```dart
/// @Contract({
///   'balance >= 0': 'The balance must never be negative.',
/// })
/// class Wallet {
///   final int balance;
///
///   Wallet(this.balance);
///
///   // Private method with preconditions and postconditions.
///   @Precondition({
///     'amount > 0': 'The deposit amount must be greater than zero.',
///   })
///   @Postcondition({
///     'balance == result': 'The returned balance must match the internal balance.',
///   })
///   int _deposit(int amount) {
///     return balance + amount;
///   }
/// }
/// ```
///
/// ### Key Notes:
/// - **Private Methods Only**: Users define private methods (e.g., `_methodName`).
/// - **Generated Public Methods**:
///   - Public methods (e.g., `methodName`) are automatically generated by the package.
///   - Generated public methods include all necessary preconditions, postconditions, and invariant checks.
/// - **Class-Level Invariants**:
///   - Declared using `@Contract` and enforced in all generated public methods.
///
/// If a condition evaluates to `false`, an error is raised with the associated assertion message.
class Contract {
  const Contract([this.invariantAsserts]);

  /// A map of conditions and their corresponding assertion messages.
  ///
  /// - **Key**: A Dart expression as a string, representing the condition.
  /// - **Value**: A human-readable message that describes the assertion.
  final Map<String, String>? invariantAsserts;
}

/// Use this annotation to specify preconditions for a private method.
///
/// Preconditions are conditions that must be satisfied **before** the method is executed.
/// These conditions ensure that the inputs or state of the system meet the required criteria
/// for the method to execute safely and correctly.
///
/// [asserts] is a map where:
/// - **Key**: A string representing a condition (a valid Dart expression).
/// - **Value**: A string containing an assertion message that describes what the condition enforces.
///
/// Preconditions are applied to the public method generated from the annotated private method.
///
/// Example:
/// ```dart
/// // Private method with a precondition.
/// @Precondition({
///   'amount > 0': 'The deposit amount must be greater than zero.',
/// })
/// int _deposit(int amount) {
///   return balance + amount;
/// }
/// ```
class Precondition {
  const Precondition(this.asserts);

  /// A map of conditions and their corresponding assertion messages.
  ///
  /// - **Key**: A Dart expression as a string, representing the condition.
  /// - **Value**: A human-readable message that describes the assertion.
  final Map<String, String> asserts;
}

/// Use this annotation to specify postconditions for a private method.
///
/// Postconditions are conditions that must be satisfied **after** the method is executed.
/// These conditions validate the method's outcome, ensuring that the method's effects
/// or returned results adhere to expectations.
///
/// [asserts] is a map where:
/// - **Key**: A string representing a condition (a valid Dart expression).
///   The condition can include a special variable `result`, which represents the value returned by the method.
/// - **Value**: A string containing an assertion message that describes what the condition enforces.
///
/// Postconditions are applied to the public method generated from the annotated private method.
///
/// Example:
/// ```dart
/// @Postcondition({
///   'result >= 0': 'The result must be non-negative.',
/// })
/// int _calculateTotal(int value) {
///   return value * 2;
/// }
/// ```
class Postcondition {
  const Postcondition(this.asserts);

  /// A map of conditions and their corresponding assertion messages.
  ///
  /// - **Key**: A Dart expression as a string, representing the condition.
  /// - **Value**: A human-readable message that describes the assertion.
  final Map<String, String> asserts;
}

/// Use this annotation to enforce class-level invariants on a private method.
///
/// The `@Invariant` annotation ensures that the invariants specified in the `@Contract` annotation
/// are checked **before** and **after** the execution of the annotated private method.
///
/// This annotation is intended for private methods that do not have explicit
/// `@Precondition` or `@Postcondition` annotations. It does not specify its own conditions but ensures
/// the class-level invariants are upheld.
///
/// Invariants are applied to the public method generated from the annotated private method.
///
/// Example:
/// ```dart
/// @Contract({
///   'balance >= 0': 'Balance must never be negative.',
/// })
/// class BankAccount {
///   int balance = 0;
///
///   @Invariant()
///   void _resetBalance() {
///     balance = 0;
///   }
/// }
/// ```
///
/// ### Key Notes:
/// - `@Invariant` applies the invariants declared in the `@Contract` annotation.
/// - This annotation is used for private methods without `@Precondition` or `@Postcondition`.
/// - Invariants are checked **before** and **after** the execution of the private method.
class Invariant {
  const Invariant();
}

final Invariant invariant = Invariant();

/// Use this annotation to specify both preconditions and postconditions for a private function.
///
/// The `@FunctionContract` annotation allows defining constraints that must be satisfied **before** (preconditions)
/// and **after** (postconditions) the execution of a private function. These conditions help ensure that the function
/// behaves correctly.
///
/// - **Preconditions**: Conditions that must be met before the function executes.
/// - **Postconditions**: Conditions that must hold true after the function completes execution.
///
/// [preconditions] and [postconditions] are optional maps where:
/// - **Key**: A string representing a condition (a valid Dart expression).
/// - **Value**: A string containing an assertion message that describes what the condition enforces.
///
/// Preconditions and postconditions are applied to the public function generated from the annotated private function.
///
/// Example:
/// ```dart
/// @FunctionContract(
///   preconditions: {
///     'value > 0': 'Input value must be greater than zero.',
///   },
///   postconditions: {
///     'result > value': 'The result must be greater than the input value.',
///   },
/// )
/// int _doubleValue(int value) {
///   return value * 2;
/// }
/// ```
///
/// ### Key Notes:
/// - **Combines Precondition and Postcondition Checks**: Allows specifying both in a single annotation.
/// - **Applied to Top-Level Private function**: The conditions are checked in the public function generated by the package.
///
/// If a condition evaluates to `false`, an error is raised with the associated assertion message.
class FunctionContract {
  const FunctionContract({
    this.preconditions,
    this.postconditions,
  });

  /// A map of preconditions and their corresponding assertion messages.
  ///
  /// - **Key**: A Dart expression as a string, representing the condition.
  /// - **Value**: A human-readable message that describes the assertion.
  final Map<String, String>? preconditions;

  /// A map of postconditions and their corresponding assertion messages.
  ///
  /// - **Key**: A Dart expression as a string, representing the condition.
  /// - **Value**: A human-readable message that describes the assertion.
  final Map<String, String>? postconditions;
}