#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/android/app"
PKG="$APP/src/main/java/com/squeezo/app"
mkdir -p "$PKG" "$APP/src/main/res/xml"
cp "$ROOT/native/android/com/squeezo/app/SqueezoVideoCompressorPlugin.java" "$PKG/"
cp "$ROOT/native/android/com/squeezo/app/MainActivity.java" "$PKG/"
cp "$ROOT/native/android/res/xml/file_paths.xml" "$APP/src/main/res/xml/file_paths.xml"

python3 - "$APP/build.gradle" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read()
block='''\n    implementation "androidx.media3:media3-transformer:1.11.0"\n    implementation "androidx.media3:media3-effect:1.11.0"\n    implementation "androidx.media3:media3-common:1.11.0"\n'''
if 'androidx.media3:media3-transformer' not in s:
    marker='dependencies {'
    if marker not in s: raise SystemExit('dependencies block not found')
    s=s.replace(marker, marker+block, 1)
open(p,'w').write(s)
PY
python3 - "$APP/src/main/AndroidManifest.xml" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read()
provider='''\n        <provider\n            android:name="androidx.core.content.FileProvider"\n            android:authorities="${applicationId}.fileprovider"\n            android:exported="false"\n            android:grantUriPermissions="true">\n            <meta-data\n                android:name="android.support.FILE_PROVIDER_PATHS"\n                android:resource="@xml/file_paths" />\n        </provider>'''
if 'androidx.core.content.FileProvider' not in s:
    s=s.replace('</application>', provider+'\n    </application>', 1)
open(p,'w').write(s)
PY
