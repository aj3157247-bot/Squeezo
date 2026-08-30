# Squeezo native video compression fix

This patch replaces the Android WebView `MediaRecorder` video path with a native Android video pipeline based on AndroidX Media3 Transformer/MediaCodec.

## Replace/add these files

- `www/app.js` — uses the native engine on Android and keeps browser fallback.
- `.github/workflows/android.yml` — builds Android and applies the native engine automatically.
- `native/apply-android.sh` — injects the native Android code and Media3 dependencies after `npx cap add android`.
- `native/android/com/squeezo/app/MainActivity.java`
- `native/android/com/squeezo/app/SqueezoVideoCompressorPlugin.java`
- `native/android/res/xml/file_paths.xml`

The native picker avoids loading large videos into JavaScript memory. Compression runs on-device using Media3/MediaCodec and the MP4 result is saved to `Downloads/Squeezo` on Android 10+.
