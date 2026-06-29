import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:vosk_flutter_service/vosk_flutter_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({final Key? key}) : super(key: key);

  @override
  Widget build(final BuildContext context) =>
      const MaterialApp(home: VoskFlutterDemo());
}

class VoskFlutterDemo extends StatefulWidget {
  const VoskFlutterDemo({final Key? key}) : super(key: key);

  @override
  State<VoskFlutterDemo> createState() => _VoskFlutterDemoState();
}

class _VoskFlutterDemoState extends State<VoskFlutterDemo> {
  static const _textStyle = TextStyle(fontSize: 30, color: Colors.black);
  static const _modelName = 'vosk-model-small-en-us-0.15';
  static const _sampleRate = 16000;

  final _vosk = VoskFlutterPlugin.instance();
  final _modelLoader = ModelLoader();
  final _recorder = Record();

  String? _fileRecognitionResult;
  String? _error;
  Model? _model;
  late Recognizer _recognizer;
  SpeechService? _speechService;

  bool _recognitionStarted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initVosk());
  }

  Future<void> _initVosk() async {
    try {
      final modelsList = await _modelLoader.loadModelsList();
      final modelDescription = modelsList.firstWhere(
        (final model) => model.name == _modelName,
      );
      final modelPath = await _modelLoader.loadFromNetwork(
        modelDescription.url,
      );
      final model = await _vosk.createModel(modelPath);
      if (mounted) {
        setState(() => _model = model);
      }

      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: _sampleRate,
      );

      if (Platform.isAndroid) {
        final speechService = await _vosk.initSpeechService(_recognizer);
        if (mounted) {
          setState(() => _speechService = speechService);
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(final BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Error: $_error', style: _textStyle)),
      );
    } else if (_model == null) {
      return const Scaffold(
        body: Center(child: Text('Loading model...', style: _textStyle)),
      );
    } else if (Platform.isAndroid && _speechService == null) {
      return const Scaffold(
        body: Center(
          child: Text('Initializing speech service...', style: _textStyle),
        ),
      );
    } else {
      return Platform.isAndroid ? _androidExample() : _commonExample();
    }
  }

  Widget _androidExample() => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () async {
              if (_recognitionStarted) {
                await _speechService!.stop();
              } else {
                await _speechService!.start();
              }
              setState(() => _recognitionStarted = !_recognitionStarted);
            },
            child: Text(
              _recognitionStarted ? 'Stop recognition' : 'Start recognition',
            ),
          ),
          StreamBuilder(
            stream: _speechService!.onPartial(),
            builder: (final context, final snapshot) =>
                Text('Partial result: ${snapshot.data}', style: _textStyle),
          ),
          StreamBuilder(
            stream: _speechService!.onResult(),
            builder: (final context, final snapshot) =>
                Text('Result: ${snapshot.data}', style: _textStyle),
          ),
        ],
      ),
    ),
  );

  Widget _commonExample() => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () async {
              if (_recognitionStarted) {
                await _stopRecording();
              } else {
                await _recordAudio();
              }
              setState(() => _recognitionStarted = !_recognitionStarted);
            },
            child: Text(
              _recognitionStarted ? 'Stop recording' : 'Record audio',
            ),
          ),
          Text(
            'Final recognition result: $_fileRecognitionResult',
            style: _textStyle,
          ),
        ],
      ),
    ),
  );

  Future<void> _recordAudio() async {
    try {
      await _recorder.start(
        samplingRate: 16000,
        encoder: AudioEncoder.wav,
        numChannels: 1,
      );
    } on Exception catch (e) {
      _error =
          '$e\n\n Make sure fmedia(https://stsaz.github.io/fmedia/) is installed on Linux';
    }
  }

  Future<void> _stopRecording() async {
    try {
      final filePath = await _recorder.stop();
      if (filePath != null) {
        final bytes = File(filePath).readAsBytesSync();
        await _recognizer.acceptWaveformBytes(bytes);
        _fileRecognitionResult = await _recognizer.getFinalResult();
      }
    } on Exception catch (e) {
      _error =
          '$e\n\n Make sure fmedia(https://stsaz.github.io/fmedia/) is installed on Linux';
    }
  }
}
