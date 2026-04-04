import 'dart:async';

import 'package:yaml_test_suite_runner/src/builder.dart';
import 'package:yaml_test_suite_runner/src/reporter.dart';
import 'package:yaml_test_suite_runner/src/test_loader.dart';
import 'package:yaml_test_suite_runner/src/test_result.dart';

/// Callback for loading all documents declared in a YAML string.
typedef MultiDocLoader = List<Object?> Function(String yaml);

/// Callback that checks if a parsed object is valid.
typedef CompareFunc = bool Function(Object? parsed, Object? expected);

/// Runs a [test] and expects it to fail.
void _expectFail(Reporter reporter, MultiDocLoader loader, YamlTest test) {
  try {
    final docs = loader(test.yaml);
    reporter.reportFailed(
      FailingTest(
        test: test,
        resultType: ResultType.expectedFail,
        onFail: 'Expected the test to failed but found a parsed node: $docs',
      ),
    );
  } catch (_) {
    reporter.reportPassed(TestResult.passing(test));
  }
}

/// DTO when a parsed object doesn't match the expected object.
typedef FailedOutputCheck = ({
  String reference,
  String input,
  String error,
  String? trace,
});

/// Checks if any of the available inputs match the [parsed] object.
(PassingResult, List<FailedOutputCheck>) _checkPossibleOutputs(
  List<Object?> parsed,
  MultiDocLoader loader,
  CompareFunc comparator,
  Map<String, String?> toCompare,
) {
  final keyMap = <String, int>{};
  final failedInputs = <FailedOutputCheck>[];

  void setTo(String key, int setting) => keyMap[key] = setting;

  for (final MapEntry(:key, :value) in toCompare.entries) {
    if (value == null) continue;

    try {
      final expected = loader(value);

      if (!comparator(parsed, expected)) {
        setTo(key, 0);
        failedInputs.add((
          reference: key,
          input: value,
          error:
              '''
Expected: $expected
Parsed: $parsed
''',
          trace: null,
        ));
        continue;
      }

      setTo(key, 1);
    } catch (e, s) {
      setTo(key, 0);
      failedInputs.add((
        reference: key,
        input: value,
        error: e.toString(),
        trace: s.toString(),
      ));
    }
  }

  return (
    (
      json: keyMap['json'] ?? -1,
      dump: keyMap['dump'] ?? -1,
      emit: keyMap['emit'] ?? -1,
    ),
    failedInputs,
  );
}

void _expectPassing(
  Reporter reporter,
  MultiDocLoader loader,
  CompareFunc comparator,
  YamlTest test,
) {
  const resultType = ResultType.expectedPass;

  try {
    final YamlTest(:yaml, :emittedYaml, :yamlJson, :yamlDump) = test;

    final docs = loader(test.yaml);
    final (result, failing) = _checkPossibleOutputs(docs, loader, comparator, {
      'json': yamlJson,
      'dump': yamlDump,
      'emit': emittedYaml,
    });

    if (result.anyPassed) {
      reporter.reportPassed(PassingParseTest(test, aggregate: result));
      return;
    }

    reporter.reportFailed(
      FailingTest(test: test, resultType: resultType, onFail: failing),
    );
  } catch (e, s) {
    reporter.reportFailed(
      FailingTest(
        test: test,
        resultType: resultType,
        onFail: <FailedOutputCheck>[
          (reference: '', input: '', error: e.toString(), trace: s.toString()),
        ],
      ),
    );
  }
}

/// Runs a single test.
final class TestRunner {
  TestRunner(
    this.reporter, {
    required this.multiDocLoader,
    required this.comparator,
  });

  /// A reporter for the test.
  final Reporter reporter;

  /// Loads all YAML documents in a single test input.
  final MultiDocLoader multiDocLoader;

  /// Compares the parsed object to the expected object in YAML.
  final CompareFunc comparator;

  /// Runs a [test] from the official YAML Test suite.
  void run(YamlTest test) {
    return test.skip
        ? reporter.reportSkipped(TestResult.skipped(test))
        : test.fail
        ? _expectFail(reporter, multiDocLoader, test)
        : _expectPassing(reporter, multiDocLoader, comparator, test);
  }
}

/// Runs the entire YAML Test Suite.
final class TestSuiteRunner {
  TestSuiteRunner({required this.runner});

  /// Runs a single test.
  final TestRunner runner;

  /// Runs the entire test suite.
  Future<void> runTestSuite() async {
    final testStream = StreamController<YamlTest>();
    final subscription = testStream.stream.listen(runner.run).asFuture<void>();
    loadTests(testStream);
    return subscription;
  }
}
