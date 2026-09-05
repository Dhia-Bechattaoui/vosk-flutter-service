import 'package:flutter/services.dart';

import 'ffi_provider.dart';
import 'generated_vosk_bindings.dart';
import 'vosk_flutter.dart';

/// Class representing the language model loaded by the plugin.
class Model {
  /// Use [VoskFlutterPlugin.createModel] to create a [Model] instance.
  Model(this.path, this._channel, [this.modelPointer, this._voskLibrary]);

  /// Location of this model in the file system.
  final String path;

  /// Pointer to a native model object.
  final Pointer<VoskModel>? modelPointer;

  final VoskLibrary? _voskLibrary;

  // The channel is passed for consistency but currently not used in this class.
  // ignore: unused_field
  final MethodChannel _channel;

  /// Free all model resources.
  void dispose() {
    if (_voskLibrary != null) {
      _voskLibrary.vosk_model_free(modelPointer!);
    }
  }

  @override
  String toString() => 'Model[path=$path, pointer=$modelPointer]';
}
