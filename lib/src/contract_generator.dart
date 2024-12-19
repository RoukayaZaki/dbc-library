import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:design_by_contract/annotation.dart';

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

    final classElement = element as ClassElement;
    final invariants = annotation.peek('invariantAsserts')?.mapValue ?? {};

    // Collect all private methods with annotations
    final privateMethods = classElement.methods.where((m) => m.name.startsWith('_'));
    final generatedMethods = privateMethods.map((method) {
      final preconditionAnnotation = _getAnnotation(method, Precondition);
      final postconditionAnnotation = _getAnnotation(method, Postcondition);
      final invariantAnnotation = _getAnnotation(method, Invariant);

      return _generateMethod(method, preconditionAnnotation, postconditionAnnotation, invariantAnnotation, invariants);
    }).join('\n');

    return '''
    class ${classElement.name} {
      $generatedMethods
    }
    ''';
  }

  /// Get annotation of a specific type from the element.
  ConstantReader? _getAnnotation(Element element, Type type) {
    for (final metadata in element.metadata) {
      final value = metadata.computeConstantValue();
      if (value?.type?.element?.name == type.toString()) {
        return ConstantReader(value);
      }
    }
    return null;
  }

  /// Generate method with preconditions, postconditions, and invariants.
  String _generateMethod(
      MethodElement method,
      ConstantReader? precondition,
      ConstantReader? postcondition,
      ConstantReader? invariant,
      Map<dynamic, dynamic> classInvariants) {
    final preconditions = precondition?.peek('asserts')?.mapValue ?? {};
    final postconditions = postcondition?.peek('asserts')?.mapValue ?? {};

    final validationCode = StringBuffer();

    // Add preconditions
    preconditions.forEach((condition, message) {
      validationCode.writeln('''
      if (!(${condition?.toStringValue()})) {
        throw AssertionError('${message?.toStringValue()}');
      }
      ''');
    });

    // Add class invariants before execution
    classInvariants.forEach((condition, message) {
      validationCode.writeln('''
      if (!(${condition.toStringValue()})) {
        throw AssertionError('${message.toStringValue()}');
      }
      ''');
    });

    // Generate the method body
    final methodBody = '''
    ${method.returnType} ${method.name.replaceFirst('_', '')}(${method.parameters.map((p) => '${p.type} ${p.name}').join(', ')}) {
      $validationCode
      final result = _${method.name}(${method.parameters.map((p) => p.name).join(', ')});
      ${_generatePostconditionChecks(postconditions)}
      return result;
    }
    ''';

    return methodBody;
  }

  /// Generate postcondition checks.
  String _generatePostconditionChecks(Map<dynamic, dynamic> postconditions) {
    final postconditionChecks = StringBuffer();
    postconditions.forEach((condition, message) {
      postconditionChecks.writeln('''
      if (!(${condition.toStringValue().replaceAll('result', 'result')})) {
        throw AssertionError('${message.toStringValue()}');
      }
      ''');
    });
    return postconditionChecks.toString();
  }
}
