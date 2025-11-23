# Custom YAML Test Suite Runner

Runs the test suite data regenerated [here][custom_test_suite]. The raw tests can be found [here][yaml_link]. The runner has been written in `Dart` but it's quite agnostic.

## Usage

The runner is self-contained. You only need to provide a parse function and an object comparator to `TestRunner`.

1. Add this repository.
    - Fork or download if you need to modify it.
    - Alternatively, for your CI or other usecases, you may need to add it as dependency in whichever way you choose. Follow procedures [here][dependencies].

2. Provide an entry point that instantiates the `TestRunner` and runs the test by calling the `runTestSuite` method. The runner has a `TestCounter` that can provide a generic summary and the pass rate of the current run by calling its `getSummary` method.

3. Compile the executable or just run the script using `Dart` itself.

## Who's using it

- [rookie_yaml](https://github.com/kekavc24/rookie_yaml)

[custom_test_suite]: https://github.com/kekavc24/yaml_test_suite_dart
[yaml_link]: https://github.com/yaml/yaml-test-suite
[dependencies]: https://dart.dev/tools/pub/dependencies
