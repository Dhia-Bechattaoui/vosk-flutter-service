import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vosk_flutter_service/vosk_flutter_service.dart';

const modelAsset = 'assets/models/vosk-model-small-en-us-0.15.zip';

class TestScreen extends StatefulWidget {
  const TestScreen({final Key? key}) : super(key: key);

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();

  Model? _model;
  bool _modelLoading = false;

  Recognizer? _recognizer;
  SpeechService? _speechService;

  String _grammar = 'hello world foo boo';
  int _maxAlternatives = 2;
  String _recognitionError = '';

  String _message = '';

  @override
  Widget build(final BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vosk Demo')),
    body: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 100,
            padding: const EdgeInsets.all(5),
            alignment: Alignment.topLeft,
            decoration: const BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),
            child: Text(_message, style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: ListView(
              children: [
                Text('Model: $_model'),
                btn('model.create', _modelCreate, color: Colors.orange),
                const Divider(color: Colors.grey, thickness: 1),
                Text('Recognizer: $_recognizer'),
                btn(
                  'recognizer.create',
                  _recognizerCreate,
                  color: Colors.green,
                ),
                Row(
                  children: [
                    Flexible(
                      child: btn(
                        'recognizer.setMaxAlternatives',
                        _recognizerSetMaxAlternatives,
                        color: Colors.green,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        _maxAlternatives.toString(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Flexible(
                      child: Slider(
                        value: _maxAlternatives.toDouble(),
                        max: 3,
                        divisions: 3,
                        onChanged: (final val) => setState(() {
                          _maxAlternatives = val.toInt();
                        }),
                      ),
                    ),
                  ],
                ),
                btn(
                  'recognizer.setWords',
                  _recognizerSetWords,
                  color: Colors.green,
                ),
                btn(
                  'recognizer.setPartialWords',
                  _recognizerSetPartialWords,
                  color: Colors.green,
                ),
                Row(
                  children: [
                    Flexible(
                      child: btn(
                        'recognizer.setGrammar',
                        _recognizerSetGrammar,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Flexible(
                      child: TextField(
                        style: const TextStyle(color: Colors.black),
                        controller: TextEditingController(text: _grammar),
                        onChanged: (final val) => setState(() {
                          _grammar = val;
                        }),
                      ),
                    ),
                  ],
                ),
                btn(
                  'recognizer.acceptWaveForm',
                  _recognizerAcceptWaveForm,
                  color: Colors.green,
                ),
                btn(
                  'recognizer.getResult',
                  _recognizerGetResult,
                  color: Colors.green,
                ),
                btn(
                  'recognizer.getPartialResult',
                  _recognizerGetPartialResult,
                  color: Colors.green,
                ),
                btn(
                  'recognizer.getFinalResult',
                  _recognizerGetFinalResult,
                  color: Colors.green,
                ),
                btn('recognizer.reset', _recognizerReset, color: Colors.green),
                btn('recognizer.close', _recognizerClose, color: Colors.green),
                const Divider(color: Colors.grey, thickness: 1),
                Text('SpeechService: $_speechService'),
                btn(
                  'speechService.init',
                  _initSpeechService,
                  color: Colors.lightBlueAccent,
                ),
                btn(
                  'speechService.start',
                  _speechServiceStart,
                  color: Colors.lightBlueAccent,
                ),
                btn(
                  'speechService.stop',
                  _speechServiceStop,
                  color: Colors.lightBlueAccent,
                ),
                btn(
                  'speechService.setPause',
                  _speechServiceSetPause,
                  color: Colors.lightBlueAccent,
                ),
                btn(
                  'speechService.reset',
                  _speechServiceReset,
                  color: Colors.lightBlueAccent,
                ),
                btn(
                  'speechService.cancel',
                  _speechServiceCancel,
                  color: Colors.lightBlueAccent,
                ),
                btn(
                  'speechService.destroy',
                  _speechServiceDestroy,
                  color: Colors.lightBlueAccent,
                ),
                const SizedBox(height: 20),
                if (_speechService != null)
                  StreamBuilder(
                    stream: _speechService?.onPartial(),
                    builder: (final _, final snapshot) =>
                        Text('Partial: ${snapshot.data}'),
                  ),
                if (_speechService != null)
                  StreamBuilder(
                    stream: _speechService?.onResult(),
                    builder: (final _, final snapshot) =>
                        Text('Result: ${snapshot.data}'),
                  ),
                if (_speechService != null)
                  Text('Recognition error: $_recognitionError'),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget btn(
    final String text,
    final VoidCallback onPressed, {
    final Color? color,
  }) => ElevatedButton(
    onPressed: onPressed,
    style: ButtonStyle(backgroundColor: WidgetStateProperty.all(color)),
    child: Text(text),
  );

  void _toastFutureError(final Future<Object?> future) => future.onError(
    (final error, final _) => _showMessage(msg: error.toString()),
  );

  Future<void> _modelCreate() async {
    if (_model != null) {
      _showMessage(msg: 'The model is already loaded');
      return;
    }

    if (_modelLoading) {
      _showMessage(msg: 'The model is loading right now');
      return;
    }
    _modelLoading = true;

    _toastFutureError(
      _vosk
          .createModel(await ModelLoader().loadFromAssets(modelAsset))
          .then((final value) => setState(() => _model = value)),
    );
  }

  Future<void> _recognizerCreate() async {
    final localModel = _model;
    if (localModel == null) {
      _showMessage(msg: 'Create the model first');
      return;
    }

    _toastFutureError(
      _vosk
          .createRecognizer(model: localModel, sampleRate: 16000)
          .then((final value) => setState(() => _recognizer = value)),
    );
  }

  Future<void> _recognizerSetMaxAlternatives() async {
    final localRecognizer = _recognizer;
    if (localRecognizer == null) {
      _showMessage(msg: 'Create the recognizer first');
      return;
    }

    _toastFutureError(localRecognizer.setMaxAlternatives(_maxAlternatives));
  }

  Future<void> _recognizerSetWords() async {
    final localRecognizer = _recognizer;
    if (localRecognizer == null) {
      _showMessage(msg: 'Create the recognizer first');
      return;
    }

    _toastFutureError(localRecognizer.setWords(words: true));
  }

  Future<void> _recognizerSetPartialWords() async {
    final localRecognizer = _recognizer;
    if (localRecognizer == null) {
      _showMessage(msg: 'Create the recognizer first');
      return;
    }

    _toastFutureError(localRecognizer.setPartialWords(partialWords: true));
  }

  Future<void> _recognizerSetGrammar() async {
    final localRecognizer = _recognizer;
    if (localRecognizer == null) {
      _showMessage(msg: 'Create the recognizer first');
      return;
    }

    _toastFutureError(localRecognizer.setGrammar(_grammar.split(' ')));
  }

  Future<void> _recognizerAcceptWaveForm() async {
    final localRecognizer = _recognizer;
    if (localRecognizer == null) {
      _showMessage(msg: 'Create the recognizer first');
      return;
    }

    _toastFutureError(
      localRecognizer
          .acceptWaveformBytes(
            (await rootBundle.load(
              'assets/audio/test.wav',
            )).buffer.asUint8List(),
          )
          .then((final value) => _showMessage(msg: value.toString())),
    );
  }

  Future<void> _recognizerGetResult() async {
    final localRecognizer = _recognizer;
    if (localRecognizer == null) {
      _showMessage(msg: 'Create the recognizer first');
      return;
    }

    _toastFutureError(
      localRecognizer.getResult().then(
        (final value) => _showMessage(msg: value),
      ),
    );
  }

  Future<void> _recognizerGetPartialResult() async {
    final localRecognizer = _recognizer;
    if (localRecognizer == null) {
      _showMessage(msg: 'Create the recognizer first');
      return;
    }

    _toastFutureError(
      localRecognizer.getPartialResult().then(
        (final value) => _showMessage(msg: value),
      ),
    );
  }

  Future<void> _recognizerGetFinalResult() async {
    final localRecognizer = _recognizer;
    if (localRecognizer == null) {
      _showMessage(msg: 'Create the recognizer first');
      return;
    }

    _toastFutureError(
      localRecognizer.getFinalResult().then(
        (final value) => _showMessage(msg: value),
      ),
    );
  }

  Future<void> _recognizerReset() async {
    final localRecognizer = _recognizer;
    if (localRecognizer == null) {
      _showMessage(msg: 'Create the recognizer first');
      return;
    }

    _toastFutureError(localRecognizer.reset());
  }

  Future<void> _recognizerClose() async {
    final localRecognizer = _recognizer;
    if (localRecognizer == null) {
      _showMessage(msg: 'Create the recognizer first');
      return;
    }

    _toastFutureError(
      localRecognizer.dispose().then((final _) => _recognizer = null),
    );
  }

  Future<void> _initSpeechService() async {
    final localRecognizer = _recognizer;
    if (localRecognizer == null) {
      _showMessage(msg: 'Create the recognizer first');
      return;
    }

    _toastFutureError(
      _vosk
          .initSpeechService(localRecognizer)
          .then((final value) => setState(() => _speechService = value)),
    );
  }

  Future<void> _speechServiceStart() async {
    final localSpeechService = _speechService;
    if (localSpeechService == null) {
      _showMessage(msg: 'Create the speech service first');
      return;
    }

    _toastFutureError(
      localSpeechService
          .start(
            onRecognitionError: (final Object error) =>
                setState(() => _recognitionError = error.toString()),
          )
          .then((final value) => _showMessage(msg: value.toString())),
    );
  }

  Future<void> _speechServiceStop() async {
    final localSpeechService = _speechService;
    if (localSpeechService == null) {
      _showMessage(msg: 'Create the speech service first');
      return;
    }

    _toastFutureError(
      localSpeechService.stop().then(
        (final value) => _showMessage(msg: value.toString()),
      ),
    );
  }

  Future<void> _speechServiceSetPause() async {
    final localSpeechService = _speechService;
    if (localSpeechService == null) {
      _showMessage(msg: 'Create the speech service first');
      return;
    }

    _toastFutureError(localSpeechService.setPause(paused: true));
  }

  Future<void> _speechServiceReset() async {
    final localSpeechService = _speechService;
    if (localSpeechService == null) {
      _showMessage(msg: 'Create the speech service first');
      return;
    }

    _toastFutureError(localSpeechService.reset());
  }

  Future<void> _speechServiceCancel() async {
    final localSpeechService = _speechService;
    if (localSpeechService == null) {
      _showMessage(msg: 'Create the speech service first');
      return;
    }

    _toastFutureError(
      localSpeechService.cancel().then(
        (final value) => _showMessage(msg: value.toString()),
      ),
    );
  }

  Future<void> _speechServiceDestroy() async {
    final localSpeechService = _speechService;
    if (localSpeechService == null) {
      _showMessage(msg: 'Create the speech service first');
      return;
    }

    _toastFutureError(
      localSpeechService.dispose().then(
        (final value) => setState(() => _speechService = null),
      ),
    );
  }

  void _showMessage({required final String msg}) {
    setState(() {
      _message = msg;
    });
  }
}
