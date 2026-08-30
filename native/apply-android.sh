#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANDROID_ROOT="$ROOT/android"
APP="$ANDROID_ROOT/app"
SRC="$SCRIPT_DIR/android"
PKG="$APP/src/main/java/com/squeezo/app"
RES_XML="$APP/src/main/res/xml"

fail() { echo "ERROR: $*" >&2; exit 1; }

[[ -d "$APP" ]] || fail "Android project not found at $APP"
[[ -f "$SRC/com/squeezo/app/SqueezoVideoCompressorPlugin.java" ]] || fail "Missing native plugin source"
[[ -f "$SRC/com/squeezo/app/MainActivity.java" ]] || fail "Missing MainActivity source"
[[ -f "$SRC/res/xml/file_paths.xml" ]] || fail "Missing file_paths.xml"
[[ -f "$ANDROID_ROOT/build.gradle" ]] || fail "android/build.gradle not found"
[[ -f "$APP/build.gradle" ]] || fail "android/app/build.gradle not found"

mkdir -p "$PKG" "$RES_XML"
cp "$SRC/com/squeezo/app/SqueezoVideoCompressorPlugin.java" "$PKG/SqueezoVideoCompressorPlugin.java"
cp "$SRC/com/squeezo/app/MainActivity.java" "$PKG/MainActivity.java"
cp "$SRC/res/xml/file_paths.xml" "$RES_XML/file_paths.xml"

# Media3 1.10.x requires compileSdk 36. Keep all Media3 modules on exactly one version.
APP_GRADLE="$APP/build.gradle"
python3 - "$APP_GRADLE" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
lines = [line for line in s.splitlines() if 'androidx.media3:' not in line]
s = '\n'.join(lines).rstrip() + '\n'
block = '''    implementation "androidx.media3:media3-transformer:1.10.1"
    implementation "androidx.media3:media3-effect:1.10.1"
    implementation "androidx.media3:media3-common:1.10.1"
    implementation "androidx.media3:media3-exoplayer:1.10.1"
    implementation "androidx.media3:media3-datasource:1.10.1"
    implementation "androidx.media3:media3-muxer:1.10.1"
'''
if 'dependencies {' not in s:
    raise SystemExit('dependencies block not found')
s = s.replace('dependencies {', 'dependencies {\n' + block, 1)
open(p, 'w', encoding='utf-8').write(s)
PY

# Capacitor 7 uses android/variables.gradle for SDK versions.
VARIABLES="$ANDROID_ROOT/variables.gradle"
if [[ -f "$VARIABLES" ]]; then
  python3 - "$VARIABLES" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'(compileSdkVersion\s*=\s*)\d+', r'\g<1>36', s)
s = re.sub(r'(targetSdkVersion\s*=\s*)\d+', r'\g<1>36', s)
s = re.sub(r'(compileSdkVersion\s+)\d+', r'\g<1>36', s)
s = re.sub(r'(targetSdkVersion\s+)\d+', r'\g<1>36', s)
open(p, 'w', encoding='utf-8').write(s)
PY
else
  # Fallback for templates that do not expose variables.gradle.
  python3 - "$APP_GRADLE" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'\bcompileSdk(?:Version)?\s*[= ]\s*\d+', 'compileSdk 36', s)
s = re.sub(r'\btargetSdk(?:Version)?\s*[= ]\s*\d+', 'targetSdk 36', s)
open(p, 'w', encoding='utf-8').write(s)
PY
fi

# AGP 8.10.0 is compatible with API 36 and requires Gradle 8.11.1.
ROOT_GRADLE="$ANDROID_ROOT/build.gradle"
python3 - "$ROOT_GRADLE" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'(com\.android\.tools\.build:gradle:)[0-9.]+', r'\g<1>8.10.0', s)
s = re.sub(r"(com\.android\.application\s+version\s+['\"])[0-9.]+(['\"])", r'\g<1>8.10.0\2', s)
s = re.sub(r"(com\.android\.library\s+version\s+['\"])[0-9.]+(['\"])", r'\g<1>8.10.0\2', s)
open(p, 'w', encoding='utf-8').write(s)
PY

WRAPPER="$ANDROID_ROOT/gradle/wrapper/gradle-wrapper.properties"
[[ -f "$WRAPPER" ]] || fail "gradle-wrapper.properties not found"
python3 - "$WRAPPER" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'^distributionUrl=.*$', 'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.11.1-all.zip', s, flags=re.M)
open(p, 'w', encoding='utf-8').write(s)
PY

MANIFEST="$APP/src/main/AndroidManifest.xml"
[[ -f "$MANIFEST" ]] || fail "AndroidManifest.xml not found"
python3 - "$MANIFEST" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
if 'androidx.core.content.FileProvider' not in s:
    provider = '''        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>\n'''
    if '</application>' not in s:
        raise SystemExit('</application> not found')
    s = s.replace('</application>', provider + '    </application>', 1)
    open(p, 'w', encoding='utf-8').write(s)
PY

echo "Squeezo native Android engine configured: compileSdk=36, targetSdk=36, AGP=8.10.0, Gradle=8.11.1, Media3=1.10.1"
