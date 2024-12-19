import 'package:build/build.dart';
import 'src/contract_generator.dart';
import 'package:source_gen/source_gen.dart';

Builder contractBuilder(BuilderOptions options) => SharedPartBuilder(
      [ContractGenerator()],
      'contract_generator',
    );
