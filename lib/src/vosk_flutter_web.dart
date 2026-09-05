/// Web implementation of the Vosk Offline Speech Recognition plugin.
library;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web implementation of the VoskFlutterPlugin.
class VoskFlutterPlugin {
  /// Default constructor for [VoskFlutterPlugin].
  VoskFlutterPlugin();

  /// Registers the plugin with the [registrar].
  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'vosk_flutter_service',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = VoskFlutterPlugin();
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  /// Handles method calls from the method channel.
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getPlatformVersion':
        return 'Web';
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              "vosk_flutter_service for web doesn't implement "
              "'${call.method}'",
        );
    }
  }
}
