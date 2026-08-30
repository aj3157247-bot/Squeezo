#!/usr/bin/env bash
set -euo pipefail

# This script is run from the repository root after `npx cap add android`.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$ROOT/android/app"
SRC="$SCRIPT_DIR/android"
PKG="$APP/src/main/java/com/squeezo/app"
RES_XML="$APP/src/main/res/xml"

if [[ ! -d "$APP" ]]; then
  echo "ERROR: Android project not found at: $APP"
  exit 1
fi

for f in \
  "$SRC/com/squeezo/app/SqueezoVideoCompressorPlugin.java" \
  "$SRC/com/squeezo/app/MainActivity.java" \
  "$SRC/res/xml/file_paths.xml"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: Native source file not found: $f"
    echo "Repository native tree:"
    find "$SCRIPT_DIR" -maxdepth 6 -type f | sort || true
    exit 1
  fi
done

mkdir -p "$PKG" "$RES_XML"

cp "$SRC/com/squeezo/app/SqueezoVideoCompressorPlugin.java" "$PKG/SqueezoVideoCompressorPlugin.java"
cp "$SRC/com/squeezo/app/MainActivity.java" "$PKG/MainActivity.java"
cp "$SRC/res/xml/file_paths.xml" "$RES_XML/file_paths.xml"

# Add Media3 dependencies once.
python3 - "$APP/build.gradle" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
block = '''\n    implementation "androidx.media3:media3-transformer:1.11.0"\n    implementation "androidx.media3:media3-effect:1.11.0"\n    implementation "androidx.media3:media3-common:1.11.0"\n'''
if 'androidx.media3:media3-transformer' not in s:
    marker = 'dependencies {'
    if marker not in s:
        raise SystemExit('dependencies block not found in ' + p)
    s = s.replace(marker, marker + block, 1)
    open(p, 'w', encoding='utf-8').write(s)
PY

# Add FileProvider once. The native plugin uses it for sharing exported files.
python3 - "$APP/src/main/AndroidManifest.xml" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
if 'androidx.core.content.FileProvider' not in s:
    provider = '''\n        <provider\n            android:name="androidx.core.content.FileProvider"\n            android:authorities="${applicationId}.fileprovider"\n            android:exported="false"\n            android:grantUriPermissions="true">\n            <meta-data\n                android:name="android.support.FILE_PROVIDER_PATHS"\n                android:resource="@xml/file_paths" />\n        </provider>'''
    if '</application>' not in s:
        raise SystemExit('</application> not found in ' + p)
    s = s.replace('</application>', provider + '\n    </application>', 1)
    open(p, 'w', encoding='utf-8').write(s)
PY

echo "Native Squeezo video engine applied successfully."
echo "Plugin: $PKG/SqueezoVideoCompressorPlugin.java"
