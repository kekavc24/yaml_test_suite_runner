# Custom YAML Test Suite Runner

Runs the test suite data found [here][yaml_link]. The runner has been written in `Dart` for simplicity.

## Usage

The runner is self-contained. You only need to provide a parse function and an object comparator to `TestRunner`.

1. Add this repository.
    - Fork or download if you need to modify it.
    - Alternatively, for your CI or other usecases, you may need to add it as dependency in whichever way you choose. Follow procedures [here][dependencies].

2. Provide an entry point that instantiates the `TestSuiteRunner` and runs all the tests by calling the `runTestSuite` method.
    - Provide a `TestRunner` that accepts a yaml parsing function, a comparator for equality and a `Reporter`.
    - A simple `Metrics` reporter is implemented if you need it.

## Failed Tests Output

- You need to extend/mix-in the `Metrics` class and override the `reportFailed` method. Alternatively, you may extend/implement its actual super class `Reporter` and override the three methods it provides.

## Who's using it

- [rookie_yaml](https://github.com/kekavc24/rookie_yaml)

[custom_test_suite]: https://github.com/kekavc24/yaml_test_suite_dart
[yaml_link]: https://github.com/yaml/yaml-test-suite
[dependencies]: https://dart.dev/tools/pub/dependencies
