import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:rookie_yaml/rookie_yaml.dart';
import 'package:yaml_test_suite_runner/src/builder.dart';

typedef OnDone = void Function();

mixin Writer<T> on BytesToScalar<T> {
  /// Called when a delegate has completed its node. Provided by a
  /// [CustomTriggers] implementation.
  late OnDone onDone;

  /// Writer for a scalar.
  late CharWriter _buffer;

  /// Actual buffer with the post-processed contents.
  final _stringBuffer = StringBuffer();

  @override
  CharWriter get onWriteRequest => _write;

  /// Shadow for the mutable [_buffer].
  void _write(int char) => _buffer(char);

  @override
  void onComplete() {}
}

/// Helps parse the test suite tags for a test.
final class TestTags extends BytesToScalar<Set<String>> with Writer {
  TestTags(OnDone callDone) {
    onDone = callDone;
    _buffer = _chunked;
  }

  final _tags = <String>{};

  void _chunked(int char) {
    if (char.isWhiteSpace()) {
      _flush();
      return;
    }

    _stringBuffer.writeCharCode(char);
  }

  void _flush() {
    if (_stringBuffer.isEmpty) return;
    _tags.add(_stringBuffer.toString());
    _stringBuffer.clear();
  }

  @override
  Set<String> parsed() {
    _flush();
    onDone();
    return _tags;
  }
}

extension on int {
  bool jsonObjPush() => this == mappingStart || this == flowSequenceStart;

  bool jsonObjPop() => this == mappingEnd || this == flowSequenceEnd;

  int jsonPopPartner() => this == mappingEnd ? mappingStart : flowSequenceStart;

  bool jsonWhite() => switch (this) {
    space || lineFeed || carriageReturn || tab => true,
    _ => false,
  };
}

/// Helps inline multiline json and bypasses `package:rookie_yaml`'s type
/// inference.
final class InlinedJson extends BytesToScalar<String> with Writer {
  InlinedJson(OnDone callDone) {
    onDone = callDone;
    _buffer = _warmUp;
  }

  var _escaped = false;
  var _topLevel = true;

  final _braceLike = ListQueue<int>();

  final _yamlObjs = <String>[];

  void _warmUp(int char) => _bufferChar(char);

  void _rootObj(int char) {
    _yamlObjs.add(_stringBuffer.toString());
    _stringBuffer.clear();
    _bufferChar(char);
  }

  void _skipWhiteSpace(int char) {
    if (char.isWhiteSpace() || char.isLineBreak()) return;
    _topLevel ? _rootObj(char) : _bufferChar(char);
  }

  void _bufferQuoted(int char) {
    _stringBuffer.writeCharCode(char);

    if (_escaped) {
      _escaped = false;
    } else if (char == doubleQuote) {
      _buffer = _skipWhiteSpace;
    } else if (char == backSlash) {
      _escaped = true;
    }
  }

  void _bufferPlain(int char) {
    if (char.jsonWhite()) {
      _buffer = _skipWhiteSpace;
      return;
    }

    _stringBuffer.writeCharCode(char);
  }

  void _jsonObject(int char) {
    _stringBuffer.writeCharCode(char);

    if (char.jsonObjPush()) {
      _braceLike.add(char);
      _topLevel = false;
    } else {
      assert(char.jsonObjPop(), 'Expected "}" or "]"');
      final partner = _braceLike.removeLast();
      assert(partner == char.jsonPopPartner());
      _topLevel = _topLevel || _braceLike.isEmpty;
    }

    _buffer = _skipWhiteSpace;
  }

  void _bufferChar(int char) {
    switch (char) {
      // { } [ ]
      case flowSequenceStart || flowSequenceEnd || mappingStart || mappingEnd:
        _jsonObject(char);

      // : ,
      case flowEntryEnd || mappingValue:
        _stringBuffer.writeCharCode(char);
        _buffer = _skipWhiteSpace;

      // "
      case doubleQuote:
        _stringBuffer.writeCharCode(char);
        _buffer = _bufferQuoted;

      default:
        {
          if (char.jsonWhite()) {
            _buffer = _skipWhiteSpace;
            return;
          }

          _stringBuffer.writeCharCode(char);
          _buffer = _bufferPlain;
        }
    }
  }

  @override
  void onComplete() {
    if (_stringBuffer.isNotEmpty) {
      _yamlObjs.add(_stringBuffer.toString());
      _stringBuffer.clear();
    }
  }

  @override
  String parsed() {
    onDone();
    return _yamlObjs.toString();
  }
}

/// —
const _emDash = 0x2014;

/// »
const _hardTabAlt = 0xBB;

/// ␣
const shadowSpace = 0x2423;

/// ↵
const _shadowLF = 0x21B5;

/// ←
const _shadowCR = 0x2190;

/// ⇔
const _shadowBOM = 0x21D4;

/// ∎
const _drainInput = 0x220E;

/// Helps parse YAML input key in a test suite and bypasses
/// `package:rookie_yaml`'s type inference.
final class YamlInput extends BytesToScalar<String> with Writer {
  YamlInput(OnDone callDone) {
    onDone = callDone;
    _buffer = _writeChar;
  }

  /// Buffers chars leading to a [_hardTabAlt].
  final _tabReplacer = StringBuffer();

  /// Buffers the [char].
  void _writeChar(int char) {
    if (char case _emDash || _hardTabAlt) {
      _buffer = _hardTabs;
      _buffer(char);
      return;
    } else if (char == _drainInput) {
      _buffer = _drain;
      return;
    }

    _stringBuffer.writeCharCode(switch (char) {
      shadowSpace => space,
      _shadowLF => lineFeed,
      _shadowCR => carriageReturn,
      _shadowBOM => unicodeBomCharacterRune,
      _ => char,
    });
  }

  /// Buffers the `-` until a [_hardTabAlt] is seen.
  void _hardTabs(int char) {
    switch (char) {
      // » . Emit hard tab. Clear buffer.
      case _hardTabAlt:
        _tabReplacer.clear();
        _stringBuffer.writeCharCode(tab);

      // - . Wait and see.
      case _emDash:
        _tabReplacer.writeCharCode(char);

      // Safe to write all "-" buffered.
      default:
        _flushReplacer();
        _buffer = _writeChar;
        _buffer(char);
    }
  }

  /// Ignores the next few characters of the scalar.
  void _drain(int _) {}

  /// Flushes the buffer tracking the `-` chars if the [_hardTabAlt] was never
  /// seen.
  void _flushReplacer() {
    if (_tabReplacer.isEmpty) return;
    _stringBuffer.write(_tabReplacer.toString());
    _tabReplacer.clear();
  }

  @override
  String parsed() {
    _flushReplacer();
    onDone();
    return _stringBuffer.toString();
  }
}

/// A fancy string buffer. Bypasses `package:rookie_yaml`'s type inference.
final class GenericString extends BytesToScalar<String> with Writer {
  GenericString([OnDone? callDone]) {
    onDone = callDone ?? (() {});
    _buffer = _stringBuffer.writeCharCode;
  }

  @override
  String parsed() {
    onDone();
    return _stringBuffer.toString();
  }
}

/// Helps parse a test suite yaml file.
final class TestSuiteFile extends SequenceToObject<YamlTest, int> {
  TestSuiteFile(this.controller);

  /// Stream to push tests into.
  final StreamController<YamlTest> controller;

  /// Number of tests seen.
  int tests = 0;

  @override
  void accept(YamlTest input) {
    controller.add(input);
    ++tests;
  }

  @override
  int parsed() => tests;
}

/// Helps parse a single test case within a [TestSuiteFile].
final class TestCase extends MappingToObject<String, Object?, YamlTest> {
  TestCase(this.builder);

  /// Creates a [YamlTest].
  final TestBuilder builder;

  @override
  bool accept(String key, Object? value) {
    switch (key) {
      case 'name':
        builder.name = value as String;

      case 'tags':
        builder.tags = value as Set<String>;

      case 'yaml':
        builder.yaml = value as String;

      case 'json':
        builder.yamlJson = value as String;

      case 'dump':
        builder.yamlDump = value as String;

      case 'emit':
        builder.emittedYaml = value as String;

      case 'fail':
        builder.fail = bool.parse(value.toString());

      case 'skip':
        builder.skip = bool.parse(value.toString());

      default:
        break;
    }

    return true;
  }

  @override
  YamlTest parsed() => builder.build();
}
