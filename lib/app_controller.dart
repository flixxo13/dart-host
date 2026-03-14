// lib/app_controller.dart
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

  // =========================================================
  // INITIALISIERUNG
  // =========================================================

  Future<void> initialize() async {
    await commentary.load();
    final ok = await voice.initialize();

    if (!ok) {
      debugPrint('⚠️ STT nicht verfügbar');
    }

    ai.initialize();

    // Zentraler Voice-Callback
    voice.onResult = _handleVoiceInput;

    _isReady = true;
    notifyListeners();

    // Begrüßung sprechen, dann Auto-Loop starten
    await voice.speak('Dart Host bereit. Sage Hey Darts um zu starten.');
    voice.startAutoListen();
  }

  // =========================================================
  // ZENTRALE VOICE-VERARBEITUNG
  // =========================================================

  Future<void> _handleVoiceInput(String input) async {
    if (input.trim().isEmpty) return;
    debugPrint('🎤 Input: "$input" | Phase: ${gameState.phase}');

    switch (gameState.phase) {

      // ── IDLE: Wake Word ──
      case AppPhase.idle:
        if (_containsAny(input, [
          'hey darts', 'hey dart', 'dart host',
          'hey dance', 'hey darts', 'hei darts', // STT-Varianten
        ])) {
          gameState.startSetup();
          await voice.speak(
            'Willkommen bei Dart Host! '
            'Sage: Spieler, gefolgt vom Namen. '
            'Zum Beispiel: Spieler Felix.');
        }
        break;

      // ── SPIELER HINZUFÜGEN ──
      case AppPhase.addingPlayers:
        if (_containsAny(input, [
          'reihenfolge fertig', 'fertig', 'starten',
          'los gehts', 'weiter', 'genug', 'reicht',
        ])) {
          if (gameState.pendingPlayers.length >= 2) {
            gameState.confirmPlayers();
            final names = gameState.pendingPlayers.join(' gegen ');
            await voice.speak(
              '$names. Welches Spiel? '
              'Sage Spiel dreihundertein oder Spiel fünfhundertein.');
          } else {
            await voice.speak(
              'Bitte mindestens zwei Spieler hinzufügen. '
              'Sage zum Beispiel: Spieler Felix.');
          }
        } else if (_containsAny(input, ['spieler', 'player', 'spielerin'])) {
          final name = _extractAfter(input, ['spieler', 'player', 'spielerin']);
          if (name.isNotEmpty) {
            final added = gameState.addPlayer(name);
            if (added) {
              await voice.speak('$name hinzugefügt. ${_playerFeedback()}');
            } else {
              await voice.speak(
                '$name ist bereits dabei, oder es sind schon drei Spieler registriert.');
            }
          } else {
            await voice.speak('Wie heißt der Spieler? Sage zum Beispiel: Spieler Felix.');
          }
        }
        break;

      // ── SPIELMODUS ──
      case AppPhase.choosingMode:
        if (_containsAny(input, ['301', 'dreihundertein', 'dreihundert eins',
            'drei null eins', 'dreihunderteins'])) {
          gameState.selectMode('301');
          await _announceStart();
        } else if (_containsAny(input, ['501', 'fünfhundertein', 'fünfhundert eins',
            'fünf null eins', 'fünfhunderteins'])) {
          gameState.selectMode('501');
          await _announceStart();
        } else if (_containsAny(input, ['701', 'siebenhundertein',
            'sieben null eins'])) {
          gameState.selectMode('701');
          await _announceStart();
        } else {
          await voice.speak(
            'Nicht verstanden. '
            'Sage Spiel dreihundertein für 301 '
            'oder Spiel fünfhundertein für 501.');
        }
        break;

      // ── SPIELEN ──
      case AppPhase.playing:
        await _handlePlaying(input);
        break;

      // ── GAME OVER ──
      case AppPhase.gameOver:
        if (_containsAny(input, ['nochmal', 'neues spiel', 'neu', 'nochmal spielen',
            'wiederholung', 'rematch'])) {
          gameState.resetGame();
          await voice.speak('Neues Spiel! Sage Hey Darts um neu zu beginnen.');
        } else if (_containsAny(input, ['beenden', 'schluss', 'ende', 'aufhören'])) {
          gameState.resetGame();
          await voice.speak('Bis zum nächsten Mal! Auf Wiedersehen.');
        }
        break;

      default:
        break;
    }
  }

  // =========================================================
  // SPIELLOGIK
  // =========================================================

  Future<void> _handlePlaying(String input) async {
    final intent = ScoreParser.detectIntent(input);
    debugPrint('🧠 Intent: $intent für "$input"');

    switch (intent) {

      case InputIntent.score:
        await _processScore(input);
        break;

      case InputIntent.undo:
        final ok = gameState.undoLast();
        if (ok) {
          final p = gameState.engine.currentPlayer;
          await voice.speak(
            'Rückgängig gemacht. ${p.name} hat wieder ${p.score} Punkte.');
        } else {
          await voice.speak('Nichts zum Rückgängigmachen vorhanden.');
        }
        break;

      case InputIntent.queryScore:
        final standings = gameState.engine.players
            .map((p) => '${p.name}: ${p.score}')
            .join(', ');
        await voice.speak('Aktueller Stand — $standings.');
        break;

      case InputIntent.queryCheckout:
        final p = gameState.engine.currentPlayer;
        await voice.speak(_buildCheckoutText(p.score, p.name));
        break;

      case InputIntent.nextPlayer:
        gameState.advanceToNextPlayer();
        final next = gameState.engine.currentPlayer;
        await voice.speak(
          '${next.name} ist dran. Noch ${next.score} Punkte.');
        break;

      case InputIntent.endGame:
        gameState.resetGame();
        await voice.speak(
          'Spiel abgebrochen. Sage Hey Darts für ein neues Spiel.');
        break;

      case InputIntent.repeat:
        final last = gameState.lastSpokenText;
        if (last.isNotEmpty) {
          await voice.speak(last);
        } else {
          await voice.speak('Nichts zum Wiederholen vorhanden.');
        }
        break;

      case InputIntent.question:
        // Freie Frage → Gemini
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
      await voice.speak(
        'Das habe ich nicht verstanden. '
        'Nenne die Punkte bitte nochmal, zum Beispiel: '
        'zwanzig, neunzehn, drei.');
      return;
    }

    debugPrint('🎯 Score: ${parsed.throws} = ${parsed.total}');
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
        response = 'Überworfen! ${player.name} bleibt bei ${player.score} Punkten.';
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
        response =
            '${result.points} Punkte. ${player.name} hat noch ${player.score}.';

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
      response = '$response — ${next.name}, du bist dran!';
    }

    gameState.setLastSpokenText(response);
    await voice.speak(response);
  }

  // =========================================================
  // HILFSFUNKTIONEN
  // =========================================================

  Future<void> _announceStart() async {
    final e = gameState.engine;
    final modeStr = gameState.selectedMode == GameMode.mode301
        ? 'dreihundertein'
        : gameState.selectedMode == GameMode.mode501
            ? 'fünfhundertein'
            : 'siebenhundertein';
    await voice.speak(
      '$modeStr! Es spielen: ${e.players.map((p) => p.name).join(" gegen ")}. '
      '${e.currentPlayer.name} beginnt. Viel Erfolg und gute Würfe!');
  }

  bool _containsAny(String input, List<String> keywords) {
    final lower = input.toLowerCase();
    return keywords.any((kw) => lower.contains(kw.toLowerCase()));
  }

  String _extractAfter(String input, List<String> keywords) {
    final lower = input.toLowerCase();
    for (final kw in keywords) {
      final idx = lower.indexOf(kw.toLowerCase());
      if (idx != -1) {
        final after = input
            .substring(idx + kw.length)
            .replaceAll(RegExp(r'^[:, ]+'), '')
            .trim();
        // Ersten Buchstaben groß schreiben
        if (after.isEmpty) continue;
        return after[0].toUpperCase() + after.substring(1);
      }
    }
    return '';
  }

  String _playerFeedback() {
    final c = gameState.pendingPlayers.length;
    if (c == 1) return 'Noch mindestens einen weiteren Spieler hinzufügen.';
    if (c == 2) {
      return 'Zwei Spieler bereit. '
          'Weiteren hinzufügen oder Reihenfolge fertig sagen.';
    }
    return 'Drei Spieler bereit. Sage Reihenfolge fertig.';
  }

  String _buildCheckoutText(int score, String name) {
    if (score > 170) {
      return 'Kein direkter Checkout möglich. $name braucht noch $score Punkte.';
    }
    if (score <= 1) return 'Bereits ausgecheckt!';

    const map = {
      40: 'Double Zwanzig',
      32: 'Double Sechzehn',
      50: 'Bull',
      36: 'Double Achtzehn',
      20: 'Double Zehn',
      60: 'Triple Zwanzig',
      38: 'Double Neunzehn',
      24: 'Double Zwölf',
    };

    if (map.containsKey(score)) {
      return '$name, du brauchst $score — wirf ${map[score]}.';
    }
    return '$name hat noch $score Punkte übrig.';
  }

  // Manueller Mikrofon-Button
  Future<void> toggleListening() async {
    await voice.toggleListening();
  }

  @override
  void dispose() {
    voice.dispose();
    super.dispose();
  }
}
