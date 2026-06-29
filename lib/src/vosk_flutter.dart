import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../vosk_flutter_service.dart';
import 'ffi_provider.dart';
import 'generated_vosk_bindings.dart';
import 'permission_service.dart';
import 'stubs/io_stub.dart' if (dart.library.io) 'dart:io';
import 'utils.dart';

/// Provides access to the Vosk speech recognition API.
class VoskFlutterPlugin {
  VoskFlutterPlugin._() {
    if (_supportsFFI()) {
      _voskLibrary = _loadVoskLibrary();
    } else if (Platform.isAndroid || Platform.isIOS) {
      _channel.setMethodCallHandler(_methodCallHandler);
    } else {
      throw UnsupportedError(
        'Platform ${Platform.operatingSystem} is not supported',
      );
    }
  }

  late VoskLibrary _voskLibrary;

  /// Get plugin instance.
  ///
  /// ignore:prefer_constructors_over_static_methods
  static VoskFlutterPlugin instance() => _instance ??= VoskFlutterPlugin._();

  static const MethodChannel _channel = MethodChannel('vosk_flutter');
  static VoskFlutterPlugin? _instance;

  late final Map<String, Completer<Model>> _pendingModels = {};
  late final Map<String, Completer<SpeakerModel>> _pendingSpeakerModels = {};

  /// Create a model from model data located at the [modelPath].
  /// See [ModelLoader]
  Future<Model> createModel(final String modelPath) async {
    final completer = Completer<Model>();

    if (_supportsFFI()) {
      unawaited(
        compute(_loadModel, modelPath).then(
          (final modelPointer) => completer.complete(
            Model(modelPath, _channel, Pointer.fromAddress(modelPointer)),
          ),
          onError: completer.completeError,
        ),
      );
    } else if (Platform.isAndroid || Platform.isIOS) {
      _pendingModels[modelPath] = completer;
      await _channel.invokeMethod('model.create', modelPath);
    }
    return completer.future;
  }

  /// Create a spaker model from model data located at the [modelPath].
  /// See [ModelLoader]
  Future<SpeakerModel> createSpeakerModel(final String modelPath) async {
    final completer = Completer<SpeakerModel>();

    _pendingSpeakerModels[modelPath] = completer;
    await _channel.invokeMethod('speakerModel.create', modelPath);
    return completer.future;
  }

  /// Create a recognizer that will use the specified [model] to process
  /// speech. [sampleRate] determines the sample rate of the audio fed to the
  /// recognizer(a mismatch in the sample rate causes accuracy problems).
  ///
  /// You can optionally provide [grammar] for the recognizer, see
  /// [Recognizer.setGrammar] for more details about the grammar usage.
  Future<Recognizer> createRecognizer({
    required final Model model,
    required final int sampleRate,
    final List<String>? grammar,
  }) async {
    if (_supportsFFI()) {
      return using((final arena) {
        final recognizerPointer = grammar == null
            ? _voskLibrary.vosk_recognizer_new(
                model.modelPointer!,
                sampleRate.toDouble(),
              )
            : _voskLibrary.vosk_recognizer_new_grm(
                model.modelPointer!,
                sampleRate.toDouble(),
                jsonEncode(grammar).toCharPtr(arena),
              );
        return Recognizer(
          id: -1,
          model: model,
          sampleRate: sampleRate,
          channel: _channel,
          recognizerPointer: recognizerPointer,
          voskLibrary: _voskLibrary,
        );
      });
    }

    final args = <String, dynamic>{
      'modelPath': model.path,
      'sampleRate': sampleRate,
    };
    if (grammar != null) {
      args['grammar'] = jsonEncode(grammar);
    }
    final id = await _channel.invokeMethod('recognizer.create', args);
    return Recognizer(
      id: id as int,
      model: model,
      sampleRate: sampleRate,
      channel: _channel,
    );
  }

  /// Set speaker model for the recognizer
  Future<void> setSpeakerModel(
    final int recognizerId,
    final SpeakerModel speakerModel,
  ) async {
    await _channel.invokeMethod('recognizer.setSpeakerModel', {
      'recognizerId': recognizerId,
      'speakerModelPath': speakerModel.path,
    });
  }

  /// Init a speech service that will use the provided [recognizer] to process
  /// audio input from the device microphone.
  ///
  /// This method may throw [MicrophoneAccessDeniedException].
  Future<SpeechService> initSpeechService(final Recognizer recognizer) async {
    if (!await PermissionService.requestMicrophonePermission()) {
      throw MicrophoneAccessDeniedException();
    }

    await _channel.invokeMethod('speechService.init', {
      'recognizerId': recognizer.id,
      'sampleRate': recognizer.sampleRate,
    });
    return SpeechService(_channel);
  }

  Future<void> _methodCallHandler(final MethodCall call) async {
    switch (call.method) {
      case 'model.created':
        final modelPath = call.arguments as String;
        _pendingModels.remove(modelPath)?.complete(Model(modelPath, _channel));
      case 'model.error':
        final args = call.arguments as Map;
        final modelPath = args['modelPath'] as String;
        final error = args['error'] as String;
        _pendingModels.remove(modelPath)?.completeError(error);
      case 'speakerModel.created':
        final speakerModelPath = call.arguments as String;
        _pendingSpeakerModels
            .remove(speakerModelPath)
            ?.complete(SpeakerModel(speakerModelPath, _channel));
      case 'speakerModel.error':
        final args = call.arguments as Map;
        final speakerModelPath = args['speakerModelPath'] as String;
        final error = args['error'] as String;
        _pendingSpeakerModels.remove(speakerModelPath)?.completeError(error);
      default:
        log('Unsupported method: ${call.method}', name: 'VOSK_PLUGIN');
    }
  }

  bool _supportsFFI() => Platform.isLinux || Platform.isWindows;

  static VoskLibrary _loadVoskLibrary() {
    String libraryPath;
    if (Platform.isLinux) {
      libraryPath = Platform.environment['LIBVOSK_PATH']!;
    } else if (Platform.isWindows) {
      libraryPath = 'libvosk.dll';
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    final dylib = DynamicLibrary.open(libraryPath);
    return VoskLibrary(dylib);
  }

  /// Method used to load a model in a separate isolate.
  static int _loadModel(final String modelPath) {
    final voskLib = _loadVoskLibrary();
    final modelPointer = using(
      (final arena) => voskLib.vosk_model_new(modelPath.toCharPtr(arena)),
    );

    if (modelPointer == nullptr) {
      // TODO(sergsavchuk): throw a custom error after deletion of the
      // MethodChannel
      // ignore: only_throw_errors
      throw 'Failed to load model';
    }
    return modelPointer.address;
  }
}

/// An exception thrown when the user denies access to the microphone.
class MicrophoneAccessDeniedException implements Exception {
  /// Default constructor for [MicrophoneAccessDeniedException].
  MicrophoneAccessDeniedException();
}
