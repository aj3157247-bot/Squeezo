# Squeezo — Android + Capacitor

Squeezo is a privacy-first image/video compressor designed to work offline. The web app is bundled locally inside the Android application, so the compressor UI and assets do not require a server.

## Build on GitHub

1. Upload this repository to GitHub.
2. Open **Actions**.
3. Run **Build Squeezo Android APK** (or push to `main`).
4. Open the completed workflow and download the **Squeezo-debug-apk** artifact.

The workflow installs Capacitor, creates the Android platform when it is not present, syncs the `www` app, and builds the APK.

## Build locally

```bash
npm install
npx cap add android
npx cap sync android
npx cap open android
```

Or build directly:

```bash
cd android
./gradlew assembleDebug
```

## App identity

- Name: Squeezo
- Package ID: `com.squeezo.app`
- Web directory: `www`

## Offline/privacy

All web assets are packaged under `www`. Squeezo does not need a backend for its local compression workflow. Files selected by the user are processed on the device/browser runtime.

## Important note about video formats

Browser-based video compression depends on the codecs supported by the device WebView. The app can therefore fall back to a browser-supported output format when a requested codec is unavailable. A future native FFmpeg module can be added if guaranteed MP4/H.264 output is required on every Android device.
