import 'dart:io';

import 'package:path/path.dart' as path;

import 'test_loader.dart';

/// Callback for every failed test.
typedef OnTestFail = void Function(MatrixResult failedTest);

/// Callback used when the test runner has completed running all tests
/// synchronously.
typedef OnRunnerComplete = void Function(String summary);

extension on int {
  /// Calculates the proportion of [this] in [total]
  String asPercentOf(int total) {
    final percent = ((this * 100) / total).toStringAsFixed(2);
    return percent.endsWith('00')
        ? percent.substring(0, percent.length - 3)
        : percent;
  }
}

/// Tracks tests
final class TestRunCounter {
  var _successTests = 0;
  var _errorTests = 0;

  var _failedSuccess = 0;
  var _failedErrors = 0;

  /// Bumps the total test count of success/error tests.
  void bumpCount({required bool isSuccess}) =>
      isSuccess ? ++_successTests : ++_errorTests;

  /// Bumps the failed test count of success/error tests.
  void bumpFail({required bool isSuccess}) =>
      isSuccess ? ++_failedSuccess : ++_failedErrors;

  /// Returns the current test suite summary.
  ({String passRate, String summary}) getSummary() {
    final passSuccess = _successTests - _failedSuccess;
    final errorSuccess = _errorTests - _failedErrors;

    final total = _successTests + _errorTests;
    final passedTests = passSuccess + errorSuccess;
    final passRate = passedTests.asPercentOf(total);

    return (
      passRate: passRate,
      summary:
          '''
Total Tests: $total
Test Summary:
  Total Tests Passing: $passedTests
  Average Pass Accuracy (%): $passRate

  # Tests meant to be parsed correctly that passed
  Success Test Ratio (%):
    Of Success Tests: ${passSuccess.asPercentOf(_successTests)}
    Of Tests Passing: ${passSuccess.asPercentOf(passedTests)}

  # Tests meant to fail that failed
  Error Test Ratio (%):
    Of Error Tests: ${errorSuccess.asPercentOf(_errorTests)}
    Of Tests Passing: ${errorSuccess.asPercentOf(passedTests)}
''',
    );
  }
}

/// A (dummy) output writer.
final class DummyWriter {
  DummyWriter._({required this.onFailed, required this.onComplete});

  /// Called for every failedTest.
  final OnTestFail onFailed;

  /// Called when all tests have been run to completion.
  final OnRunnerComplete onComplete;

  /// Creates a writer that saves a failed test as `.md` file if [saveFailed]
  /// is `true`. Otherwise, ignores it.
  factory DummyWriter.forRunner(String? directory, {required bool saveFailed}) {
    if (!saveFailed) {
      return DummyWriter._(onFailed: (_) {}, onComplete: (_) {});
    }

    final outDir = Directory(
      directory ?? path.join(Directory.current.absolute.path, 'failed'),
    );

    if (outDir.existsSync()) {
      outDir.deleteSync(recursive: true);
    }

    outDir.createSync(recursive: true);
    final fullPath = outDir.absolute.path;

    print('Any failed tests will be saved at: $fullPath');

    return DummyWriter._(
      onFailed: (result) => _saveFailTest(fullPath, result),
      onComplete: (summary) => _createSummary(fullPath, summary),
    );
  }
}

/// Saves the test [summary] in the provided [directory].
void _createSummary(String directory, String summary) => File(
  path.joinAll([directory, '#_summary_#.yaml']),
).writeAsStringSync(summary);

/// Saves a [result] from a failed test in the provided [directory].
void _saveFailTest(String directory, MatrixResult result) {
  final buffer = StringBuffer();
  final (:testID, :description, :testInput, :messageOnFail, :stackTrace) =
      result;

  _writeSection(
    buffer,
    testID,
    description.trimRight(),
    isFileHeader: true,
    wrapInTextBlock: false,
  );

  _writeSection(buffer, 'Test Input', testInput);

  if (messageOnFail.isNotEmpty) {
    _writeSection(buffer, 'Reason Test Failed', messageOnFail);
  }

  if (stackTrace != null) {
    _writeSection(buffer, 'Stack Trace', stackTrace);
  }

  File(
    path.joinAll([directory, '$testID.md']),
  ).writeAsStringSync(buffer.toString());
}

/// Saves the [content] of a single section to an `.md` file storing info
/// about the failed test.
///
/// If [isFileHeader] is `true`, the [header] is written as a `h1` title.
/// Otherwise, `h2` is used by default.
///
/// If [wrapInTextBlock] is `true`, the [content] is wrapped in a text code
/// block.
void _writeSection(
  StringBuffer buffer,
  String header,
  String content, {
  bool isFileHeader = false,
  bool wrapInTextBlock = true,
}) {
  if (buffer.isNotEmpty) buffer.writeln();

  final titleSize = isFileHeader ? '#' : '##';
  final body = wrapInTextBlock ? '```text\n$content\n```' : content;

  buffer
    ..writeln('$titleSize $header')
    ..writeln()
    ..writeln(body);
}
