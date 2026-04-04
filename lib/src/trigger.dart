import 'dart:async';

import 'package:rookie_yaml/rookie_yaml.dart';
import 'package:yaml_test_suite_runner/src/builder.dart';
import 'package:yaml_test_suite_runner/src/delegates.dart';

/// Switches to an value delegate based on the [key].
OnCustomScalar _fromKey<T>(String? key, OnDone onDone) => switch (key) {
  'json' => () => InlinedJson(onDone),
  'tags' => () => TestTags(onDone),
  'yaml' || 'dump' || 'emit' => () => YamlInput(onDone),
  _ => () => GenericString(onDone),
};

/// A trigger that influences the parser's context based on the key.
final class AdvancingTrigger extends CustomTriggers {
  AdvancingTrigger(this.builder, this.controller) {
    _initKey();
  }

  /// A reusable [YamlTest] builder.
  final TestBuilder builder;

  /// Accepts parsed test cases on the fly.
  final StreamController<YamlTest> controller;

  /// A [CustomResolver] for a scalar.
  late OnCustomScalar<Object?> lazyScalar;

  @override
  void onParsedKey(Object? key) =>
      lazyScalar = _fromKey(key.toString(), _initKey);

  /// Initializes a key scalar.
  void _initKey() => lazyScalar = () => GenericString();

  @override
  ObjectFromScalarBytes<S>? onDefaultScalar<S>() {
    return ObjectFromScalarBytes(
      onCustomScalar: lazyScalar as OnCustomScalar<S>,
    );
  }

  @override
  ObjectFromIterable<E, S>? onDefaultSequence<E, S>() {
    return ObjectFromIterable(onCustomIterable: () => TestSuiteFile(controller))
        as ObjectFromIterable<E, S>;
  }

  @override
  ObjectFromMap<K, V, M>? onDefaultMapping<K, V, M>() {
    return ObjectFromMap(onCustomMap: () => TestCase(builder))
        as ObjectFromMap<K, V, M>;
  }
}
