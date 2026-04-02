import 'package:yaml_test_suite_runner/src/builder.dart';

enum ResultType {
  passing,
  skipped,
  expectedPass,
  expectedFail
  ;

  bool get passed => this == ResultType.passing;
}

/// A valid test result.
class TestResult {
  TestResult._(this.test, this.result);

  /// Creates a [TestResult] for a skipped [test].
  TestResult.skipped(YamlTest test) : this._(test, ResultType.skipped);

  /// Creates a passing [TestResult] for a [test] that failed but was expected
  /// to fail.
  TestResult.passing(YamlTest test) : this._(test, ResultType.passing);

  /// A valid test in the YAML test suite.
  final YamlTest test;

  /// Summarised test result.
  final ResultType result;
}

/// Generic result for a test expected to pass.
///
/// Each test expected to pass may use (in order of preference):
///   1. json
///   2. dump
///   3. emit
///
/// All tests are run but expects at least one to pass. Returns:
///   - `0` - if failed.
///   - `1` - if passed.
///   - `-1` - if the input was not present.
typedef PassingResult = ({int json, int dump, int emit});

extension CheckResult on PassingResult {
  bool get anyPassed => json == 1 || dump == 1 || emit == 1;
}

/// A passing test.
final class PassingParseTest extends TestResult {
  PassingParseTest(YamlTest test, {required this.aggregate})
    : super._(test, ResultType.passing);

  /// An aggregation of the expected outputs.
  final PassingResult aggregate;
}

/// A failing test.
final class FailingTest extends TestResult {
  FailingTest({
    required YamlTest test,
    required ResultType resultType,
    required this.onFail,
  }) : assert(
         resultType == ResultType.expectedFail ||
             resultType == ResultType.expectedPass,
         'Expected the test to fail but found $resultType',
       ),
       super._(test, resultType);

  /// Captured error on fail.
  ///
  /// If `resultType` is [ResultType.expectedFail], this will be a string.
  /// Otherwise, this will be a `FailedInputCheck`
  final Object? onFail;
}
