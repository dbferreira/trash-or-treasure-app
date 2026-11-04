# Trash or Treasure

A Flutter app that identifies second-hand items from photos and estimates their resale value. The heavy lifting is done by an AI agent workflow built with [Mastra](https://mastra.ai), which lives in a companion backend repo: [trash-or-treasure-backend](https://github.com/dbferreira/trash-or-treasure-backend).

## Features

- **AI-powered identification:** Snap or pick one or more photos (optionally with a short description) and the agent identifies the item's brand, model and condition.
- **Resale value estimation:** Get a low–high price range with a confidence score.
- **Comparable listings:** Links to the market listings the estimate was based on (e.g. Kijiji, Facebook Marketplace).
- **Live Scan (Android):** On-device object detection with Google ML Kit draws boxes around items in the camera feed. Tap a box to capture it and get a price.
- **Pinned results:** Save results locally with their photos, a timestamp and a nearby place name (via reverse geocoding), so you can remember where you saw an item.
- **Share:** Send a result and its photos to other apps.
- **Cancel and timeout handling:** Long-running agent requests can be canceled and time out cleanly.

## How it works

```
Flutter app ──(base64 images + description)──▶ Mastra backend: pricingWorkflow
                                                  └─ identify-and-price step (Gemini vision agent + market listing search)
            ◀──(item, price range, confidence, sources)──
```

The app calls `POST /api/workflows/pricingWorkflow/start-async` and renders the structured result returned by the workflow's `identify-and-price` step.

## Getting started

### Prerequisites

- Flutter SDK (latest stable)
- The [Mastra backend](https://github.com/dbferreira/trash-or-treasure-backend) running locally (it listens on port `4111` by default)

### Configuration

The backend URL is set at build time with `--dart-define`. It defaults to `http://localhost:4111` (see `lib/config.dart`).

**Android emulator** (`10.0.2.2` is the emulator's alias for your computer):
```bash
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:4111
```

**Physical device on the same Wi-Fi network** (use your computer's LAN IP):
```bash
flutter run --dart-define=BACKEND_URL=http://<your-computer-ip>:4111
```

**Production build:**
```bash
flutter build apk --release --dart-define=BACKEND_URL=https://api.yourdomain.com
```

> Cleartext HTTP is enabled in the Android manifest so the app can talk to a local development backend. Use HTTPS for any deployed backend.

## Project structure

- `lib/api_service.dart`: API client for the Mastra workflow.
- `lib/app_state.dart`: Centralized state management with Provider (chat, requests, pinned results).
- `lib/config.dart`: Environment configuration.
- `lib/models.dart`: Data models for messages and workflow results.
- `lib/screens/`: Live Scan and Pinned Results tabs.
- `lib/widgets/`: Reusable UI components (message bubbles, result cards, image previews).

## Development

```bash
flutter analyze
flutter test
```

## Testing on a physical Android device

1. **Enable Developer Options:** Go to **Settings > About Phone** and tap **Build Number** 7 times.
2. **Enable USB Debugging:** Go to **Settings > System > Developer Options** and turn on **USB Debugging**.
3. **Connect:** Plug your phone into your computer with USB and allow debugging if prompted.
4. **Run:** Make sure your phone and the computer running the backend are on the same Wi-Fi network, then run the physical-device command above.

To install manually instead, build with `flutter build apk --debug` and copy `build/app/outputs/flutter-apk/app-debug.apk` to your phone.

## License

Released under the [MIT License](LICENSE).
