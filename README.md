# Squeezo — Final Offline Web App

Squeezo is a privacy-first media compressor designed for GitHub Pages / PWA.

## Included
- Image compression: WebP/JPEG, quality, max resolution, batch processing.
- Video compression: browser-native MediaRecorder/WebCodecs-style workflow using canvas + captured audio where supported.
- Presets: Balanced, Small Size, High Quality, Custom.
- Resolution, bitrate and FPS controls.
- Progress indicator.
- Save and native Share support.
- PWA service worker for offline app shell.
- 12 languages with RTL for Dari, Pashto and Arabic.
- Dark/light theme.
- Local-only processing; no upload API or server is used.

## Important video compatibility note
Video encoding is performed by the browser. Chromium-based browsers on Android/desktop are the main target. MP4 recording is only used when the browser reports support; otherwise WebM is selected. This avoids shipping a huge third-party WASM binary and keeps the app deployable as a static GitHub Pages site.

## GitHub Pages
Repository Settings → Pages → Deploy from branch → main → /(root).

The app does not require a backend or API key.
