import 'package:google_generative_ai/google_generative_ai.dart';
import '../state/commentary_settings.dart';
import '../state/game_state_manager.dart';

class HostAI {
  // ↓↓↓ HIER DEINEN GEMINI API KEY EINTRAGEN ↓↓↓
  static const String _apiKey = 'AIzaSyB6fLm7U61O9IhE8ecax7oz9YG5Xm6coJo';

  late GenerativeModel _model;
  bool _isInitialized = false;

  void initialize() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        maxOutputTokens: 150,
        temperature: 0.8,
      ),
    );
    _isInitialized = true;
  }

  Future<String> respond({
    required String userInput,
    required GameStateManager gameState,
    required CommentarySettings commentary,
    String? eventType,
  }) async {
    if (!_isInitialized) return _fallback(userInput, gameState, eventType);

    try {
      final context = gameState.buildAIContext(commentary);
      final prompt = _buildPrompt(context: context, userInput: userInput, eventType: eventType);
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? _fallback(userInput, gameState, eventType);
    } catch (e) {
      return _fallback(userInput, gameState, eventType);
    }
  }

  Future<String> commentOnEvent({
    required String eventType,
    required GameStateManager gameState,
    required CommentarySettings commentary,
    Map<String, dynamic>? eventData,
  }) async {
    final playerName = gameState.engine.currentPlayer.name;
    final score = gameState.engine.currentPlayer.score;

    String eventPrompt = switch (eventType) {
      'HIGH_SCORE' => 'EREIGNIS: $playerName hat ${eventData?['points']} Punkte geworfen! Kommentiere enthusiastisch!',
      'SCORE_180'  => 'EREIGNIS: $playerName hat 180 geworfen — das Maximum! Reagiere begeistert!',
      'BUST'       => 'EREIGNIS: $playerName hat überworfen und bleibt bei ${eventData?['remaining'] ?? score}. Kommentiere kurz.',
      'CHECKOUT_OPPORTUNITY' => 'EREIGNIS: $playerName kann auschecken! Restpunkte: $score. Empfehlung: ${eventData?['checkout']}. Kündige es an!',
      'MOMENTUM'   => 'EREIGNIS: ${eventData?['leader']} führt mit ${eventData?['diff']} Punkten. Kommentiere die Spannung.',
      'WIN'        => 'EREIGNIS: $playerName hat gewonnen! Feiere den Sieg!',
      _            => '',
    };

    if (eventPrompt.isEmpty) return '';

    return await respond(
      userInput: eventPrompt,
      gameState: gameState,
      commentary: commentary,
      eventType: eventType,
    );
  }

  String _buildPrompt({
    required String context,
    required String userInput,
    String? eventType,
  }) {
    return '''$context

---
${eventType != null ? "SPIELEREIGNIS: $eventType" : "SPIELER FRAGT: $userInput"}

Antworte auf Deutsch in maximal 2 kurzen Sätzen.
Keine Listen, kein Markdown — nur natürliche gesprochene Sprache.
Zahlen ausschreiben (z.B. "zwanzig" statt "20").
''';
  }

  String _fallback(String input, GameStateManager gameState, String? eventType) {
    final name = gameState.engine.currentPlayer.name;
    final score = gameState.engine.currentPlayer.score;

    return switch (eventType) {
      'BUST'      => 'Überworfen! $name bleibt bei $score Punkten.',
      'WIN'       => '$name gewinnt! Herzlichen Glückwunsch!',
      'SCORE_180' => 'Einhundertachtzig! Was für ein Wurf!',
      _           => '$name ist dran. Noch $score Punkte.',
    };
  }
}