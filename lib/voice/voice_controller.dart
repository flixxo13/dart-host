import 'dart:async'; // Wichtig für Completer
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceState { idle, listening, processing, speaking }

class VoiceController extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  // Dieser Completer hilft uns zu warten, bis TTS wirklich fertig ist
  Completer<void>? _ttsCompleter;

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
    await _tts.setSpeechRate(0.5); // Etwas langsamer für bessere Erkennung
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() { 
      _state = VoiceState.speaking; 
      notifyListeners(); 
    });

    _tts.setCompletionHandler(() { 
      _state = VoiceState.idle; 
      // Wenn der Completer wartet, schließen wir ihn hier ab
      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _ttsCompleter!.complete();
      }
      notifyListeners(); 
    });

    _tts.setErrorHandler((_) { 
      _state = VoiceState.idle; 
      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _ttsCompleter!.complete();
      }
      notifyListeners(); 
    });

    _isInitialized = sttAvailable;
    notifyListeners();
    return sttAvailable;
  }

  Future<void> startListening() async {
    // Falls er noch spricht, warten wir kurz oder stoppen es
    if (_state == VoiceState.speaking) {
       await _tts.stop();
       _state = VoiceState.idle;
    }

    if (!_isInitialized) return;
    
    _state = VoiceState.listening;
    _partialResult = '';
    notifyListeners();

    await _stt.listen(
      onResult: _onSpeechResult,
      localeId: 'de_DE',
      listenMode: ListenMode.confirmation,
      pauseFor: const Duration(seconds: 3), // Mehr Zeit lassen
      listenFor: const Duration(seconds: 15),
      partialResults: true,
    );
  }

  // Die neue, intelligente speak-Funktion
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    
    await _stt.stop();
    _state = VoiceState.speaking;
    notifyListeners();

    _ttsCompleter = Completer<void>();
    await _tts.speak(text);
    
    // HIER ist die Magie: Wir warten auf den CompletionHandler von oben
    return _ttsCompleter!.future;
  }

  // ... Rest der Klasse (stopListening, _onSpeechResult, etc.) bleibt gleich ...
  
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
    debugPrint("STT ERROR: $error");
    _state = VoiceState.idle;
    notifyListeners();
    onError?.call(error);
  }

  void _handleSttStatus(String status) {
    debugPrint("STT STATUS: $status");
    if (status == 'done' || status == 'notListening') {
      if (_state == VoiceState.listening) {
        _state = VoiceState.idle;
        notifyListeners();
      }
    }
  }

  bool get isListening => _state == VoiceState.listening;
  bool get isSpeaking => _state == VoiceState.speaking;
}
