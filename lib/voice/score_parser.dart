class ParsedThrow {
  final List<int> throws;
  final int total;
  final bool isValid;
  final String? error;

  ParsedThrow({required this.throws, required this.isValid, this.error})
      : total = throws.fold(0, (a, b) => a + b);
}

class ScoreParser {
  static const Map<String, int> _numberWords = {
    'null': 0, 'eins': 1, 'ein': 1, 'eine': 1, 'zwei': 2, 'drei': 3,
    'vier': 4, 'fünf': 5, 'sechs': 6, 'sieben': 7, 'acht': 8, 'neun': 9,
    'zehn': 10, 'elf': 11, 'zwölf': 12, 'dreizehn': 13, 'vierzehn': 14,
    'fünfzehn': 15, 'sechzehn': 16, 'siebzehn': 17, 'achtzehn': 18,
    'neunzehn': 19, 'zwanzig': 20,
    '0': 0, '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6,
    '7': 7, '8': 8, '9': 9, '10': 10, '11': 11, '12': 12, '13': 13,
    '14': 14, '15': 15, '16': 16, '17': 17, '18': 18, '19': 19, '20': 20,
    'bull': 25, 'bullseye': 50,
  };

  static const Map<String, int> _multipliers = {
    'einmal': 1, 'single': 1,
    'zweimal': 2, 'doppel': 2, 'double': 2,
    'dreimal': 3, 'triple': 3, 'treble': 3,
    '1 mal': 1, '2 mal': 2, '3 mal': 3,
  };

  static const Set<String> _ignoreWords = {
    'fertig', 'weiter', 'okay', 'ok', 'ja', 'nein', 'und', 'dann', 'äh',
  };

  static ParsedThrow parse(String input) {
    final cleaned = input.toLowerCase().trim();
    final direct = _parseDirectScore(cleaned);
    if (direct != null) {
      return ParsedThrow(throws: [direct], isValid: true);
    }
    final throws = _parseThrows(cleaned);
    if (throws.isEmpty) {
      return ParsedThrow(throws: [], isValid: false,
          error: 'Keine Würfe erkannt');
    }
    for (final t in throws) {
      if (t < 0 || t > 60) {
        return ParsedThrow(throws: [], isValid: false,
            error: 'Ungültiger Wert: $t');
      }
    }
    if (throws.length > 3) {
      return ParsedThrow(throws: [], isValid: false,
          error: 'Zu viele Würfe');
    }
    return ParsedThrow(throws: throws, isValid: true);
  }

  static int? _parseDirectScore(String text) {
    const composites = {
      'dreißig': 30, 'vierzig': 40, 'fünfzig': 50, 'sechzig': 60,
      'siebzig': 70, 'achtzig': 80, 'neunzig': 90, 'hundert': 100,
      'einhundert': 100, 'hundertachtzig': 180, 'einhundertachtzig': 180,
    };
    if (composites.containsKey(text)) return composites[text];
    return int.tryParse(text);
  }

  static List<int> _parseThrows(String text) {
    final results = <int>[];
    var normalized = text
        .replaceAll(',', ' ').replaceAll(';', ' ')
        .replaceAll(' und ', ' ').replaceAll('  ', ' ').trim();
    final tokens = normalized.split(' ').where((t) => t.isNotEmpty).toList();

    int i = 0;
    while (i < tokens.length && results.length < 3) {
      final token = tokens[i];
      if (_ignoreWords.contains(token)) { i++; continue; }

      int multiplier = 1;
      bool foundMultiplier = false;

      if (_multipliers.containsKey(token)) {
        multiplier = _multipliers[token]!;
        foundMultiplier = true;
        i++;
      } else if (i + 1 < tokens.length) {
        final twoToken = '$token ${tokens[i + 1]}';
        if (_multipliers.containsKey(twoToken)) {
          multiplier = _multipliers[twoToken]!;
          foundMultiplier = true;
          i += 2;
        }
      }

      if (i >= tokens.length) break;
      final value = _numberWords[tokens[i]];
      if (value != null) {
        final points = value * multiplier;
        if (points >= 0 && points <= 60) results.add(points);
        i++;
      } else {
        i++;
      }
    }
    return results;
  }

  static int? _parseNumber(String token) {
    if (_numberWords.containsKey(token)) return _numberWords[token];
    return int.tryParse(token);
  }

  static InputIntent detectIntent(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.contains('rückgängig') || lower.contains('zurück')) return InputIntent.undo;
    if (lower.contains('stand') || lower.contains('punkte') || lower.contains('wie viel')) return InputIntent.queryScore;
    if (lower.contains('was muss') || lower.contains('checkout') || lower.contains('was soll')) return InputIntent.queryCheckout;
    if (lower.contains('spiel beenden') || lower.contains('abbrechen')) return InputIntent.endGame;
    if (lower.contains('fertig') || lower.contains('weiter') || lower.contains('nächster')) return InputIntent.nextPlayer;
    if (lower.contains('nochmal') || lower.contains('wiederholen')) return InputIntent.repeat;
    final parsed = parse(input);
    if (parsed.isValid && parsed.throws.isNotEmpty) return InputIntent.score;
    return InputIntent.question;
  }
}

enum InputIntent {
  score, undo, queryScore, queryCheckout, nextPlayer, endGame, repeat, question,
}