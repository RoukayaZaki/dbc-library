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

      return _generateMethod(
        method,
        preconditionAnnotation,
        postconditionAnnotation,
        invariantAnnotation,
        invariants,
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
        name =
            constructor.name[0].toUpperCase() + constructor.name.substring(1);
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
    ${method.returnType} ${method.name.replaceFirst('_', '')}(${method.parameters.map((p) => '${p.type} ${p.name}').join(', ')}) ${method.isAsynchronous ? 'async' : ''} {
      ${_generateChecks(classInvariants)}
      ${_generateChecks(preconditions)}
      final result = ${method.isAsynchronous ? 'await' : ''} ${method.name}(${method.parameters.map((p) => p.name).join(', ')});
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
