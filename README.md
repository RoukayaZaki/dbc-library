# 🧾 Design by Contract for Dart

**A code generation library bringing robust Eiffel-style contracts to Dart. Define constraints like preconditions, postconditions, and invariants using annotations — and let the generator enforce them at runtime!**

---

## ✨ Key Features

- ✅ **@Contract** for class-level invariants  
- ✅ **@Precondition / @Postcondition** for method contracts  
- ✅ **@Invariant** to enforce class invariants only  
- ✅ **@FunctionContract** for top-level functions  
- 🔁 **Support for `old(...)` values** in postconditions  
- 🚫 **Private method enforcement** — generate safe public wrappers

---

## 📦 Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  design_by_contract:
    git:
      url: https://github.com/RoukayaZaki/dbc-library

dev_dependencies:
  build_runner: ^2.4.0
```

---

## 🧠 Usage

### 🏛️ Contract on a Class

```dart
// ignore_for_file: unused_field, unused_element

import 'package:design_by_contract/annotation.dart';

part 'bank_account.g.dart';

@Contract({
  'balance >= overdraftLimit': 'Balance must not be less than the overdraft limit.',
})
class BankAccount {
  double _balance;
  double get balance => _balance;
  
  final double overdraftLimit;

  BankAccount(this._balance, this.overdraftLimit);

  @Invariant()
  void _deposit(double amount) {
    _balance += amount;
  }

  @Invariant()
  void _withdraw(double amount) {
    _balance -= amount;
  }

  @Invariant()
  void _resetAccount() {
    _balance = 0.0;
  }
}
```

To get generated files run (`dart run build_runner build`):

And then you can use your methods and functions. No need to rerun the command if you changed the method or function but you need to rerun it if you changed the conditions in DbC.

---

### 🧪 Using `@FunctionContract` for Functions

```dart
@FunctionContract(
  preconditions: {
    'value > 0': 'Input must be positive.',
  },
  postconditions: {
    'result > value': 'Result should be greater than input.',
  },
)
int _doubleValue(int value) => value * 2;
```

---

## 🧷 Annotations Summary

| Annotation         | Applied To         | Purpose                                                 |
|--------------------|--------------------|----------------------------------------------------------|
| `@Contract`        | Class              | Defines class-level **invariants**                      |
| `@Precondition`    | Private Method     | Conditions that must be true **before** execution       |
| `@Postcondition`   | Private Method     | Conditions that must be true **after** execution        |
| `@Invariant`       | Private Method     | Enforces class invariants before and after execution        |
| `@FunctionContract`| Private Function   | Combines pre and postconditions for top-level functions |

---

## 🔍 `old()` Support

Use `old(fieldName)` inside postconditions to refer to values **before** method execution.

```dart
@Postcondition({
  'balance == old(balance) + amount': 'Balance must update correctly.',
})
```

> Note: Only simple fields are supported for `old()` access.

---

## 👩‍💻 Author

Built by [@RoukayaZaki](https://github.com/RoukayaZaki) and [@Orillio](https://github.com/Orillio).
