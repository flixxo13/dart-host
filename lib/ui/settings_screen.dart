// lib/ui/settings_screen.dart
// Einstellungen: Host-Stimmung & Kommentar-Toggles

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_controller.dart';
import '../state/game_state_manager.dart';
import '../state/commentary_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.white,
        title: const Text('Einstellungen'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFF30363D), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: '🎙️ Host Stimmung'),
          const SizedBox(height: 12),
          Consumer<AppController>(
            builder: (context, controller, _) => _MoodSelector(
              currentMood: controller.gameState.mood,
              onMoodSelected: (mood) => controller.gameState.setMood(mood),
            ),
          ),
          Consumer<AppController>(
            builder: (context, controller, _) {
              if (controller.gameState.mood != HostMood.custom) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _CustomMoodInput(
                  initialValue: controller.gameState.customMoodPrompt,
                  onChanged: (val) => controller.gameState.customMoodPrompt = val,
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const _SectionHeader(title: '💬 Auto-Kommentare'),
          const SizedBox(height: 4),
          const Text(
            'Was soll der Host von sich aus sagen?',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Consumer<CommentarySettings>(
            builder: (context, settings, _) => Column(
              children: [
                _CommentaryToggle(icon: '🔥', label: 'Hohe Scores feiern',
                  subtitle: 'z.B. "180!" oder "Über 100 Punkte!"',
                  value: settings.celebrateHighScores,
                  onChanged: (v) => settings.celebrateHighScores = v),
                _CommentaryToggle(icon: '🎯', label: 'Checkout ansagen',
                  subtitle: 'Wenn ein Finish möglich ist',
                  value: settings.announceCheckouts,
                  onChanged: (v) => settings.announceCheckouts = v),
                _CommentaryToggle(icon: '⚡', label: 'Spannung kommentieren',
                  subtitle: 'Wenn ein Spieler aufholt oder führt',
                  value: settings.commentMomentum,
                  onChanged: (v) => settings.commentMomentum = v),
                _CommentaryToggle(icon: '💡', label: 'Tipps geben',
                  subtitle: 'Strategie-Hinweise nach schwachen Runden',
                  value: settings.giveTips,
                  onChanged: (v) => settings.giveTips = v),
                _CommentaryToggle(icon: '💥', label: 'Bust-Reaktion',
                  subtitle: 'Kommentar wenn überworfen',
                  value: settings.bustReaction,
                  onChanged: (v) => settings.bustReaction = v),
                _CommentaryToggle(icon: '🏆', label: 'Sieger feiern',
                  subtitle: 'Große Ansage wenn jemand gewinnt',
                  value: settings.winnerCelebration,
                  onChanged: (v) => settings.winnerCelebration = v),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const _SectionHeader(title: '🎤 Sprachbefehle'),
          const SizedBox(height: 12),
          const _CommandsCheatSheet(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2333),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF58A6FF), size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Einstellungen werden automatisch gespeichert.',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _MoodSelector extends StatelessWidget {
  final HostMood currentMood;
  final Function(HostMood) onMoodSelected;
  const _MoodSelector({required this.currentMood, required this.onMoodSelected});

  @override
  Widget build(BuildContext context) {
    final moods = [
      (HostMood.professional, '🎩', 'Profi', 'Sachlich & präzise wie ein Turnier'),
      (HostMood.hype, '🔥', 'Hype', 'Energetisch & wild — Pub-Abend'),
      (HostMood.chill, '😎', 'Chill', 'Entspannt & locker'),
      (HostMood.custom, '✏️', 'Custom', 'Eigene Persönlichkeit definieren'),
    ];
    return Column(
      children: moods.map((mood) {
        final (mode, icon, label, desc) = mood;
        final isSelected = currentMood == mode;
        return GestureDetector(
          onTap: () => onMoodSelected(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF30D158).withOpacity(0.12) : const Color(0xFF1C2333),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF30D158) : const Color(0xFF30363D),
                width: isSelected ? 1.5 : 1),
            ),
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(
                  color: isSelected ? const Color(0xFF30D158) : Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15)),
                Text(desc, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
              ])),
              if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF30D158), size: 20),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _CustomMoodInput extends StatefulWidget {
  final String initialValue;
  final Function(String) onChanged;
  const _CustomMoodInput({required this.initialValue, required this.onChanged});

  @override
  State<_CustomMoodInput> createState() => _CustomMoodInputState();
}

class _CustomMoodInputState extends State<_CustomMoodInput> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2333), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Host-Persönlichkeit beschreiben:',
          style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl, onChanged: widget.onChanged, maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'z.B. "Du bist ein bayerischer Wirt der Darts liebt..."',
            hintStyle: TextStyle(color: Color(0xFF30363D), fontSize: 13),
            border: InputBorder.none)),
      ]),
    );
  }
}

class _CommentaryToggle extends StatelessWidget {
  final String icon, label, subtitle;
  final bool value;
  final Function(bool) onChanged;
  const _CommentaryToggle({
    required this.icon, required this.label, required this.subtitle,
    required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF1C2333), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
          Text(subtitle, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
        ])),
        Switch(value: value, onChanged: onChanged,
          activeColor: const Color(0xFF30D158), inactiveTrackColor: const Color(0xFF30363D)),
      ]),
    );
  }
}

class _CommandsCheatSheet extends StatelessWidget {
  const _CommandsCheatSheet();

  @override
  Widget build(BuildContext context) {
    final sections = [
      ('Setup', [('Hey Darts', 'App aktivieren'), ('Spieler: [Name]', 'Spieler hinzufügen'),
        ('Reihenfolge fertig', 'Setup abschließen'), ('Spiel 301 / 501', 'Modus wählen')]),
      ('Im Spiel', [('Zwanzig, neunzehn, drei', '3 einzelne Würfe'),
        ('Dreimal zwanzig, drei, fünf', 'Triple + 2 Singles'),
        ('Fertig / Weiter', 'Nächster Spieler'), ('Rückgängig', 'Letzten Zug widerrufen')]),
      ('Fragen', [('Was ist der Stand?', 'Score vorlesen'), ('Was muss ich werfen?', 'Checkout-Tipp'),
        ('Wie läuft Marco?', 'Spieler-Statistik'), ('Spiel beenden', 'Zurück zum Start')]),
    ];

    return Column(children: sections.map((section) {
      final (title, cmds) = section;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Text(title, style: const TextStyle(
            color: Color(0xFF58A6FF), fontSize: 12, fontWeight: FontWeight.bold))),
        ...cmds.map((cmd) {
          final (say, desc) = cmd;
          return Padding(padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF1C2333),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF30363D))),
                child: Text('"$say"', style: const TextStyle(
                  color: Color(0xFFD2A679), fontFamily: 'monospace', fontSize: 11))),
              const SizedBox(width: 8),
              Expanded(child: Text(desc,
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12))),
            ]));
        }),
        const SizedBox(height: 8),
      ]);
    }).toList());
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(
      color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold));
  }
}
