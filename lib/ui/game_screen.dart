// lib/ui/game_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_controller.dart';
import '../state/game_state_manager.dart';
import 'settings_screen.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, controller, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, controller),
                Expanded(child: _buildMainContent(controller)),
                _buildScoreBoard(controller),
                _buildVoiceButton(controller),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header ──
  Widget _buildHeader(BuildContext context, AppController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          const Text(
            'Dart Host',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          _PhaseChip(phase: controller.gameState.phase),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF8B949E), size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hauptinhalt: KI-Sprachblase + Status ──
  Widget _buildMainContent(AppController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // KI Host Sprachblase
          if (controller.gameState.lastSpokenText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2333),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF30D158), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🎙️ Dart Host',
                    style: TextStyle(color: Color(0xFF30D158), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.gameState.lastSpokenText,
                    style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.4),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Status Message
          Text(
            controller.gameState.statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 14),
          ),

          const SizedBox(height: 16),

          // Partial Result — was der Nutzer gerade spricht
          if (controller.voice.partialResult.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2333),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${controller.voice.partialResult}"',
                style: const TextStyle(
                  color: Color(0xFF58A6FF),
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Scoreboard ──
  Widget _buildScoreBoard(AppController controller) {
    final phase = controller.gameState.phase;
    if (phase != AppPhase.playing &&
        phase != AppPhase.gameOver &&
        phase != AppPhase.roundResult) {
      return const SizedBox.shrink();
    }

    final players = controller.gameState.engine.players;
    final currentIndex = controller.gameState.engine.currentPlayerIndex;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2333),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(players.length, (i) {
          final p = players[i];
          final isActive = i == currentIndex;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF30D158).withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isActive
                    ? Border.all(color: const Color(0xFF30D158), width: 1.5)
                    : Border.all(color: Colors.transparent),
              ),
              child: Column(
                children: [
                  if (isActive)
                    const Text('▼', style: TextStyle(color: Color(0xFF30D158), fontSize: 10)),
                  Text(
                    p.name,
                    style: TextStyle(
                      color: isActive ? const Color(0xFF30D158) : const Color(0xFF8B949E),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.score}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isActive ? 34 : 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Ø ${p.average.toStringAsFixed(0)}',
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Mikrofon Button ──
  Widget _buildVoiceButton(AppController controller) {
    final voice = controller.voice;
    final isListening = voice.isListening;
    final isSpeaking = voice.isSpeaking;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        children: [
          Text(
            isListening
                ? 'Ich höre zu...'
                : isSpeaking
                    ? 'Dart Host spricht...'
                    : 'Tippen zum Sprechen',
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: isSpeaking ? null : controller.toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isListening
                    ? const Color(0xFFFF3B30)
                    : isSpeaking
                        ? const Color(0xFF30D158)
                        : const Color(0xFF1C2333),
                border: Border.all(
                  color: isListening
                      ? const Color(0xFFFF3B30)
                      : isSpeaking
                          ? const Color(0xFF30D158)
                          : const Color(0xFF30363D),
                  width: 2,
                ),
                boxShadow: isListening
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF3B30).withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        )
                      ]
                    : [],
              ),
              child: Icon(
                isListening
                    ? Icons.mic
                    : isSpeaking
                        ? Icons.volume_up
                        : Icons.mic_none,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Phase Chip ──
class _PhaseChip extends StatelessWidget {
  final AppPhase phase;
  const _PhaseChip({required this.phase});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      AppPhase.idle          => ('Bereit',    const Color(0xFF8B949E)),
      AppPhase.addingPlayers => ('Setup',     const Color(0xFF58A6FF)),
      AppPhase.choosingMode  => ('Modus',     const Color(0xFFD2A679)),
      AppPhase.playing       => ('Läuft',     const Color(0xFF30D158)),
      AppPhase.roundResult   => ('Ergebnis',  const Color(0xFF30D158)),
      AppPhase.gameOver      => ('Ende',      const Color(0xFFFF6B6B)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
