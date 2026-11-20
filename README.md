<div align="center">
  <img src="assets/images/zunify_logo.png" alt="Zunify Logo" width="110" />
  <h1>Zunify</h1>
  <p><strong>Standalone Aesthetic Android Music Player</strong></p>

  <p>
    <a href="https://github.com/Irfans128/zunify-apk/releases/latest">
      <img src="https://img.shields.io/badge/Version-v2.0.2-crimson?style=flat-square" alt="Version" />
    </a>
    <img src="https://img.shields.io/badge/Platform-Android%207.0%2B-3DDC84?style=flat-square&logo=android&logoColor=white" alt="Platform" />
    <img src="https://img.shields.io/badge/Flutter-3.24-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
    <a href="LICENSE">
      <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License" />
    </a>
  </p>
</div>

---

## Overview

**Zunify** is a standalone, serverless Android music player built with Flutter. Designed for speed, zero login friction, and clean visual aesthetics, it combines high-performance audio playback with synced bilingual lyrics, offline storage, and native Android DSP hardware controls.

## Key Features

- **Dual Aesthetic Themes** — Switch seamlessly between **Neo-Brutalism** and **Liquid Glass** with 90/120Hz fluid animations.
- **Standalone & Zero Login** — Stream music directly with an intelligent radio queue engine and multilingual voice search.
- **Synced Bilingual Lyrics** — Real-time timestamped lyrics with smart automatic Indonesian translation.
- **Private Offline Vault** — Download tracks, cover art, and lyrics internally for 100% offline playback without cluttering device storage.
- **Hardware DSP Equalizer** — Native Android Equalizer, Bass Boost, and Virtualizer integration with customizable presets.
- **3-Tier Audio Quality** — Choose between Data Saver (96 kbps), Normal (128 kbps), and Studio Hi-Fi (160 kbps Opus).
- **Instant FCM Notifications** — Powered by Firebase Cloud Messaging for zero-battery-drain updates and announcements.
- **In-App Auto Updater & Weekly Rapot** — Seamless self-updating directly inside the app and weekly listening summaries.

## Download

Get the latest APK directly from the [Releases](https://github.com/Irfans128/zunify-apk/releases/latest) page:

| Variant | Recommended For |
| :--- | :--- |
| **`Lite-arm64`** | Most modern Android devices (smaller size, optimized for 64-bit) |
| **`Universal`** | All Android architectures (arm64, armeabi-v7a, x86_64) |

## Build From Source

### Cloud Build (GitHub Actions)
This repository includes a pre-configured workflow at `.github/workflows/build-apk.yml` that automatically builds and publishes release APKs on every push to `main`.

### Local Build
Ensure Flutter SDK (`>= 3.24.0`) and Android SDK are configured, then run:
```bash
flutter pub get
flutter build apk --release --split-per-abi
```

## License

Distributed under the **MIT License**. See [LICENSE](LICENSE) for more information.

---

<div align="center">
  <sub>Crafted with ❤️ by <strong>Fannz</strong> (<code>com.fannz.zunify</code>)</sub>
</div>
