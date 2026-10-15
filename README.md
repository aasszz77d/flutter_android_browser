# Flutter Android Browser

A simple, clean multi-tab web browser for Android built with Flutter and the official `webview_flutter` package.

## Features

- Multi-tab browsing
- Address bar with URL / search support
- Back / Forward / Reload / Home controls
- Loading progress indicator
- Desktop mode toggle
- Incognito-friendly (no persistent history by default)
- Material 3 UI

## Requirements

- Flutter 3.22+
- Android minSdk 24

## Getting Started

```bash
git clone https://github.com/aasszz77d/flutter_android_browser.git
cd flutter_android_browser
flutter pub get
flutter run
```

## Build Release APK

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

## GitHub Actions

Pushing to `main` (or manual workflow dispatch) will automatically build a release APK and upload it as an artifact.

## Tech Stack

- Flutter
- webview_flutter (official)
- Material 3
