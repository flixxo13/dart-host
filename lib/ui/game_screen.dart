// lib/ui/game_screen.dart
import 'dart:math';
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
                _MicButton(controller: controller),
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
          const Text('Dart Host',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          _PhaseChip(phase: controller.gameState.phase),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: Color(0xFF8B949E), size: 22),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
    );
  }

  // ── Hauptinhalt ──
  Widget _buildMainContent(AppController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // KI Host Sprachblase
          if (controller.gameState.lastSpokenText.isNotEmpty)
            _HostBubble(text: controller.gameState.lastSpokenText),

          const SizedBox(height: 20),

          // Status Message
          Text(
            controller.gameState.statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 14),
          ),

          const SizedBox(height: 16),

          // Partial Result
          if (controller.voice.partialResult.isNotEmpty)
            _PartialResultBox(text: controller.voice.partialResult),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
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
                    const Text('▼',
                        style: TextStyle(
                            color: Color(0xFF30D158), fontSize: 10)),
                  Text(p.name,
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF30D158)
                            : const Color(0xFF8B949E),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${p.score}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isActive ? 34 : 26,
                        fontWeight: FontWeight.bold,
                      )),
                  Text('Ø ${p.average.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Color(0xFF8B949E), fontSize: 11)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Host Sprachblase ──
class _HostBubble extends StatelessWidget {
  final String text;
  const _HostBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text('🎙️ Dart Host',
              style: TextStyle(color: Color(0xFF30D158), fontSize: 12)),
          const SizedBox(height: 8),
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, height: 1.4)),
        ],
      ),
    );
  }
}

// ── Partial Result Box ──
class _PartialResultBox extends StatelessWidget {
  final String text;
  const _PartialResultBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2333),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF58A6FF).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hearing, color: Color(0xFF58A6FF), size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '"$text"',
                style: const TextStyle(
                  color: Color(0xFF58A6FF),
                  fontStyle: FontStyle.italic,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mikrofon Button mit Puls-Animation ──
class _MicButton extends StatefulWidget {
  final AppController controller;
  const _MicButton({required this.controller});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnim;
  late Animation<double> _rippleAnim;
  late Animation<double> _rippleOpacity;

  @override
  void initState() {
    super.initState();

    // Puls-Animation (Mikrofon-Button selbst)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ripple-Animation (Welle um Mikrofon)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _rippleAnim = Tween<double>(begin: 0.8, end: 2.2).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _rippleOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller.voice,
      builder: (context, _) {
        final isListening = widget.controller.voice.isListening;
        final isSpeaking = widget.controller.voice.isSpeaking;

        final Color btnColor = isListening
            ? const Color(0xFFFF3B30)
            : isSpeaking
                ? const Color(0xFF30D158)
                : const Color(0xFF1C2333);

        final Color borderColor = isListening
            ? const Color(0xFFFF3B30)
            : isSpeaking
                ? const Color(0xFF30D158)
                : const Color(0xFF30363D);

        final IconData icon = isListening
            ? Icons.mic
            : isSpeaking
                ? Icons.volume_up
                : Icons.mic_none;

        final String label = isListening
            ? 'Ich höre zu...'
            : isSpeaking
                ? 'Dart Host spricht...'
                : 'Tippen zum Sprechen';

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF8B949E), fontSize: 12)),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: () => widget.controller.toggleListening(),
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ripple Wellen (nur beim Hören)
                      if (isListening) ...[
                        _buildRipple(borderColor, 1.0),
                        _buildRipple(borderColor, 0.6, delay: 0.5),
                      ],

                      // Pulsierender Button
                      AnimatedBuilder(
                        animation: isListening ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: isListening ? _pulseAnim.value : 1.0,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: btnColor,
                            border: Border.all(color: borderColor, width: 2),
                            boxShadow: isListening
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF3B30)
                                          .withOpacity(0.35),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    )
                                  ]
                                : isSpeaking
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF30D158)
                                              .withOpacity(0.3),
                                          blurRadius: 20,
                                          spreadRadius: 3,
                                        )
                                      ]
                                    : [],
                          ),
                          child: Icon(icon, color: Colors.white, size: 30),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRipple(Color color, double opacity, {double delay = 0.0}) {
    return AnimatedBuilder(
      animation: _rippleController,
      builder: (context, _) {
        double progress = (_rippleController.value + delay) % 1.0;
        final scale = 0.8 + progress * 1.4;
        final alpha = ((1.0 - progress) * opacity * 0.6).clamp(0.0, 1.0);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(alpha),
                width: 2,
              ),
            ),
          ),
        );
      },
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
      AppPhase.idle          => ('Bereit',   const Color(0xFF8B949E)),
      AppPhase.addingPlayers => ('Setup',    const Color(0xFF58A6FF)),
      AppPhase.choosingMode  => ('Modus',    const Color(0xFFD2A679)),
      AppPhase.playing       => ('Läuft',    const Color(0xFF30D158)),
      AppPhase.roundResult   => ('Ergebnis', const Color(0xFF30D158)),
      AppPhase.gameOver      => ('Ende',     const Color(0xFFFF6B6B)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
