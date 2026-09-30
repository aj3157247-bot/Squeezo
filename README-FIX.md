# Squeezo native media compression fix

This patch fixes Android compression failures by using native Android processing for both videos and images, while keeping a browser fallback for web builds.

## What changed

- Android video picker/compression uses the native Media3/MediaCodec pipeline.
- Android image picker/compression uses Android `BitmapFactory`/`Bitmap.compress`, so images do not depend on Android WebView `createImageBitmap()` decoding.
- JPG, PNG, WebP and other Android-decodable image sources can be read through `ContentResolver`.
- Compressed images and videos are saved locally under `Downloads/Squeezo` on Android 10+.
- Browser image compression now uses an `Image` + object URL fallback instead of relying only on `createImageBitmap`.
- The bundled `www/app.js` and root `app.js` are kept synchronized.

No upload/server is required for compression.
