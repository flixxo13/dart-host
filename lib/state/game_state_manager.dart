import 'package:flutter/foundation.dart';
import '../engine/dart_engine.dart';
import 'commentary_settings.dart';

enum AppPhase { idle, addingPlayers, choosingMode, playing, roundResult, gameOver }
enum HostMood { professional, hype, chill, custom }

class GameStateManager extends ChangeNotifier {
  AppPhase _phase = AppPhase.idle;
  AppPhase get phase => _phase;

  List<String> _pendingPlayers = [];
  List<String> get pendingPlayers => _pendingPlayers;

  GameMode _selectedMode = GameMode.mode301;
  GameMode get selectedMode => _selectedMode;

  final DartEngine _engine = DartEngine();
  DartEngine get engine => _engine;

  HostMood _mood = HostMood.hype;
  HostMood get mood => _mood;
  String customMoodPrompt = '';

  ThrowResult? _lastResult;
  ThrowResult? get lastResult => _lastResult;

  String _lastSpokenText = '';
  String get lastSpokenText => _lastSpokenText;

  String _statusMessage = 'Sage "Hey Darts" um zu starten';
  String get statusMessage => _statusMessage;

  void startSetup() {
    _pendingPlayers = [];
    _phase = AppPhase.addingPlayers;
    _statusMessage = 'Spieler hinzufügen: "Spieler: [Name]"';
    notifyListeners();
  }

  bool addPlayer(String name) {
    if (_pendingPlayers.length >= 3) return false;
    if (name.trim().isEmpty) return false;
    if (_pendingPlayers.contains(name.trim())) return false;
    _pendingPlayers.add(name.trim());
    _statusMessage = 'Spieler: ${_pendingPlayers.join(', ')}. '
        '${_pendingPlayers.length < 2 ? "Mindestens 1 weiteren hinzufügen." : "Sage Reihenfolge fertig."}';
    notifyListeners();
    return true;
  }

  bool confirmPlayers() {
    if (_pendingPlayers.length < 2) return false;
    _phase = AppPhase.choosingMode;
    _statusMessage = 'Spielmodus: "Spiel 301", "Spiel 501" oder "Spiel 701"';
    notifyListeners();
    return true;
  }

  bool selectMode(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('301'))      _selectedMode = GameMode.mode301;
    else if (lower.contains('501')) _selectedMode = GameMode.mode501;
    else if (lower.contains('701')) _selectedMode = GameMode.mode701;
    else return false;
    startGame();
    return true;
  }

  void startGame() {
    _engine.setupGame(playerNames: _pendingPlayers, mode: _selectedMode);
    _phase = AppPhase.playing;
    _statusMessage = '${_engine.currentPlayer.name} ist dran!';
    notifyListeners();
  }

  ThrowResult? processThrow(List<int> throws) {
    if (_phase != AppPhase.playing) return null;
    final result = _engine.processRound(throws);
    _lastResult = result;
    if (result.isWin) {
      _phase = AppPhase.gameOver;
      _statusMessage = '🎯 ${_engine.currentPlayer.name} gewinnt!';
    } else if (result.isBust) {
      _statusMessage = 'BUST! ${_engine.currentPlayer.name} bleibt bei ${_engine.currentPlayer.score}.';
    } else {
      _statusMessage = '${result.points} Punkte. ${_engine.currentPlayer.name} hat noch ${_engine.currentPlayer.score}.';
    }
    notifyListeners();
    return result;
  }

  void advanceToNextPlayer() {
    if (_phase == AppPhase.playing || _lastResult?.isBust == true) {
      _engine.nextPlayer();
      _phase = AppPhase.playing;
      _statusMessage = '${_engine.currentPlayer.name} ist dran! (${_engine.currentPlayer.score} übrig)';
      notifyListeners();
    }
  }

  bool undoLast() {
    final success = _engine.undoLastRound();
    if (success) {
      _phase = AppPhase.playing;
      _statusMessage = 'Rückgängig. ${_engine.currentPlayer.name} ist dran.';
      notifyListeners();
    }
    return success;
  }

  void resetGame() {
    _phase = AppPhase.idle;
    _pendingPlayers = [];
    _lastResult = null;
    _statusMessage = 'Sage "Hey Darts" um zu starten';
    notifyListeners();
  }

  void setMood(HostMood mood) {
    _mood = mood;
    notifyListeners();
  }

  String buildAIContext(CommentarySettings commentary) {
    final sb = StringBuffer();
    sb.writeln(_getMoodPrompt());
    sb.writeln('');
    sb.writeln('KOMMENTAR-EINSTELLUNGEN:');
    sb.writeln('- Hohe Scores feiern: ${commentary.celebrateHighScores}');
    sb.writeln('- Checkouts ansagen: ${commentary.announceCheckouts}');
    sb.writeln('- Momentum kommentieren: ${commentary.commentMomentum}');
    sb.writeln('- Tipps geben: ${commentary.giveTips}');
    sb.writeln('');
    if (_phase == AppPhase.playing || _phase == AppPhase.gameOver) {
      sb.writeln(_engine.getGameContext());
    }
    return sb.toString();
  }

  String _getMoodPrompt() => switch (_mood) {
    HostMood.professional => 'Du bist ein professioneller Dart-Moderator wie bei einem TV-Turnier. Sprich sachlich, präzise auf Deutsch. Max 2 Sätze.',
    HostMood.hype         => 'Du bist ein energetischer Dart-Host für einen Pub-Abend! Feuere die Spieler an, mach Stimmung! Deutsch, max 2 Sätze.',
    HostMood.chill        => 'Du bist ein entspannter Dart-Moderator. Locker, nett, kein Druck. Deutsch, kurz und angenehm.',
    HostMood.custom       => customMoodPrompt.isNotEmpty ? customMoodPrompt : 'Du bist ein Dart-Moderator. Sprich Deutsch, kurz und freundlich.',
  };

  void setLastSpokenText(String text) {
    _lastSpokenText = text;
    notifyListeners();
  }
}