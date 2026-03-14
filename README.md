# 🎯 Dart Host

KI-gesteuerter Dart Moderator für Android — vollständig hands-free per Sprache.

## Features Sprint 1
- ✅ Voice-First: Komplette Spielsteuerung per Sprache
- ✅ Wake Words: "Hey Darts", "Spieler: [Name]", "Spiel 301"
- ✅ Dart Engine: 301 / 501 / 701 mit Bust-Erkennung
- ✅ Checkout-Tabelle: Empfehlungen für alle Scores bis 170
- ✅ KI Moderator: Gemini-powered mit 3 Stimmungsprofilen
- ✅ Score Parser: Deutsche Zahlwörter ("dreimal zwanzig" → 60)
- ✅ TTS Ausgabe: Natürliche deutsche Stimme

---

## 🚀 Setup (einmalig)

### 1. Repository auf GitHub erstellen
- Neues Repo: `dart-host`
- Alle Dateien hochladen (Ordnerstruktur beachten!)

### 2. Gemini API Key eintragen
- Kostenloser Key: https://aistudio.google.com/app/apikey
- Datei öffnen: `lib/ai/host_ai.dart`
- Zeile ändern: `static const String _apiKey = 'DEIN_GEMINI_API_KEY';`

### 3. GitHub Actions aktivieren
- Auf GitHub: Tab "Actions" → "I understand my workflows, go ahead and enable them"
- Bei jedem Push auf `main` wird automatisch eine APK gebaut

### 4. APK herunterladen & installieren
- GitHub → Actions → letzter Build → "dart-host-debug-X" → Download
- APK auf Android installieren (Unbekannte Quellen erlauben)

---

## 📁 Projektstruktur

```
dart_host/
├── .github/workflows/
│   └── build.yml              ← GitHub Actions APK Build
├── android/app/src/main/
│   └── AndroidManifest.xml    ← Mikrofon + Internet Permissions
├── lib/
│   ├── main.dart              ← App Einstieg
│   ├── app_controller.dart    ← Zentraler Controller
│   ├── engine/
│   │   ├── dart_engine.dart   ← Spiellogik (301/501, Bust, Win)
│   │   └── checkout_table.dart← Alle Checkout-Empfehlungen
│   ├── voice/
│   │   ├── voice_controller.dart ← STT + TTS
│   │   └── score_parser.dart  ← Zahlenwörter → Punkte
│   ├── ai/
│   │   └── host_ai.dart       ← Gemini Moderator
│   ├── state/
│   │   └── game_state_manager.dart ← State Machine
│   └── ui/
│       └── game_screen.dart   ← Minimale UI
└── pubspec.yaml               ← Dependencies
```

---

## 🎙️ Sprachbefehle

### Setup
| Sagen | Aktion |
|---|---|
| "Hey Darts" | App starten |
| "Spieler: Felix" | Spieler hinzufügen |
| "Reihenfolge fertig" | Setup abschließen |
| "Spiel 301" | Spielmodus wählen |

### Während des Spiels
| Sagen | Aktion |
|---|---|
| "Zwanzig, dreizehn, fünf" | 3 Würfe eingeben |
| "Dreimal zwanzig, neunzehn, drei" | Mit Multiplikatoren |
| "Fertig" / "Weiter" | Nächster Spieler |
| "Rückgängig" | Letzten Zug widerrufen |
| "Was ist der Stand?" | Score vorlesen |
| "Was muss ich werfen?" | Checkout-Empfehlung |
| "Spiel beenden" | Zurück zum Start |

### Freie Fragen (KI antwortet)
- "Wie läuft Marco so?"
- "Welches Double soll ich anvisieren?"
- "Wer führt gerade?"

---

## 🔧 Dependencies

```yaml
speech_to_text: ^6.6.2      # Offline STT
flutter_tts: ^4.0.2         # Offline TTS  
google_generative_ai: ^0.4.6 # Gemini API
permission_handler: ^11.3.1  # Mikrofon-Permission
provider: ^6.1.2             # State Management
shared_preferences: ^2.3.2   # Einstellungen
```

---

## 📋 Sprint Roadmap

- **Sprint 1** ✅ Fundament: Engine, Voice, State Machine, Gemini Host
- **Sprint 2** → Settings: Stimmung wählen, Kommentar-Toggles, Spieler-Farben
- **Sprint 3** → Statistiken: Average, Highscore, Spielverlauf
- **Sprint 4** → Wake Word: Offline Trigger (Porcupine), dauerhaftes Zuhören
- **Sprint 5** → Multiplayer: Bluetooth Sync zwischen 2 Smartphones
