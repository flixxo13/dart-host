import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceState { idle, listening, processing, speaking }

class VoiceController extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String _lastRecognized = '';
  String get lastRecognized => _lastRecognized;

  String _partialResult = '';
  String get partialResult => _partialResult;

  Function(String)? onResult;
  Function(String)? onError;

  Future<bool> initialize() async {
    final sttAvailable = await _stt.initialize(
      onError: (error) => _handleSttError(error.errorMsg),
      onStatus: (status) => _handleSttStatus(status),
    );

    await _tts.setLanguage('de-DE');
    await _tts.setSpeechRate(0.9);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() { _state = VoiceState.speaking; notifyListeners(); });
    _tts.setCompletionHandler(() { _state = VoiceState.idle; notifyListeners(); });
    _tts.setErrorHandler((_) { _state = VoiceState.idle; notifyListeners(); });

    _isInitialized = sttAvailable;
    notifyListeners();
    return sttAvailable;
  }

  Future<void> startListening() async {
    if (!_isInitialized || _state == VoiceState.speaking) return;
    await _tts.stop();
    _state = VoiceState.listening;
    _partialResult = '';
    notifyListeners();

    await _stt.listen(
      onResult: _onSpeechResult,
      localeId: 'de_DE',
      listenMode: ListenMode.confirmation,
      pauseFor: const Duration(seconds: 2),
      listenFor: const Duration(seconds: 15),
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    if (_state == VoiceState.listening) {
      await _stt.stop();
      _state = VoiceState.idle;
      notifyListeners();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      _lastRecognized = result.recognizedWords;
      _partialResult = '';
      _state = VoiceState.processing;
      notifyListeners();
      if (_lastRecognized.isNotEmpty) onResult?.call(_lastRecognized);
    } else {
      _partialResult = result.recognizedWords;
      notifyListeners();
    }
  }

  void _handleSttError(String error) {
    _state = VoiceState.idle;
    notifyListeners();
    onError?.call(error);
  }

  void _handleSttStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (_state == VoiceState.listening) {
        _state = VoiceState.idle;
        notifyListeners();
      }
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _stt.stop();
    _state = VoiceState.speaking;
    notifyListeners();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _state = VoiceState.idle;
    notifyListeners();
  }

  bool get isListening => _state == VoiceState.listening;
  bool get isSpeaking => _state == VoiceState.speaking;
  bool get isIdle => _state == VoiceState.idle;

  @override
  void dispose() {
    _stt.stop();
    _tts.stop();
    super.dispose();
  }
}