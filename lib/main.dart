import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_controller.dart';
import 'state/commentary_settings.dart';
import 'ui/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const DartHostApp());
}

class DartHostApp extends StatelessWidget {
  const DartHostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppController(),
      child: Consumer<AppController>(
        builder: (context, controller, _) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider<CommentarySettings>.value(
                value: controller.commentary,
              ),
            ],
            child: MaterialApp(
              title: 'Dart Host',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF30D158),
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
                scaffoldBackgroundColor: const Color(0xFF0D1117),
              ),
              home: const _InitScreen(),
            ),
          );
        },
      ),
    );
  }
}

class _InitScreen extends StatefulWidget {
  const _InitScreen();
  @override
  State<_InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<_InitScreen> {
  bool _initializing = true;
  String _initMessage = 'Starte Dart Host...';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _initMessage = 'Mikrofon wird vorbereitet...');
    final controller = context.read<AppController>();
    await controller.initialize();
    if (mounted) setState(() => _initializing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎯', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              const Text('Dart Host',
                  style: TextStyle(color: Colors.white, fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_initMessage,
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 14)),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                  color: Color(0xFF30D158), strokeWidth: 2),
            ],
          ),
        ),
      );
    }
    return const GameScreen();
  }
}