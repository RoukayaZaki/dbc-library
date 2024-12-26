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
    // Commented for now as constructors has to be public
    // for (var method in element.methods) {
    //   if (!method.name.startsWith('_')) {
    //     throw InvalidGenerationSourceError(
    //       'Method should not be declared public.',
    //       element: method,
    //     );
    //   }
    // }

    final invariants = annotation.peek('invariantAsserts')?.mapValue ?? {};

    // Generate wrappers for constructors
    final constructorWrappers = element.constructors.map((constructor) {
      return _generateConstructor(
        constructor,
        invariants,
      );
    }).join('\n');
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

      return _generateMethod(
        method,
        preconditionAnnotation,
        postconditionAnnotation,
        invariantAnnotation,
        invariants,
      );
    }).join('\n');

    return '''
    extension on ${element.name} {
      $constructorWrappers
     $generatedMethods
    }
    ''';
  }

  /// Generate wrapper for a constructor
  String _generateConstructor(
      ConstructorElement constructor, Map<dynamic, dynamic> classInvariants) {
    final precondition = _getAnnotation(constructor, Precondition);
    final postcondition = _getAnnotation(constructor, Postcondition);

    final preconditions = precondition?.peek('asserts')?.mapValue ?? {};
    final postconditions = postcondition?.peek('asserts')?.mapValue ?? {};

    // Handle unnamed constructors
    final constructorName =
        constructor.name.isEmpty ? '' : '.${constructor.name}';

    return '''
  factory ${constructor.enclosingElement.name}$constructorName(${constructor.parameters.map((p) => '${p.type} ${p.name}').join(', ')}) {
    ${_generateChecks(classInvariants)}
    ${_generateChecks(preconditions)}
    final instance = ${constructor.enclosingElement.name}$constructorName(${constructor.parameters.map((p) => p.name).join(', ')});
    ${_generateChecks(postconditions)}
    ${_generateChecks(classInvariants)}
    return instance;
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

    // Generate the method body
    final methodBody = '''
    ${method.returnType} ${method.name.replaceFirst('_', '')}(${method.parameters.map((p) => '${p.type} ${p.name}').join(', ')}) {
      ${_generateChecks(classInvariants)}
      ${_generateChecks(preconditions)}
      final result = ${method.name}(${method.parameters.map((p) => p.name).join(', ')});
      ${_generateChecks(postconditions)}
      ${_generateChecks(classInvariants)}
      return result;
    }
    ''';

    return methodBody;
  }

  String _generateChecks(Map<dynamic, dynamic> checks) {
    final sb = StringBuffer();
    checks.forEach((condition, message) {
      sb.writeln('''
      if (!(${condition.toStringValue()})) {
        throw AssertionError('${message.toStringValue()}');
      }
      ''');
    });

    return sb.toString();
  }
}
