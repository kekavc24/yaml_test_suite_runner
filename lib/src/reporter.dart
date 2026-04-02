import 'package:meta/meta.dart';
import 'package:yaml_test_suite_runner/src/test_result.dart';

/// A test reporter for the runner.
abstract class Reporter {
  /// Reports a skipped test.
  void reportSkipped(TestResult result);

  /// Reports a failed test.
  void reportFailed(FailingTest result);

  /// Reports a passing test.
  void reportPassed(TestResult result);
}

typedef _Routing = void Function();

/// A metrics reporter.
mixin class Metrics implements Reporter {
  /// Tests expected to pass that passed.
  var _countPassPassing = 0;

  /// Tests expected to fail that failed.
  var _countPassFailing = 0;

  /// Tests expected to pass that were skipped.
  var _countPassSkipped = 0;

  /// Tests expected to fail that failed.
  var _countFailPassing = 0;

  /// Tests expected to fail that did not fail.
  var _countFailFailing = 0;

  /// Tests expected to fail that were skipped.
  var _countFailSkipped = 0;

  /// Tests that passed.
  int get totalPassing => _countPassPassing + _countFailPassing;

  /// Tests that failed.
  int get totalFailing => _countFailFailing + _countPassFailing;

  /// Tests that were skipped.
  int get totalSkipped => _countFailSkipped + _countPassSkipped;

  /// Tests that actually ran.
  int get totalRan => totalPassing + totalFailing;

  /// Total number of tests.
  int get total => totalSkipped + totalRan;

  /// Count of tests meant to pass.
  int get totalMeantToPass =>
      _countPassPassing + _countPassFailing + _countPassSkipped;

  /// Count of tests meant to fail.
  int get totalMeantToFail =>
      _countFailFailing + _countFailPassing + _countFailSkipped;

  /// Calculates the metrics based on the type of test.
  void _metrics(
    TestResult result, {
    required _Routing ifFail,
    required _Routing ifPass,
  }) => result.test.fail ? ifFail() : ifPass();

  @override
  @mustCallSuper
  void reportFailed(TestResult result) => _metrics(
    result,
    ifFail: () => ++_countFailFailing,
    ifPass: () => ++_countPassFailing,
  );

  @override
  @mustCallSuper
  void reportPassed(TestResult result) => _metrics(
    result,
    ifFail: () => ++_countFailPassing,
    ifPass: () => ++_countPassPassing,
  );

  @override
  @mustCallSuper
  void reportSkipped(TestResult result) => _metrics(
    result,
    ifFail: () => ++_countFailSkipped,
    ifPass: () => ++_countPassSkipped,
  );
}
