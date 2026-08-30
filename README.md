# Squeezo — Android / Capacitor

Squeezo is an offline-first web app packaged as an Android application with Capacitor.

## GitHub Actions

Push this project to the `main` branch, then open **Actions → Build Squeezo Android APK → Run workflow**.
The generated APK is available under the workflow's **Artifacts** section as `Squeezo-debug-apk`.

## Structure

- `www/` — the complete web application bundled into the APK.
- `capacitor.config.ts` — Capacitor app configuration.
- `package.json` — Node/Capacitor dependencies.
- `.github/workflows/android.yml` — automatic Android APK build.

The Android platform folder is generated during CI with `npx cap add android`, so it does not need to be committed.
