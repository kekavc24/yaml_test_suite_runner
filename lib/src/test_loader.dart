import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:rookie_yaml/rookie_yaml.dart';
import 'package:yaml_test_suite_runner/src/builder.dart';
import 'package:yaml_test_suite_runner/src/trigger.dart';

const _testSuiteCommitHash = 'da267a5c4782e7361e82889e76c0dc7df0e1e870';
const _repoUrl = 'https://github.com/yaml/yaml-test-suite.git';
const _testDir = 'src';

/// Creates a temporary directory with the [subFolder] as the base.
Directory _createTempDir(String subFolder) {
  final pathToDir = path.joinAll([Directory.systemTemp.path, subFolder]);
  final dir = Directory(pathToDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

/// Fetches the YAML test suite and checks out the head at the
/// [_testSuiteCommitHash].
Directory _fetchYamlTestSuite() {
  final suite = _createTempDir('yaml-test-suite');
  final fullPath = suite.absolute.path;

  void runGit(List<String> args) =>
      Process.runSync('git', args, workingDirectory: fullPath);

  runGit(['init']); // Faux repo. No cloning, baby.
  runGit(['remote', 'add', 'origin', _repoUrl]);
  runGit(['fetch', 'origin', _testSuiteCommitHash]);
  runGit(['checkout', 'FETCH_HEAD']);
  return suite;
}

/// Fetches the YAML test suite files.
Stream<File> fetchTests() {
  return Directory(path.joinAll([_fetchYamlTestSuite().path, _testDir]))
      .list()
      .where((fs) => fs is File && path.extension(fs.path).endsWith('yaml'))
      .cast<File>();
}

/// Loads the yaml test suite files and adds them to the stream handled by the
/// [controller]. Calls `close` on the [controller] after all the tests have
/// been loaded.
void loadTests(StreamController<YamlTest> controller) async {
  final builder = TestBuilder();
  final trigger = AdvancingTrigger(builder, controller);

  await for (final file in fetchTests()) {
    final testID = path.basenameWithoutExtension(file.path);
    builder.reset = testID;

    loadObject(
      // It would be more efficient to decode the utf8 while parsing. However,
      // `package:rookie_yaml` implements strict utf8 which does not allow
      // malformed code units.
      YamlSource.simpleString(file.readAsStringSync()),
      triggers: trigger,
    );
  }

  await controller.close();
}
