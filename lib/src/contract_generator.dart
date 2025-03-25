import 'package:analyzer/dart/constant/value.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:design_by_contract/annotation.dart';

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

    return '''
    extension ${element.name}Extension  on ${element.name} {
      ${constrPreconditionAsserts != null ? constrPreconditionAsserts : ''}
      $generatedMethods
    }
    ''';
    // ommitting the constructor wrappers for now as they can't be introduced in the extension
    // $constructorWrappers
  }
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

/// Generate executable with preconditions, postconditions, and invariants.
String _generateExecutable<T extends ExecutableElement>(
  T executable, {
  Map<DartObject?, DartObject?> preconditions = const {},
  Map<DartObject?, DartObject?> postconditions = const {},
  Map<dynamic, dynamic>? classInvariants = null,
}) {
  final executableBody = '''
    ${executable.returnType} ${executable.name.replaceFirst('_', '')}(${executable.parameters.map((p) => '${p.type} ${p.name}').join(', ')}) ${executable.isAsynchronous ? 'async' : ''} {
      ${classInvariants != null ? _generateChecks(classInvariants) : ''}
      ${_generateChecks(preconditions)}
      final result = ${executable.isAsynchronous ? 'await' : ''} ${executable.name}(${executable.parameters.map((p) => p.name).join(', ')});
      ${_generateChecks(postconditions)}
      ${classInvariants != null ? _generateChecks(classInvariants) : ''}
      return result;
    }
    ''';

  return executableBody;
}

String _generateChecks(Map<dynamic, dynamic> checks) {
  final sb = StringBuffer();
  checks.forEach((condition, message) {
    sb.writeln('assert(${condition.toStringValue()}, "${message.toStringValue()}");');

  });

  return sb.toString();
}
