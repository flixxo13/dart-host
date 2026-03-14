import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommentarySettings extends ChangeNotifier {
  bool _celebrateHighScores = true;
  bool _announceCheckouts = true;
  bool _commentMomentum = true;
  bool _giveTips = false;
  bool _bustReaction = true;
  bool _winnerCelebration = true;

  bool get celebrateHighScores => _celebrateHighScores;
  bool get announceCheckouts => _announceCheckouts;
  bool get commentMomentum => _commentMomentum;
  bool get giveTips => _giveTips;
  bool get bustReaction => _bustReaction;
  bool get winnerCelebration => _winnerCelebration;

  set celebrateHighScores(bool v) { _celebrateHighScores = v; _save(); notifyListeners(); }
  set announceCheckouts(bool v)   { _announceCheckouts = v;   _save(); notifyListeners(); }
  set commentMomentum(bool v)     { _commentMomentum = v;     _save(); notifyListeners(); }
  set giveTips(bool v)            { _giveTips = v;            _save(); notifyListeners(); }
  set bustReaction(bool v)        { _bustReaction = v;        _save(); notifyListeners(); }
  set winnerCelebration(bool v)   { _winnerCelebration = v;   _save(); notifyListeners(); }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _celebrateHighScores = prefs.getBool('celebrate_high') ?? true;
    _announceCheckouts   = prefs.getBool('announce_checkout') ?? true;
    _commentMomentum     = prefs.getBool('momentum') ?? true;
    _giveTips            = prefs.getBool('tips') ?? false;
    _bustReaction        = prefs.getBool('bust') ?? true;
    _winnerCelebration   = prefs.getBool('winner') ?? true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('celebrate_high', _celebrateHighScores);
    await prefs.setBool('announce_checkout', _announceCheckouts);
    await prefs.setBool('momentum', _commentMomentum);
    await prefs.setBool('tips', _giveTips);
    await prefs.setBool('bust', _bustReaction);
    await prefs.setBool('winner', _winnerCelebration);
  }
}