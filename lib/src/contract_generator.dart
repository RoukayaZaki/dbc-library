import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:design_by_contract/annotation.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';


class FunctionContractGenerator
    extends GeneratorForAnnotation<FunctionContract> {
  @override
  String generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! FunctionElement) {
      print(element.runtimeType);
      throw InvalidGenerationSourceError(
        'The @FunctionContract annotation can only be applied to functions.',
        element: element,
      );
    }
    if (!element.name.startsWith('_')) {
      throw InvalidGenerationSourceError(
        'Function should not be declared public.',
        element: element,
      );
    }

    final preconditions = annotation.peek('preconditions')?.mapValue ?? {};
    final postconditions = annotation.peek('postconditions')?.mapValue ?? {};

    return _generateExecutable(
      element,
      preconditions: preconditions,
      postconditions: postconditions,
    );
  }
}

class ContractGenerator extends GeneratorForAnnotation<Contract> {
  @override
  String generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'The @Contract annotation can only be applied to classes.',
        element: element,
      );
    }

    for (var method in element.methods) {
      if (!method.name.startsWith('_')) {
        throw InvalidGenerationSourceError(
          'Method should not be declared public.',
          element: method,
        );
      }
    }

    final invariants = annotation.peek('invariantAsserts')?.mapValue ?? {};

    // Collect all private methods with annotations
    final privateMethods = element.methods.where((m) => m.name.startsWith('_'));

    final generatedMethods = privateMethods.map((method) {
      final preconditionAnnotation = _getAnnotation(method, Precondition);
      final postconditionAnnotation = _getAnnotation(method, Postcondition);
      final invariantAnnotation = _getAnnotation(method, Invariant);

      if (preconditionAnnotation == null &&
          postconditionAnnotation == null &&
          invariantAnnotation == null) {
        return '';
      }
      final preconditions =
          preconditionAnnotation?.peek('asserts')?.mapValue ?? {};
      final postconditions =
          postconditionAnnotation?.peek('asserts')?.mapValue ?? {};

      return _generateExecutable(
        method,
        preconditions: preconditions,
        postconditions: postconditions,
        classInvariants: invariants,
      );
    }).join('\n');

    final String? constrPreconditionAsserts =
        _generateConstructorPrecondition(element);

    final String typeParams = '<${element.typeParameters.join(', ')}>';
    final String typeParamsNoBounds =
        '<${element.typeParameters.map((p) => p.name).join(', ')}>';

    return '''
    // Add a map to store old values for specific expressions
    extension ${element.name}Extension${typeParams} on ${element.name}${typeParamsNoBounds} {
      // Map to store old values before method execution
      static final Map<String, dynamic> _oldValues = {};
      
      void _captureValue(String expression, dynamic value) {
        if (value == null || value is int || value is double || value is bool || value is String) {
          // Primitives can be stored directly
          _oldValues[expression] = value;
        } else if (value is List) {
          _oldValues[expression] = List.from(value);
        } else if (value is Map) {
          _oldValues[expression] = Map.from(value);
        } else if (value is Set) {
          _oldValues[expression] = Set.from(value);
        }
      }
      
      // Method to retrieve a captured value
      dynamic old(String expression) {
        if (!_oldValues.containsKey(expression)) {
          throw StateError('No value captured for expression: \$expression');
        }
        return _oldValues[expression];
      }
      
      // Method to clear all captured values
      void _clearOldValues() {
        _oldValues.clear();
      }
      
      ${constrPreconditionAsserts != null ? constrPreconditionAsserts : ''}
      $generatedMethods
    }
    ''';
  }
}

class _OldInvocationCollector extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations;
  _OldInvocationCollector(this.invocations);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'old') {
      invocations.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

Set<String> _extractOldArguments(String condition) {
  const String prefix = 'var _ = ';
  final String code = '$prefix$condition;';
  final parseResult = parseString(content: code, throwIfDiagnostics: false);
  final unit = parseResult.unit;
  final collector = _OldInvocationCollector([]);
  unit.visitChildren(collector);
  return collector.invocations
      .map((inv) => inv.argumentList.arguments.first.toSource().trim())
      .toSet();
}

String _transformOldInvocations(String condition) {
  const String prefix = 'var _ = ';
  final String fullCode = '$prefix$condition;';
  final parseResult = parseString(content: fullCode, throwIfDiagnostics: false);
  final unit = parseResult.unit;
  final collector = _OldInvocationCollector([]);
  unit.visitChildren(collector);
  final invocations = collector.invocations
    ..sort((a, b) => a.offset.compareTo(b.offset));

  final conditionStartOffset = prefix.length;
  final buffer = StringBuffer();
  int lastPos = 0;
  for (final invocation in invocations) {
    final relativeStart = invocation.offset - conditionStartOffset;
    final relativeEnd = invocation.end - conditionStartOffset;
    buffer.write(condition.substring(lastPos, relativeStart));
    final argumentText =
        invocation.argumentList.arguments.first.toSource().trim();
    buffer.write("old('$argumentText')");
    lastPos = relativeEnd;
  }
  buffer.write(condition.substring(lastPos));
  return buffer.toString();
}

String _generateExecutable<T extends ExecutableElement>(
  T executable, {
  Map<DartObject?, DartObject?> preconditions = const {},
  Map<DartObject?, DartObject?> postconditions = const {},
  Map<dynamic, dynamic>? classInvariants,
}) {
  final oldExpressions = <String>{};
  postconditions.keys.forEach((key) {
    final condition = key?.toStringValue() ?? '';
    final oldArgs = _extractOldArguments(condition);
    oldExpressions.addAll(oldArgs);
  });

  final captureOldValues = oldExpressions.map((expr) {
    return '_captureValue(\'$expr\', $expr);';
  }).join('\n      ');

  String typeParams = '';
  if (executable.typeParameters.isNotEmpty) {
    typeParams = '<${executable.typeParameters.join(', ')}>';
  }

  final executableBody = '''
    ${executable.returnType} ${executable.name.replaceFirst('_', '')}$typeParams(${executable.parameters.map((p) => '${p.type} ${p.name}').join(', ')}) ${executable.isAsynchronous ? 'async' : ''} {
      ${classInvariants != null ? _generateChecks(classInvariants) : ''}
      ${_generateChecks(preconditions)}
      ${oldExpressions.isNotEmpty ? '// Capture values before method execution\n      $captureOldValues' : ''}
      final result = ${executable.isAsynchronous ? 'await' : ''} ${executable.name}(${executable.parameters.map((p) => p.name).join(', ')});
      ${_generatePostconditionChecks(postconditions)}
      ${classInvariants != null ? _generateChecks(classInvariants) : ''}
      ${oldExpressions.isNotEmpty ? '// Clear captured values after method execution\n      _clearOldValues();' : ''}
      return result;
    }
    ''';
  return executableBody;
}

ConstantReader? _getAnnotation(Element element, Type type) {
  for (final metadata in element.metadata) {
    final value = metadata.computeConstantValue();
    if (value?.type?.element?.name == type.toString()) {
      return ConstantReader(value);
    }
  }
  return null;
}

String? _generateConstructorPrecondition(
  ClassElement el,
) {
  if (el.constructors.isEmpty) return null;
  final result = el.constructors.map((constructor) {
    final precondition = _getAnnotation(constructor, Precondition);
    if (precondition == null) return '';

    final preconditions = precondition.peek('asserts')?.mapValue ?? {};

    String name = constructor.name;
    if (name.isNotEmpty) {
      name = constructor.name[0].toUpperCase() + constructor.name.substring(1);
    }

    return '''
      void _ensure${name}() {
        ${_generateChecks(preconditions)}
      }
      ''';
  }).join('\n');

  if (result.trim().isEmpty) return null;

  return result;
}

String _generateChecks(Map<dynamic, dynamic> checks) {
  final sb = StringBuffer();
  checks.forEach((condition, message) {
    sb.writeln(
        'assert(${condition.toStringValue()}, "${message.toStringValue()}");');
  });

  return sb.toString();
}

String _generatePostconditionChecks(Map<dynamic, dynamic> postconditions) {
  final sb = StringBuffer();
  postconditions.forEach((condition, message) {
    String conditionStr = condition.toStringValue() ?? '';
    conditionStr = _transformOldInvocations(conditionStr);
    sb.writeln('assert($conditionStr, "${message.toStringValue()}");');
  });
  return sb.toString();
}
