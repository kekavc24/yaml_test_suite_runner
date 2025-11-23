import 'dart:convert';

import 'package:yaml_test_suite_runner/test_loader.dart';
import 'package:yaml_test_suite_runner/utils.dart';

/// YAML parser callback
typedef YamlParser = Object? Function(String yaml);

/// Callback that compares a parsed object and an object matching the expected
/// output
typedef ObjectComparator = bool Function(Object? parsed, Object? toCompare);

/// A single test result
typedef RunnerResult = ({bool failed, MatrixResult result});

/// Parses [jsonOutput]vor [yamlfallback] with the [parseFunction] and compare
/// the object emitted to [parsed] with the [comparator]. Calls [onFail] if the
/// two objects are not equal or [parseFunction] throws an error when parsing
/// [jsonOutput] or [yamlfallback].
void _matchOutput(
  Object? parsed, {
  required String? jsonOutput,
  required String? yamlfallback,
  required YamlParser parseFunction,
  required ObjectComparator comparator,
  required void Function(String outputError, String? trace) onFail,
}) {
  try {
    final toCompare = jsonOutput != null
        ? json.decode(jsonOutput)
        : parseFunction(yamlfallback ?? '');

    if (!comparator(parsed, toCompare)) {
      onFail('''
Expected: $toCompare

Parsed: $parsed''', null);
    }
  } catch (error, stackTrace) {
    onFail(
      'Failed to parse reference output. Parser failed with:'
      '${error.toString().split('\n').map((s) => '\t$s').join('\n')}',
      stackTrace.toString(),
    );
  }
}

/// A trivial runner that run a test in the current thread as a simple
/// program which always catches errors and exceptions and treats them as
/// failures.
final class TestRunner {
  TestRunner(
    this.tests, {
    required this.parseFunction,
    required this.sourceComparator,
  });

  /// [MatrixTest]s to run.
  final Stream<MatrixTest> tests;

  /// Represents the callback used to parse both the yaml test input and the
  /// output that the parser should match against.
  ///
  /// The output is usually present as json. If missing, the `out.yaml` is
  /// used.
  final YamlParser parseFunction;

  /// Represents a callback used to compare the object emitted after calling
  /// the [parseFunction] on:
  ///   - `in.yaml`
  ///   - `jsonToDartStr` or `out.yaml`
  ///
  /// This only ever called if input and output both match. A valid yaml
  /// [parseFunction] should be able to parse both json and yaml.
  final ObjectComparator sourceComparator;

  /// Simple test stat counter
  final counter = TestRunCounter();

  /// Runs all [tests] asynchronously.
  Stream<RunnerResult> runTests() async* {
    await for (final test in tests) {
      yield _runTest(test);
    }
  }

  /// Blocks and runs a single test and returns a [MatrixResult].
  RunnerResult _runTest(MatrixTest test) {
    print(test);
    final MatrixTest(:testID, :description, :testAsYaml) = test;

    String? parserError;
    String? stackTrace;
    var failed = true;

    Object? parsed;

    try {
      parsed = parseFunction(testAsYaml);
      failed = false;
    } catch (e, trace) {
      parserError = e.toString();
      stackTrace = trace.toString();
    }

    switch (test) {
      case SuccessTest(:final jsonAsDartStr, :final yamlFallback):
        {
          counter.bumpCount(isSuccess: true);

          if (failed) {
            counter.bumpFail(isSuccess: true);
            break;
          }

          _matchOutput(
            parsed,
            jsonOutput: jsonAsDartStr,
            yamlfallback: yamlFallback,
            parseFunction: parseFunction,
            comparator: sourceComparator,
            onFail: (outputError, trace) {
              failed = true;
              counter.bumpFail(isSuccess: true);
              parserError = outputError;
              stackTrace = trace;
            },
          );
        }

      case FailTest _:
        {
          counter.bumpCount(isSuccess: false);
          if (failed) {
            failed = false;
            break;
          }

          counter.bumpFail(isSuccess: false);
          parserError = 'Expected test to fail but found parsed node: $parsed';
        }
    }

    return (
      failed: failed,
      result: (
        testID: testID,
        description: description,
        testInput: testAsYaml,
        messageOnFail: parserError ?? '',
        stackTrace: stackTrace,
      ),
    );
  }
}
