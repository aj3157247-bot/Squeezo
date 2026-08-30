#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$ROOT/android/app"
ANDROID_ROOT="$ROOT/android"

SRC="$SCRIPT_DIR/android"
PKG="$APP/src/main/java/com/squeezo/app"
RES_XML="$APP/src/main/res/xml"

echo "========================================"
echo " Squeezo Native Android Setup"
echo "========================================"
echo "ROOT: $ROOT"
echo "ANDROID: $ANDROID_ROOT"
echo "APP: $APP"

if [[ ! -d "$APP" ]]; then
  echo "ERROR: Android project not found:"
  echo "$APP"
  exit 1
fi

# --------------------------------------------------
# 1. Check native source files
# --------------------------------------------------

for f in \
  "$SRC/com/squeezo/app/SqueezoVideoCompressorPlugin.java" \
  "$SRC/com/squeezo/app/MainActivity.java" \
  "$SRC/res/xml/file_paths.xml"; do

  if [[ ! -f "$f" ]]; then
    echo "ERROR: Native source file not found:"
    echo "$f"

    echo ""
    echo "Native repository tree:"
    find "$SCRIPT_DIR" -maxdepth 8 -type f | sort || true

    exit 1
  fi
done

echo "Native source files found."

# --------------------------------------------------
# 2. Copy Java files
# --------------------------------------------------

mkdir -p "$PKG"
mkdir -p "$RES_XML"

cp \
  "$SRC/com/squeezo/app/SqueezoVideoCompressorPlugin.java" \
  "$PKG/SqueezoVideoCompressorPlugin.java"

cp \
  "$SRC/com/squeezo/app/MainActivity.java" \
  "$PKG/MainActivity.java"

cp \
  "$SRC/res/xml/file_paths.xml" \
  "$RES_XML/file_paths.xml"

echo "Native Java files copied."

# --------------------------------------------------
# 3. Upgrade Android Gradle Plugin
# --------------------------------------------------

ROOT_GRADLE="$ANDROID_ROOT/build.gradle"

if [[ -f "$ROOT_GRADLE" ]]; then

  echo "Updating Android Gradle Plugin..."

  python3 - "$ROOT_GRADLE" <<'PY'
import sys
import re

p = sys.argv[1]

with open(p, encoding="utf-8") as f:
    s = f.read()

# AGP versions such as:
# com.android.application version '8.7.2'
s = re.sub(
    r"(com\.android\.application['\"]?\s+version\s+['\"])\d+\.\d+\.\d+(['\"])",
    r"\g<1>8.10.0\2",
    s
)

# Old buildscript style:
# com.android.tools.build:gradle:8.7.2
s = re.sub(
    r"(com\.android\.tools\.build:gradle:)\d+\.\d+\.\d+",
    r"\g<1>8.10.0",
    s
)

with open(p, "w", encoding="utf-8") as f:
    f.write(s)

print("AGP updated to 8.10.0")
PY

else
  echo "WARNING: $ROOT_GRADLE not found."
fi

# --------------------------------------------------
# 4. Upgrade Gradle wrapper
# --------------------------------------------------

WRAPPER="$ANDROID_ROOT/gradle/wrapper/gradle-wrapper.properties"

if [[ -f "$WRAPPER" ]]; then

  echo "Updating Gradle wrapper..."

  python3 - "$WRAPPER" <<'PY'
import sys
import re

p = sys.argv[1]

with open(p, encoding="utf-8") as f:
    s = f.read()

s = re.sub(
    r"distributionUrl=.*",
    "distributionUrl=https\\://services.gradle.org/distributions/gradle-8.11.1-all.zip",
    s
)

with open(p, "w", encoding="utf-8") as f:
    f.write(s)

print("Gradle wrapper updated to 8.11.1")
PY

else
  echo "WARNING: Gradle wrapper properties not found."
fi

# --------------------------------------------------
# 5. Update compileSdk / targetSdk
# --------------------------------------------------

APP_GRADLE="$APP/build.gradle"

if [[ ! -f "$APP_GRADLE" ]]; then
  echo "ERROR: app/build.gradle not found:"
  echo "$APP_GRADLE"
  exit 1
fi

echo "Updating compileSdk and targetSdk..."

python3 - "$APP_GRADLE" <<'PY'
import sys
import re

p = sys.argv[1]

with open(p, encoding="utf-8") as f:
    s = f.read()

# compileSdk 35 / compileSdkVersion 35
s = re.sub(
    r"\bcompileSdk(?:Version)?\s+35\b",
    "compileSdk 36",
    s
)

# If compileSdk exists with another numeric version.
s = re.sub(
    r"\bcompileSdk(?:Version)?\s+\d+\b",
    "compileSdk 36",
    s
)

# targetSdk 35 / targetSdkVersion 35
s = re.sub(
    r"\btargetSdk(?:Version)?\s+35\b",
    "targetSdk 36",
    s
)

# If targetSdk exists with another numeric version.
s = re.sub(
    r"\btargetSdk(?:Version)?\s+\d+\b",
    "targetSdk 36",
    s
)

with open(p, "w", encoding="utf-8") as f:
    f.write(s)

print("compileSdk = 36")
print("targetSdk  = 36")
PY

# --------------------------------------------------
# 6. Add Media3 dependencies
# --------------------------------------------------

echo "Adding Media3 dependencies..."

python3 - "$APP_GRADLE" <<'PY'
import sys

p = sys.argv[1]

with open(p, encoding="utf-8") as f:
    s = f.read()

# Remove previous Squeezo Media3 entries so versions cannot conflict.
lines = []

for line in s.splitlines():
    if "androidx.media3:" in line:
        continue
    lines.append(line)

s = "\n".join(lines) + "\n"

block = '''
    implementation "androidx.media3:media3-transformer:1.10.1"
    implementation "androidx.media3:media3-effect:1.10.1"
    implementation "androidx.media3:media3-common:1.10.1"
    implementation "androidx.media3:media3-exoplayer:1.10.1"
    implementation "androidx.media3:media3-datasource:1.10.1"
    implementation "androidx.media3:media3-muxer:1.10.1"
'''

marker = "dependencies {"

if marker not in s:
    raise SystemExit("ERROR: dependencies block not found")

s = s.replace(marker, marker + block, 1)

with open(p, "w", encoding="utf-8") as f:
    f.write(s)

print("Media3 1.10.1 configured.")
PY

# --------------------------------------------------
# 7. Add FileProvider
# --------------------------------------------------

MANIFEST="$APP/src/main/AndroidManifest.xml"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: AndroidManifest.xml not found:"
  echo "$MANIFEST"
  exit 1
fi

python3 - "$MANIFEST" <<'PY'
import sys

p = sys.argv[1]

with open(p, encoding="utf-8") as f:
    s = f.read()

if "androidx.core.content.FileProvider" not in s:

    provider = '''
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
'''

    if "</application>" not in s:
        raise SystemExit("ERROR: </application> not found")

    s = s.replace(
        "</application>",
        provider + "    </application>",
        1
    )

    with open(p, "w", encoding="utf-8") as f:
        f.write(s)

    print("FileProvider added.")

else:
    print("FileProvider already exists.")
PY

# --------------------------------------------------
# 8. Print final Android configuration
# --------------------------------------------------

echo ""
echo "========================================"
echo " FINAL ANDROID CONFIGURATION"
echo "========================================"

echo "--- AGP ---"
grep -R "com.android.tools.build:gradle\|com.android.application.*version" \
  "$ANDROID_ROOT" \
  --include="build.gradle" \
  --include="build.gradle.kts" \
  2>/dev/null || true

echo ""
echo "--- SDK ---"
grep -E "compileSdk|targetSdk" "$APP_GRADLE" || true

echo ""
echo "--- Media3 ---"
grep "androidx.media3:" "$APP_GRADLE" || true

echo ""
echo "========================================"
echo " Native Squeezo video engine applied."
echo "========================================"
