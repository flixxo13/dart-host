// lib/voice/voice_controller.dart
import 'dart:async';
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

  // Auto-Restart Loop aktiv?
  bool _autoListenActive = false;
  Timer? _restartTimer;
  Timer? _silenceTimer;

  // Completer für TTS-Synchronisation
  Completer<void>? _ttsCompleter;

  // Noise-Filter: minimale Wortanzahl & Länge
  static const int _minWordCount = 1;
  static const int _minCharLength = 2;
  static const Duration _restartDelay = Duration(milliseconds: 300);
  static const Duration _listenTimeout = Duration(seconds: 20);
  static const Duration _pauseTimeout = Duration(seconds: 3);

  Function(String)? onResult;
  Function(String)? onError;

  // =========================================================
  // INITIALISIERUNG
  // =========================================================

  Future<bool> initialize() async {
    try {
      final sttAvailable = await _stt.initialize(
        onError: (error) => _handleSttError(error.errorMsg),
        onStatus: (status) => _handleSttStatus(status),
        debugLogging: false,
      );

      await _tts.setLanguage('de-DE');
      await _tts.setSpeechRate(0.88);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // TTS Callbacks mit Completer-Sync
      _tts.setStartHandler(() {
        _state = VoiceState.speaking;
        notifyListeners();
      });

      _tts.setCompletionHandler(() {
        _ttsCompleter?.complete();
        _ttsCompleter = null;
        _state = VoiceState.idle;
        notifyListeners();
        // Auto-Restart nach TTS
        if (_autoListenActive) {
          _scheduleRestart();
        }
      });

      _tts.setErrorHandler((msg) {
        _ttsCompleter?.complete();
        _ttsCompleter = null;
        _state = VoiceState.idle;
        notifyListeners();
        if (_autoListenActive) _scheduleRestart();
      });

      _tts.setCancelHandler(() {
        _ttsCompleter?.complete();
        _ttsCompleter = null;
        _state = VoiceState.idle;
        notifyListeners();
      });

      _isInitialized = sttAvailable;
      notifyListeners();
      return sttAvailable;
    } catch (e) {
      debugPrint('VoiceController init error: $e');
      return false;
    }
  }

  // =========================================================
  // AUTO-LISTEN LOOP
  // =========================================================

  /// Startet den dauerhaften Hör-Loop
  void startAutoListen() {
    _autoListenActive = true;
    if (_state != VoiceState.speaking) {
      _scheduleRestart();
    }
  }

  /// Stoppt den dauerhaften Hör-Loop
  void stopAutoListen() {
    _autoListenActive = false;
    _restartTimer?.cancel();
    _silenceTimer?.cancel();
    _stt.stop();
    _state = VoiceState.idle;
    notifyListeners();
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(_restartDelay, () {
      if (_autoListenActive && _state != VoiceState.speaking) {
        _startListeningInternal();
      }
    });
  }

  // =========================================================
  // STT INTERN
  // =========================================================

  Future<void> _startListeningInternal() async {
    if (!_isInitialized || _state == VoiceState.speaking) return;
    if (_stt.isListening) await _stt.stop();

    _state = VoiceState.listening;
    _partialResult = '';
    notifyListeners();

    try {
      await _stt.listen(
        onResult: _onSpeechResult,
        localeId: 'de_DE',
        listenMode: ListenMode.confirmation,
        pauseFor: _pauseTimeout,
        listenFor: _listenTimeout,
        partialResults: true,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('STT listen error: $e');
      _state = VoiceState.idle;
      notifyListeners();
      if (_autoListenActive) _scheduleRestart();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      final text = result.recognizedWords.trim();

      // Noise-Filter: zu kurz / zu wenig Wörter → ignorieren
      if (text.length < _minCharLength) {
        _partialResult = '';
        _state = VoiceState.idle;
        notifyListeners();
        if (_autoListenActive) _scheduleRestart();
        return;
      }

      final wordCount = text.split(' ').where((w) => w.isNotEmpty).length;
      if (wordCount < _minWordCount) {
        _partialResult = '';
        _state = VoiceState.idle;
        notifyListeners();
        if (_autoListenActive) _scheduleRestart();
        return;
      }

      _lastRecognized = text;
      _partialResult = '';
      _state = VoiceState.processing;
      notifyListeners();

      debugPrint('✅ STT Final: "$text"');
      onResult?.call(text);
    } else {
      // Partial Result
      _partialResult = result.recognizedWords;
      notifyListeners();
    }
  }

  void _handleSttError(String error) {
    debugPrint('STT Error: $error');
    // Keine Fehler für normale Timeouts anzeigen
    if (error == 'error_speech_timeout' ||
        error == 'error_no_match' ||
        error == 'error_client') {
      _partialResult = '';
      _state = VoiceState.idle;
      notifyListeners();
      if (_autoListenActive) _scheduleRestart();
      return;
    }
    _state = VoiceState.idle;
    notifyListeners();
    onError?.call(error);
    if (_autoListenActive) _scheduleRestart();
  }

  void _handleSttStatus(String status) {
    debugPrint('STT Status: $status');
    if (status == 'done' || status == 'notListening') {
      if (_state == VoiceState.listening) {
        _partialResult = '';
        _state = VoiceState.idle;
        notifyListeners();
        // Auto-Restart wenn kein TTS aktiv
        if (_autoListenActive && _state != VoiceState.speaking) {
          _scheduleRestart();
        }
      }
    }
  }

  // =========================================================
  // TTS — mit Completer-Synchronisation
  // =========================================================

  /// Spricht Text aus und wartet bis fertig
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Laufendes Hören stoppen
    _restartTimer?.cancel();
    if (_stt.isListening) await _stt.stop();

    // Warten bis vorheriges TTS fertig
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      await _tts.stop();
    }

    _ttsCompleter = Completer<void>();
    _state = VoiceState.speaking;
    _partialResult = '';
    notifyListeners();

    await _tts.speak(text);

    // Warten bis TTS fertig (max 30 Sekunden)
    await _ttsCompleter!.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _ttsCompleter?.complete();
        _ttsCompleter = null;
      },
    );
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _ttsCompleter?.complete();
    _ttsCompleter = null;
    _state = VoiceState.idle;
    notifyListeners();
  }

  // =========================================================
  // MANUELLES TOGGLE (Mikrofon-Button)
  // =========================================================

  Future<void> toggleListening() async {
    if (_state == VoiceState.speaking) {
      await stopSpeaking();
      return;
    }
    if (_state == VoiceState.listening) {
      await _stt.stop();
      _state = VoiceState.idle;
      notifyListeners();
    } else {
      await _startListeningInternal();
    }
  }

  // =========================================================
  // GETTER
  // =========================================================

  bool get isListening => _state == VoiceState.listening;
  bool get isSpeaking => _state == VoiceState.speaking;
  bool get isIdle => _state == VoiceState.idle;
  bool get isProcessing => _state == VoiceState.processing;

  @override
  void dispose() {
    _autoListenActive = false;
    _restartTimer?.cancel();
    _silenceTimer?.cancel();
    _stt.stop();
    _tts.stop();
    super.dispose();
  }
}
