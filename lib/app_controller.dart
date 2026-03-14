import 'package:flutter/material.dart';
import 'state/game_state_manager.dart';
import 'state/commentary_settings.dart';
import 'voice/voice_controller.dart';
import 'voice/score_parser.dart';
import 'ai/host_ai.dart';
import 'engine/dart_engine.dart';

class AppController extends ChangeNotifier {
  final GameStateManager gameState = GameStateManager();
  final VoiceController voice = VoiceController();
  final HostAI ai = HostAI();
  final CommentarySettings commentary = CommentarySettings();

  bool _isReady = false;
  bool get isReady => _isReady;

  /*Future<void> initialize() async {
    await commentary.load();
    await voice.initialize();
    ai.initialize();
    voice.onResult = _handleVoiceInput;
    _isReady = true;
    notifyListeners();
    await voice.speak('Dart Host bereit. Sage Hey Darts um zu starten.');
  }*/

Future<void> initialize() async {
  await commentary.load();
  await voice.initialize();
  ai.initialize();
  voice.onResult = _handleVoiceInput;
  _isReady = true;
  notifyListeners();
  
  // Wichtig: Wir warten, bis er fertig gesprochen hat, und starten DANN den Listener
  await voice.speak('Dart Host bereit. Sage Hey Darts um zu starten.');
  
  // Hier fehlte der Start-Befehl!
  await voice.startListening(); 
}


  Future<void> _handleVoiceInput(String input) async {
    debugPrint('Voice Input: "$input"');

    switch (gameState.phase) {
      case AppPhase.idle:
        if (_contains(input, ['hey darts', 'hey dart', 'dart host'])) {
          gameState.startSetup();
          await voice.speak(
            'Willkommen bei Dart Host! Sage: Spieler, gefolgt vom Namen. '
            'Zum Beispiel: Spieler Felix.');
        }
        break;

      case AppPhase.addingPlayers:
        if (_contains(input, ['reihenfolge fertig', 'fertig', 'starten', 'weiter'])) {
          if (gameState.pendingPlayers.length >= 2) {
            gameState.confirmPlayers();
            final names = gameState.pendingPlayers.join(' gegen ');
            await voice.speak(
              '$names. Welches Spiel? Sage zum Beispiel: '
              'Spiel dreihundertein oder Spiel fünfhundertein.');
          } else {
            await voice.speak('Bitte mindestens zwei Spieler hinzufügen.');
          }
        } else if (_contains(input, ['spieler'])) {
          final name = _after(input, 'spieler');
          if (name.isNotEmpty) {
            final added = gameState.addPlayer(name);
            if (added) {
              await voice.speak('$name hinzugefügt. ${_playerFeedback()}');
            } else {
              await voice.speak('$name ist bereits dabei oder zu viele Spieler.');
            }
          }
        }
        break;

      case AppPhase.choosingMode:
        if (_contains(input, ['301', 'dreihundertein', 'dreihundert'])) {
          gameState.selectMode('301');
          await _announceStart();
        } else if (_contains(input, ['501', 'fünfhundertein', 'fünfhundert'])) {
          gameState.selectMode('501');
          await _announceStart();
        } else if (_contains(input, ['701', 'siebenhundertein'])) {
          gameState.selectMode('701');
          await _announceStart();
        } else {
          await voice.speak(
            'Nicht verstanden. Sage Spiel dreihundertein oder Spiel fünfhundertein.');
        }
        break;

      case AppPhase.playing:
        await _handlePlaying(input);
        break;

      case AppPhase.gameOver:
        if (_contains(input, ['nochmal', 'neues spiel', 'neu'])) {
          gameState.resetGame();
          await voice.speak('Neues Spiel. Sage Hey Darts um zu beginnen.');
        } else if (_contains(input, ['beenden', 'schluss', 'ende'])) {
          gameState.resetGame();
          await voice.speak('Bis zum nächsten Mal!');
        }
        break;

      default:
        break;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    await voice.startListening();
  }

  Future<void> _handlePlaying(String input) async {
    final intent = ScoreParser.detectIntent(input);

    switch (intent) {
      case InputIntent.score:
        await _processScore(input);
        break;
      case InputIntent.undo:
        final ok = gameState.undoLast();
        if (ok) {
          final p = gameState.engine.currentPlayer;
          await voice.speak('Rückgängig. ${p.name} hat wieder ${p.score} Punkte.');
        } else {
          await voice.speak('Nichts zum Rückgängigmachen.');
        }
        break;
      case InputIntent.queryScore:
        final s = gameState.engine.players
            .map((p) => '${p.name}: ${p.score}').join(', ');
        await voice.speak('Aktueller Stand: $s.');
        break;
      case InputIntent.queryCheckout:
        final p = gameState.engine.currentPlayer;
        await voice.speak(_checkoutText(p.score));
        break;
      case InputIntent.nextPlayer:
        gameState.advanceToNextPlayer();
        final next = gameState.engine.currentPlayer;
        await voice.speak('${next.name} ist dran. Noch ${next.score} Punkte.');
        break;
      case InputIntent.endGame:
        gameState.resetGame();
        await voice.speak('Spiel abgebrochen. Sage Hey Darts für ein neues Spiel.');
        break;
      case InputIntent.repeat:
        await voice.speak(gameState.lastSpokenText);
        break;
      case InputIntent.question:
        final answer = await ai.respond(
          userInput: input,
          gameState: gameState,
          commentary: commentary,
        );
        gameState.setLastSpokenText(answer);
        await voice.speak(answer);
        break;
    }
  }

  Future<void> _processScore(String input) async {
    final parsed = ScoreParser.parse(input);
    if (!parsed.isValid || parsed.throws.isEmpty) {
      await voice.speak('Nicht verstanden. Bitte Punkte nochmal nennen.');
      return;
    }

    final result = gameState.processThrow(parsed.throws);
    if (result == null) return;

    String response = '';

    if (result.isBust) {
      final player = gameState.engine.currentPlayer;
      if (commentary.bustReaction) {
        response = await ai.commentOnEvent(
          eventType: 'BUST',
          gameState: gameState,
          commentary: commentary,
          eventData: {'remaining': player.score},
        );
      } else {
        response = 'Überworfen! ${player.name} bleibt bei ${player.score}.';
      }
      gameState.advanceToNextPlayer();
    } else if (result.isWin) {
      response = await ai.commentOnEvent(
        eventType: 'WIN',
        gameState: gameState,
        commentary: commentary,
      );
    } else {
      final player = gameState.engine.currentPlayer;
      if (result.points == 180 && commentary.celebrateHighScores) {
        response = await ai.commentOnEvent(
          eventType: 'SCORE_180',
          gameState: gameState,
          commentary: commentary,
        );
      } else if (result.points >= 100 && commentary.celebrateHighScores) {
        response = await ai.commentOnEvent(
          eventType: 'HIGH_SCORE',
          gameState: gameState,
          commentary: commentary,
          eventData: {'points': result.points},
        );
      } else if (result.isCheckoutOpportunity && commentary.announceCheckouts) {
        response = await ai.commentOnEvent(
          eventType: 'CHECKOUT_OPPORTUNITY',
          gameState: gameState,
          commentary: commentary,
          eventData: {'checkout': result.checkoutSuggestion},
        );
      } else {
        response = '${result.points} Punkte. ${player.name} hat noch ${player.score}.';
        if (commentary.commentMomentum &&
            gameState.engine.scoreDifference < 20 &&
            gameState.engine.players.length > 1) {
          final mc = await ai.commentOnEvent(
            eventType: 'MOMENTUM',
            gameState: gameState,
            commentary: commentary,
            eventData: {
              'leader': gameState.engine.leadingPlayer.name,
              'diff': gameState.engine.scoreDifference,
            },
          );
          if (mc.isNotEmpty) response = '$response $mc';
        }
      }
      gameState.advanceToNextPlayer();
      final next = gameState.engine.currentPlayer;
      response = '$response ${next.name}, du bist dran.';
    }

    gameState.setLastSpokenText(response);
    await voice.speak(response);
  }

  Future<void> _announceStart() async {
    final e = gameState.engine;
    final modeStr = gameState.selectedMode == GameMode.mode301
        ? 'dreihundertein'
        : gameState.selectedMode == GameMode.mode501
            ? 'fünfhundertein'
            : 'siebenhundertein';
    await voice.speak(
      '$modeStr! Es spielen: ${e.players.map((p) => p.name).join(", ")}. '
      '${e.currentPlayer.name} beginnt. Viel Erfolg!');
  }

  bool _contains(String input, List<String> keywords) {
    final lower = input.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }

  String _after(String input, String keyword) {
    final lower = input.toLowerCase();
    final idx = lower.indexOf(keyword);
    if (idx == -1) return '';
    return input.substring(idx + keyword.length)
        .replaceAll(RegExp(r'^[:, ]+'), '').trim();
  }

  String _playerFeedback() {
    final c = gameState.pendingPlayers.length;
    if (c == 1) return 'Noch mindestens einen Spieler hinzufügen.';
    if (c == 2) return 'Zwei Spieler bereit. Weiteren hinzufügen oder Reihenfolge fertig sagen.';
    return 'Drei Spieler bereit. Sage Reihenfolge fertig.';
  }

  String _checkoutText(int score) {
    if (score > 170) return 'Kein direkter Checkout möglich. Noch $score Punkte.';
    if (score <= 0) return 'Bereits ausgecheckt!';
    const map = {40: 'Double Zwanzig', 32: 'Double Sechzehn', 50: 'Bull',
      36: 'Double Achtzehn', 20: 'Double Zehn', 60: 'Triple Zwanzig'};
    return map[score] != null
        ? 'Für $score Punkte: ${map[score]}.'
        : 'Du brauchst noch $score Punkte.';
  }

  Future<void> toggleListening() async {
    if (voice.isListening) {
      await voice.stopListening();
    } else {
      await voice.startListening();
    }
  }

  @override
  void dispose() {
    voice.dispose();
    super.dispose();
  }
}