/// Use this annotation to declare a class as a contract.
///
/// A contract defines rules (invariants) that a class must adhere to.
/// These invariants must always hold true before and after
/// each call to any public method or during object creation.
///
/// Annotated classes should be declared as private classes (e.g., `_ClassName`).
/// A public subclass is automatically generated, extending this private class
/// and enforcing the specified contract checks.
///
/// \[invariantAsserts] is an optional map where:
/// - **Key**: A string representing a condition (a valid Dart expression).
/// - **Value**: A string containing an assertion message that describes what the condition enforces.
///
/// Users define methods with relevant annotations (`@Precondition`, `@Postcondition`, or `@Invariant`).
///
/// Example:
/// ```dart
/// @Contract({
///   'balance >= 0': 'The balance must never be negative.',
/// })
/// class _Wallet {
///   int balance;
///
///   _Wallet(this.balance);
///
///   @Precondition({
///     'amount > 0': 'The deposit amount must be greater than zero.',
///   })
///   @Postcondition({
///     'balance == result': 'The returned balance must match the internal balance.',
///   })
///   int deposit(int amount) {
///     balance += amount;
///     return balance;
///   }
/// }
/// ```
///
/// ### Key Notes:
/// - Annotated classes should be private (e.g., `_ClassName`).
/// - Generated public classes extend the private annotated classes.
/// - Class-level invariants are enforced in all generated public methods.
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

/// Use this annotation to specify preconditions for methods and constructors.
///
/// Preconditions must be satisfied **before** method or constructor execution.
/// They ensure that inputs or state meet required criteria for safe and correct execution.
///
/// \[asserts] is a map where:
/// - **Key**: A Dart expression as a string representing the condition.
/// - **Value**: A human-readable message describing the assertion.
///
/// Preconditions are applied to the corresponding generated public method or constructor.
///
/// Example:
/// ```dart
/// // Constructor with a precondition.
/// @Precondition({
///   'initialBalance >= 0': 'Initial balance must be non-negative.',
/// })
/// _Wallet(this.initialBalance);
///
/// // Method with a precondition.
/// @Precondition({
///   'amount > 0': 'The deposit amount must be greater than zero.',
/// })
/// int deposit(int amount) {
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

/// Use this annotation to specify postconditions for methods.
///
/// Postconditions must be satisfied **after** method execution.
/// They validate method outcomes to ensure results adhere to expectations.
///
/// [asserts] is a map where:
/// - **Key**: A Dart expression as a string. The expression can include `result`, the method's return value.
/// - **Value**: A human-readable message describing the assertion.
///
/// ### Old Values:
/// - The `old` keyword retrieves the value of a class field before method execution.
/// - Usage: `old(<field_name>)`.
/// - Only primitive fields (`int`, `bool`, `double`, `String`) are supported.
/// - Using expressions other than direct class fields within `old` results in an exception.
///
/// Example:
/// ```dart
/// @Postcondition({
///   'result >= 0': 'The result must be non-negative.',
///   'balance == old(balance) + amount': 'Balance must increase correctly.',
/// })
/// int deposit(int amount) => balance += amount;
/// ```
class Postcondition {
  const Postcondition(this.asserts);

  /// A map of conditions and their corresponding assertion messages.
  ///
  /// - **Key**: A Dart expression as a string, representing the condition.
  /// - **Value**: A human-readable message that describes the assertion.
  final Map<String, String> asserts;
}

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
