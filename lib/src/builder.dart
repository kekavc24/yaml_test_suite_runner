final class TestBuilder {
  /// Test ID for the test
  String testID = '';

  /// Whether the test should fail.
  bool fail = false;

  /// Whether the test should be skipped.
  bool skip = false;

  /// Name for the test. Defaults to the test's ID if missing.
  String? name;

  /// Test tags.
  Set<String>? tags;

  /// Input.
  String? yaml;

  /// JSON string representation of the [yaml] string.
  String? yamlJson;

  /// Dumped YAML string.
  String? yamlDump;

  /// YAML from an emitter.
  String? emittedYaml;

  /// Resets the builder to use the specified [testID].
  set reset(String testID) {
    this.testID = testID;
    fail = skip = false;
    name = yaml = yamlJson = yamlDump = emittedYaml = null;
    tags = null;
  }

  /// Creates a [YamlTest].
  YamlTest build() => YamlTest(
    testID,
    name: name,
    tags: tags,
    input: yaml,
    yamlJson: yamlJson,
    yamlDump: yamlDump,
    emittedYaml: emittedYaml,
    fail: fail,
    skip: skip,
  );
}

/// A test from the official YAML test suite.
final class YamlTest {
  YamlTest(
    this.testID, {
    required this.name,
    required this.tags,
    required String? input,
    required this.yamlJson,
    required this.yamlDump,
    required this.emittedYaml,
    required this.fail,
    required bool skip,
  }) : // Ensure we can run this test.
       skip =
           skip ||
           input == null ||
           (!fail &&
               yamlJson == null &&
               yamlDump == null &&
               emittedYaml == null),
       yaml = input ?? '';

  /// Test ID.
  final String testID;

  /// Name for the test.
  final String? name;

  /// Tags uniquely identifying the test.
  final Set<String>? tags;

  /// Input.
  final String yaml;

  /// JSON string representation of the [yaml] string.
  final String? yamlJson;

  /// Dumped YAML string.
  final String? yamlDump;

  /// YAML from an emitter.
  final String? emittedYaml;

  /// Whether the test should be skipped.
  final bool skip;

  /// Whether the test should fail.
  final bool fail;
}
