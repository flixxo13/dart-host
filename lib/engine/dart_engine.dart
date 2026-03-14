import 'checkout_table.dart';

class DartPlayer {
  final String name;
  int score;
  int legsWon;
  List<int> scoreHistory;
  List<List<int>> throwHistory;

  DartPlayer({required this.name, required int startScore})
      : score = startScore,
        legsWon = 0,
        scoreHistory = [],
        throwHistory = [];

  double get average {
    if (scoreHistory.isEmpty) return 0.0;
    return scoreHistory.fold(0, (a, b) => a + b) / scoreHistory.length;
  }

  int get highestRound {
    if (scoreHistory.isEmpty) return 0;
    return scoreHistory.reduce((a, b) => a > b ? a : b);
  }
}

enum GameStatus { setup, playing, bust, won, finished }
enum GameMode { mode301, mode501, mode701 }

class ThrowResult {
  final int points;
  final bool isBust;
  final bool isWin;
  final bool isCheckoutOpportunity;
  final String? checkoutSuggestion;

  ThrowResult({
    required this.points,
    required this.isBust,
    required this.isWin,
    required this.isCheckoutOpportunity,
    this.checkoutSuggestion,
  });
}

class DartEngine {
  late List<DartPlayer> players;
  late int startScore;
  late GameMode gameMode;

  int currentPlayerIndex = 0;
  int currentRound = 1;
  GameStatus status = GameStatus.setup;

  void setupGame({required List<String> playerNames, required GameMode mode}) {
    gameMode = mode;
    startScore = _getStartScore(mode);
    players = playerNames
        .map((name) => DartPlayer(name: name, startScore: startScore))
        .toList();
    currentPlayerIndex = 0;
    currentRound = 1;
    status = GameStatus.playing;
  }

  int _getStartScore(GameMode mode) {
    switch (mode) {
      case GameMode.mode301: return 301;
      case GameMode.mode501: return 501;
      case GameMode.mode701: return 701;
    }
  }

  DartPlayer get currentPlayer => players[currentPlayerIndex];

  ThrowResult processRound(List<int> throws) {
    final total = throws.fold(0, (a, b) => a + b);
    final player = currentPlayer;
    final newScore = player.score - total;

    if (newScore < 0 || newScore == 1) {
      status = GameStatus.bust;
      return ThrowResult(
          points: total, isBust: true, isWin: false,
          isCheckoutOpportunity: false);
    }

    if (newScore == 0) {
      player.score = 0;
      player.scoreHistory.add(total);
      player.throwHistory.add(throws);
      player.legsWon++;
      status = GameStatus.won;
      return ThrowResult(
          points: total, isBust: false, isWin: true,
          isCheckoutOpportunity: false);
    }

    player.score = newScore;
    player.scoreHistory.add(total);
    player.throwHistory.add(throws);

    final checkout = CheckoutTable.getCheckout(newScore);
    final isCheckoutOpp = newScore <= 170 && checkout != null;
    status = GameStatus.playing;

    return ThrowResult(
        points: total, isBust: false, isWin: false,
        isCheckoutOpportunity: isCheckoutOpp,
        checkoutSuggestion: checkout);
  }

  bool undoLastRound() {
    final player = currentPlayer;
    if (player.scoreHistory.isEmpty) {
      if (currentPlayerIndex > 0) {
        currentPlayerIndex--;
      } else {
        return false;
      }
    }
    final prevPlayer = currentPlayer;
    if (prevPlayer.scoreHistory.isEmpty) return false;
    final lastScore = prevPlayer.scoreHistory.removeLast();
    prevPlayer.throwHistory.removeLast();
    prevPlayer.score += lastScore;
    status = GameStatus.playing;
    return true;
  }

  void nextPlayer() {
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    if (currentPlayerIndex == 0) currentRound++;
    status = GameStatus.playing;
  }

  String getGameContext() {
    final sb = StringBuffer();
    sb.writeln('=== SPIELSTAND ===');
    sb.writeln('Modus: $startScore');
    sb.writeln('Runde: $currentRound');
    sb.writeln('');
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      final marker = i == currentPlayerIndex ? '→ ' : '  ';
      sb.writeln('$marker${p.name}: ${p.score} übrig (Ø ${p.average.toStringAsFixed(1)}/Runde)');
    }
    sb.writeln('');
    sb.writeln('Aktuell dran: ${currentPlayer.name}');
    final checkout = CheckoutTable.getCheckout(currentPlayer.score);
    if (checkout != null) sb.writeln('Checkout möglich: $checkout');
    return sb.toString();
  }

  DartPlayer get leadingPlayer =>
      players.reduce((a, b) => a.score < b.score ? a : b);

  int get scoreDifference {
    if (players.length < 2) return 0;
    final sorted = [...players]..sort((a, b) => a.score.compareTo(b.score));
    return sorted[1].score - sorted[0].score;
  }
}