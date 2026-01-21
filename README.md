# Treasure or Trash

A modern Flutter application for item identification and resale value estimation, powered by a Mastra-based AI backend.

## Features

- **AI-Powered Identification:** Take photos of items to identify brand, model, and condition.
- **Resale Value Estimation:** Get real-time price ranges based on market data.
- **Market References:** Direct links to comparable listings on platforms like Kijiji and Facebook Marketplace.
- **Modern UI:** Playful Indigo-themed interface with smooth animations and a conversational flow.

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Mastra Backend running (see `/Users/daniel/src/treasure-or-trash`)

### Configuration

The app uses `--dart-define` to manage environment-specific configurations.

#### Backend URL
The default backend URL is set to `http://192.168.86.59:4111` in `lib/config.dart`.

To override the backend URL at runtime (e.g., for local emulator or production):

**Run locally (Emulator):**
```bash
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:4111
```

**Run on Physical Device (Local Network):**
```bash
flutter run --dart-define=BACKEND_URL=http://192.168.86.59:4111
```

**Build for Production:**
```bash
flutter build apk --release --dart-define=BACKEND_URL=https://api.yourdomain.com
```

## Project Structure

- `lib/api_service.dart`: API client for the Mastra workflow.
- `lib/app_state.dart`: Centralized state management using Provider.
- `lib/config.dart`: Environment configuration.
- `lib/models.dart`: Data models for messages and workflow results.
- `lib/widgets/`: Modular UI components (Message Bubbles, Result Cards, etc.).

## Development

### Run Analysis
```bash
flutter analyze
```

### Build APK

```bash

flutter build apk --debug

```



## Testing on a Physical Android Device



### 1. Prepare your Android Device

1.  **Enable Developer Options:** Go to **Settings > About Phone** and tap **Build Number** 7 times.

2.  **Enable USB Debugging:** Go to **Settings > System > Developer Options** and toggle on **USB Debugging**.

3.  **Connect:** Plug your phone into your computer via USB and allow debugging if prompted.



### 2. Run the App

Ensure your phone and the computer running the backend are on the **same Wi-Fi network**, then run:

```bash

flutter run

```



### 3. Install via APK

If you'd rather install the app manually:

1.  Build the APK: `flutter build apk --debug`

2.  Transfer the file from `build/app/outputs/flutter-apk/app-debug.apk` to your phone and open it to install.
