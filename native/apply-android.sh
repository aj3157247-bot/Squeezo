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

[[ -d "$APP" ]] || fail "Android project not found: $APP"
[[ -f "$SRC/com/squeezo/app/SqueezoVideoCompressorPlugin.java" ]] || fail "Missing native plugin source"
[[ -f "$SRC/com/squeezo/app/MainActivity.java" ]] || fail "Missing MainActivity source"
[[ -f "$SRC/res/xml/file_paths.xml" ]] || fail "Missing file_paths.xml"
[[ -f "$ANDROID_ROOT/build.gradle" ]] || fail "Missing android/build.gradle"
[[ -f "$APP/build.gradle" ]] || fail "Missing android/app/build.gradle"

mkdir -p "$PKG" "$RES_XML"
cp "$SRC/com/squeezo/app/SqueezoVideoCompressorPlugin.java" "$PKG/SqueezoVideoCompressorPlugin.java"
cp "$SRC/com/squeezo/app/MainActivity.java" "$PKG/MainActivity.java"
cp "$SRC/res/xml/file_paths.xml" "$RES_XML/file_paths.xml"

# Capacitor 7 normally generates SDK values in variables.gradle.
# Update both variables.gradle and app/build.gradle so no template variant can remain on API 35.
if [[ -f "$ANDROID_ROOT/variables.gradle" ]]; then
  python3 - "$ANDROID_ROOT/variables.gradle" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'(compileSdkVersion\s*=\s*)\d+', r'\g<1>36', s)
s = re.sub(r'(targetSdkVersion\s*=\s*)\d+', r'\g<1>36', s)
s = re.sub(r'(compileSdk\s*=\s*)\d+', r'\g<1>36', s)
s = re.sub(r'(targetSdk\s*=\s*)\d+', r'\g<1>36', s)
open(p, 'w', encoding='utf-8').write(s)
PY
fi

python3 - "$APP/build.gradle" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
# Handle both Groovy forms used by Capacitor templates.
s = re.sub(r'\bcompileSdkVersion\s+\d+', 'compileSdkVersion 36', s)
s = re.sub(r'\bcompileSdk\s+\d+', 'compileSdk 36', s)
s = re.sub(r'\btargetSdkVersion\s+\d+', 'targetSdkVersion 36', s)
s = re.sub(r'\btargetSdk\s+\d+', 'targetSdk 36', s)
# Remove every old Media3 implementation line; the block below is the single source of truth.
s = '\n'.join(line for line in s.splitlines() if 'androidx.media3:' not in line).rstrip() + '\n'
marker = 'dependencies {'
if marker not in s:
    raise SystemExit('dependencies block not found in app/build.gradle')
block = '''    implementation "androidx.media3:media3-transformer:1.10.1"\n    implementation "androidx.media3:media3-effect:1.10.1"\n    implementation "androidx.media3:media3-common:1.10.1"\n    implementation "androidx.media3:media3-exoplayer:1.10.1"\n    implementation "androidx.media3:media3-datasource:1.10.1"\n    implementation "androidx.media3:media3-muxer:1.10.1"\n'''
s = s.replace(marker, marker + '\n' + block, 1)
open(p, 'w', encoding='utf-8').write(s)
PY

# Update AGP wherever Capacitor's generated template declares it.
python3 - "$ANDROID_ROOT" <<'PY'
import re, sys
root = sys.argv[1]
for rel in ('build.gradle', 'settings.gradle', 'settings.gradle.kts'):
    p = f'{root}/{rel}'
    try:
        s = open(p, encoding='utf-8').read()
    except FileNotFoundError:
        continue
    s = re.sub(r'(com\.android\.tools\.build:gradle:)\d+\.\d+\.\d+', r'\g<1>8.10.0', s)
    s = re.sub(r'(id\s+[\'\"]com\.android\.(?:application|library)[\'\"]\s+version\s+[\'\"])\d+\.\d+\.\d+([\'\"])', r'\g<1>8.10.0\2', s)
    open(p, 'w', encoding='utf-8').write(s)
PY

WRAPPER="$ANDROID_ROOT/gradle/wrapper/gradle-wrapper.properties"
[[ -f "$WRAPPER" ]] || fail "Missing Gradle wrapper properties"
python3 - "$WRAPPER" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'^distributionUrl=.*$', 'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.11.1-all.zip', s, flags=re.M)
open(p, 'w', encoding='utf-8').write(s)
PY

MANIFEST="$APP/src/main/AndroidManifest.xml"
[[ -f "$MANIFEST" ]] || fail "Missing AndroidManifest.xml"
python3 - "$MANIFEST" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
if 'androidx.core.content.FileProvider' not in s:
    provider = '''        <provider\n            android:name="androidx.core.content.FileProvider"\n            android:authorities="${applicationId}.fileprovider"\n            android:exported="false"\n            android:grantUriPermissions="true">\n            <meta-data\n                android:name="android.support.FILE_PROVIDER_PATHS"\n                android:resource="@xml/file_paths" />\n        </provider>\n'''
    if '</application>' not in s:
        raise SystemExit('</application> not found')
    s = s.replace('</application>', provider + '    </application>', 1)
    open(p, 'w', encoding='utf-8').write(s)
PY

echo '--- FINAL CONFIG ---'
grep -R -E 'com\.android\.tools\.build:gradle|com\.android\.(application|library).*version' "$ANDROID_ROOT" --include='build.gradle' --include='settings.gradle' --include='settings.gradle.kts' 2>/dev/null || true
grep -R -E 'compileSdk|targetSdk' "$ANDROID_ROOT" --include='variables.gradle' --include='build.gradle' 2>/dev/null || true
grep 'androidx.media3:' "$APP/build.gradle" || true
grep '^distributionUrl=' "$WRAPPER"
