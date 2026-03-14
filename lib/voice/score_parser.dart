// lib/voice/score_parser.dart
class ParsedThrow {
  final List<int> throws;
  final int total;
  final bool isValid;
  final String? error;

  ParsedThrow({required this.throws, required this.isValid, this.error})
      : total = throws.fold(0, (a, b) => a + b);
}

class ScoreParser {
  // Deutsche Zahlwörter
  static const Map<String, int> _numberWords = {
    'null': 0, 'eins': 1, 'ein': 1, 'eine': 1,
    'zwei': 2, 'drei': 3, 'vier': 4, 'fünf': 5,
    'sechs': 6, 'sieben': 7, 'acht': 8, 'neun': 9,
    'zehn': 10, 'elf': 11, 'zwölf': 12, 'dreizehn': 13,
    'vierzehn': 14, 'fünfzehn': 15, 'sechzehn': 16,
    'siebzehn': 17, 'achtzehn': 18, 'neunzehn': 19, 'zwanzig': 20,
    // Ziffern als Text
    '0': 0, '1': 1, '2': 2, '3': 3, '4': 4,
    '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
    '10': 10, '11': 11, '12': 12, '13': 13, '14': 14,
    '15': 15, '16': 16, '17': 17, '18': 18, '19': 19, '20': 20,
    // Sonderfelder
    'bull': 25, 'bulls': 25, 'bullseye': 50,
    'außenbull': 25, 'innenbull': 50,
    'doppelbull': 50, 'double bull': 50,
  };

  // Multiplikatoren
  static const Map<String, int> _multipliers = {
    // Deutsch
    'einmal': 1, 'einfach': 1, 'single': 1,
    'zweimal': 2, 'doppel': 2, 'double': 2, 'doppelt': 2,
    'dreimal': 3, 'triple': 3, 'treble': 3, 'dreifach': 3,
    // Kurznotation (T20, D16 etc.)
    't': 3, 'd': 2, 's': 1,
    // Zwei-Token
    'zwei mal': 2, 'drei mal': 3, 'ein mal': 1,
    '2 mal': 2, '3 mal': 3, '1 mal': 1,
    '2x': 2, '3x': 3, '1x': 1,
  };

  // Wörter die ignoriert werden
  static const Set<String> _ignoreWords = {
    'fertig', 'weiter', 'okay', 'ok', 'ja', 'nein',
    'und', 'dann', 'also', 'äh', 'ähm', 'komma',
    'ich', 'habe', 'hab', 'geworfen', 'getroffen',
    'eine', 'einen', 'mal', 'punkte', 'punkt',
  };

  // Natürliche Phrasen → Score direkt
  static const Map<String, int> _naturalPhrases = {
    'einhundertachtzig': 180,
    'hundertachtzig': 180,
    'maximum': 180,
    'maximal': 180,
    'top score': 180,
    'perfect': 180,
    'dreißig': 30,
    'vierzig': 40,
    'fünfzig': 50,
    'sechzig': 60,
    'siebzig': 70,
    'achtzig': 80,
    'neunzig': 90,
    'hundert': 100,
    'einhundert': 100,
    'einundzwanzig': 21,
    'zweiundzwanzig': 22,
    'dreiundzwanzig': 23,
    'vierundzwanzig': 24,
    'fünfundzwanzig': 25,
    'sechsundzwanzig': 26,
    'siebenundzwanzig': 27,
    'achtundzwanzig': 28,
    'neunundzwanzig': 29,
    'einunddreißig': 31,
    'zweiunddreißig': 32,
    'dreiunddreißig': 33,
    'vierunddreißig': 34,
    'fünfunddreißig': 35,
    'sechsunddreißig': 36,
    'siebenunddreißig': 37,
    'achtunddreißig': 38,
    'neununddreißig': 39,
  };

  // =========================================================
  // HAUPTFUNKTION
  // =========================================================

  static ParsedThrow parse(String input) {
    var text = input.toLowerCase().trim();

    // Natürliche Sprach-Präfixe entfernen
    text = _removeNaturalPrefixes(text);

    // T/D Notation parsen (z.B. "T20 D16 Bull")
    final notationResult = _parseNotation(text);
    if (notationResult != null) return notationResult;

    // Direkte Gesamtzahl
    final direct = _parseDirectScore(text);
    if (direct != null && direct >= 0 && direct <= 180) {
      return ParsedThrow(throws: [direct], isValid: true);
    }

    // Mehrere Würfe parsen
    final throws = _parseThrows(text);
    if (throws.isEmpty) {
      return ParsedThrow(throws: [], isValid: false,
          error: 'Keine Würfe erkannt in: "$input"');
    }

    for (final t in throws) {
      if (t < 0 || t > 60) {
        return ParsedThrow(throws: [], isValid: false,
            error: 'Ungültiger Wert: $t');
      }
    }

    if (throws.length > 3) {
      return ParsedThrow(throws: [], isValid: false,
          error: 'Zu viele Würfe: ${throws.length}');
    }

    return ParsedThrow(throws: throws, isValid: true);
  }

  /// Entfernt natürliche Einleitungen wie "Ich habe ... geworfen"
  static String _removeNaturalPrefixes(String text) {
    final prefixes = [
      r'^ich habe?\s+',
      r'^ich hab\s+',
      r'^das war\s+',
      r'^es waren?\s+',
      r'^meine punkte\s+',
      r'^punkte\s*:\s*',
      r'^score\s*:\s*',
      r'^eingabe\s*:\s*',
    ];
    final suffixes = [
      r'\s+geworfen$',
      r'\s+getroffen$',
      r'\s+punkte$',
      r'\s+punkt$',
    ];

    var result = text;
    for (final p in prefixes) {
      result = result.replaceAll(RegExp(p), '');
    }
    for (final s in suffixes) {
      result = result.replaceAll(RegExp(s), '');
    }
    return result.trim();
  }

  /// T20, D16, S5 Notation parsen
  static ParsedThrow? _parseNotation(String text) {
    // Normalisieren: t20 d16 bull
    final normalized = text
        .replaceAll(',', ' ')
        .replaceAll('/', ' ')
        .trim();

    final pattern = RegExp(r'([tds])(\d{1,2})|bull(seye)?', caseSensitive: false);
    final matches = pattern.allMatches(normalized).toList();

    if (matches.isEmpty) return null;

    // Prüfen ob wirklich Notation-Format (mindestens 1 Match mit T/D/S)
    final hasNotation = matches.any((m) => m.group(1) != null);
    if (!hasNotation && !normalized.contains('bull')) return null;

    final throws = <int>[];
    for (final m in matches) {
      if (m.group(0)!.toLowerCase().startsWith('bull')) {
        final isBullseye = m.group(0)!.toLowerCase() == 'bullseye';
        throws.add(isBullseye ? 50 : 25);
      } else {
        final prefix = m.group(1)!.toLowerCase();
        final num = int.tryParse(m.group(2) ?? '0') ?? 0;
        final mult = prefix == 't' ? 3 : prefix == 'd' ? 2 : 1;
        throws.add(num * mult);
      }
      if (throws.length >= 3) break;
    }

    if (throws.isEmpty) return null;
    for (final t in throws) {
      if (t < 0 || t > 60) return null;
    }

    return ParsedThrow(throws: throws, isValid: true);
  }

  static int? _parseDirectScore(String text) {
    if (_naturalPhrases.containsKey(text)) return _naturalPhrases[text];
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

      // Multiplikator?
      int multiplier = 1;
      bool foundMult = false;

      if (_multipliers.containsKey(token)) {
        multiplier = _multipliers[token]!;
        foundMult = true;
        i++;
      } else if (i + 1 < tokens.length) {
        final twoToken = '$token ${tokens[i + 1]}';
        if (_multipliers.containsKey(twoToken)) {
          multiplier = _multipliers[twoToken]!;
          foundMult = true;
          i += 2;
        }
      }

      if (i >= tokens.length) break;

      // Zahl oder Zahlwort
      final currentToken = tokens[i];

      // Bull-Sonderfall
      if (currentToken == 'bull' || currentToken == 'bulls') {
        results.add(25 * multiplier > 60 ? 50 : 25);
        i++;
        continue;
      }
      if (currentToken == 'bullseye') {
        results.add(50);
        i++;
        continue;
      }

      // Zahlwort
      if (_numberWords.containsKey(currentToken)) {
        final val = _numberWords[currentToken]! * multiplier;
        if (val >= 0 && val <= 60) results.add(val);
        i++;
      } else if (_naturalPhrases.containsKey(currentToken)) {
        final val = _naturalPhrases[currentToken]!;
        if (val >= 0 && val <= 60) results.add(val);
        i++;
      } else if (foundMult) {
        i++;
      } else {
        i++;
      }
    }

    return results;
  }

  // =========================================================
  // INTENT ERKENNUNG
  // =========================================================

  static InputIntent detectIntent(String input) {
    final lower = input.toLowerCase().trim();

    // Rückgängig
    if (_matchesAny(lower, ['rückgängig', 'zurück', 'undo', 'cancel',
        'das war falsch', 'fehler', 'nochmal eingeben'])) {
      return InputIntent.undo;
    }

    // Score abfragen
    if (_matchesAny(lower, ['wie viel', 'wieviel', 'aktuell', 'stand',
        'punkte noch', 'wie hoch', 'was ist der', 'zeig den',
        'was haben wir', 'ergebnis'])) {
      return InputIntent.queryScore;
    }

    // Checkout abfragen
    if (_matchesAny(lower, ['was muss', 'was soll', 'checkout',
        'wie kann ich', 'welches double', 'welches triple',
        'wie finish', 'finish möglichkeit', 'auswerfen',
        'auschecken', 'wie gewinne'])) {
      return InputIntent.queryCheckout;
    }

    // Spiel beenden
    if (_matchesAny(lower, ['spiel beenden', 'abbrechen', 'aufhören',
        'game over', 'beenden', 'neues spiel starten'])) {
      return InputIntent.endGame;
    }

    // Nächster Spieler
    if (_matchesAny(lower, ['fertig', 'weiter', 'nächster', 'next',
        'dran', 'jetzt du', 'du bist dran'])) {
      return InputIntent.nextPlayer;
    }

    // Wiederholen
    if (_matchesAny(lower, ['nochmal', 'wiederholen', 'was hast du gesagt',
        'bitte nochmal', 'wie bitte', 'hä', 'pardon'])) {
      return InputIntent.repeat;
    }

    // Score-Eingabe versuchen
    final parsed = parse(input);
    if (parsed.isValid && parsed.throws.isNotEmpty) {
      return InputIntent.score;
    }

    // Alles andere → freie Frage
    return InputIntent.question;
  }

  static bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }
}

enum InputIntent {
  score, undo, queryScore, queryCheckout,
  nextPlayer, endGame, repeat, question,
}
