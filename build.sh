#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026 команда S.T.A.R.K.
#
# Сборка P.L.I.S. в .apk без Gradle и без сторонних библиотек.
# Нужны: JDK 17+, Android SDK (platforms + build-tools), утилита zip.
#
#   ./build.sh            собрать приложение
#   ./build.sh --clean    удалить результаты сборки
#
# Переменные окружения:
#   ANDROID_HOME (или ANDROID_SDK_ROOT)  путь к Android SDK
#   PLIS_KEYSTORE_B64    ключ подписи релиза, закодированный в base64 (так он хранится в секретах GitHub)
#   PLIS_KEY_ALIAS       имя ключа внутри хранилища (по умолчанию plis)
#   PLIS_KS_PASS         пароль хранилища
#   PLIS_KEY_PASS        пароль ключа (по умолчанию тот же, что у хранилища)
# Если ключ не задан, приложение подписывается тестовым ключом (.keys/debug.jks).
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "--clean" ]; then
  rm -rf build dist
  echo "Очищено."
  exit 0
fi

die() { echo "Ошибка: $*" >&2; exit 1; }

for tool in java javac keytool zip base64; do
  command -v "$tool" >/dev/null 2>&1 || die "не найдена программа '$tool'"
done

VERSION="$(tr -d '[:space:]' < VERSION)"
IFS=. read -r V_MAJOR V_MINOR V_PATCH <<<"$VERSION"
VERSION_CODE=$(( V_MAJOR * 10000 + V_MINOR * 100 + V_PATCH ))
MIN_SDK=24
TARGET_SDK=34

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[ -n "$SDK" ] && [ -d "$SDK" ] || die "не найден Android SDK: задайте ANDROID_HOME"

BT="$(ls -d "$SDK"/build-tools/*/ 2>/dev/null | sort -V | tail -n1 || true)"; BT="${BT%/}"
PLATFORM="$(ls -d "$SDK"/platforms/android-*/ 2>/dev/null | sort -V | tail -n1 || true)"; PLATFORM="${PLATFORM%/}"
[ -n "$BT" ] || die "в SDK нет build-tools"
[ -n "$PLATFORM" ] && [ -f "$PLATFORM/android.jar" ] || die "в SDK нет platforms/android-*/android.jar"
ANDROID_JAR="$PLATFORM/android.jar"
for tool in aapt2 d8 zipalign apksigner; do
  [ -x "$BT/$tool" ] || die "в $BT нет '$tool'"
done

echo "== P.L.I.S. $VERSION (код версии $VERSION_CODE)"
echo "   build-tools: $(basename "$BT"), платформа: $(basename "$PLATFORM")"

rm -rf build
mkdir -p build/assets build/classes build/dex dist
cp web/index.html build/assets/index.html

echo "== 1/6 ресурсы"
"$BT/aapt2" compile --dir android/res -o build/res.zip
"$BT/aapt2" link --auto-add-overlay -o build/base.apk -I "$ANDROID_JAR" \
  --manifest android/AndroidManifest.xml -R build/res.zip -A build/assets \
  --min-sdk-version "$MIN_SDK" --target-sdk-version "$TARGET_SDK" \
  --version-code "$VERSION_CODE" --version-name "$VERSION"

echo "== 2/6 Java"
find android/src -name '*.java' > build/sources.txt
javac --release 8 -encoding UTF-8 -classpath "$ANDROID_JAR" -d build/classes @build/sources.txt

echo "== 3/6 dex"
find build/classes -name '*.class' > build/classes.txt
"$BT/d8" --release --min-api "$MIN_SDK" --lib "$ANDROID_JAR" --output build/dex @build/classes.txt
(cd build/dex && zip -q ../base.apk classes.dex)

echo "== 4/6 выравнивание"
"$BT/zipalign" -f -p 4 build/base.apk build/aligned.apk

echo "== 5/6 подпись"
SUFFIX=""
if [ -n "${PLIS_KEYSTORE_B64:-}" ]; then
  [ -n "${PLIS_KS_PASS:-}" ] || die "задан PLIS_KEYSTORE_B64, но нет PLIS_KS_PASS"
  echo "$PLIS_KEYSTORE_B64" | base64 -d > build/release.jks
  KS="build/release.jks"
  KEY_ALIAS="${PLIS_KEY_ALIAS:-plis}"
  export PLIS_KEY_PASS="${PLIS_KEY_PASS:-$PLIS_KS_PASS}"
else
  echo "   ключ релиза не задан: подпись ТЕСТОВАЯ (такое приложение нельзя обновить релизным)"
  KS=".keys/debug.jks"
  KEY_ALIAS="plis-debug"
  export PLIS_KS_PASS="plis-debug" PLIS_KEY_PASS="plis-debug"
  SUFFIX="-debug"
  if [ ! -f "$KS" ]; then
    mkdir -p .keys
    keytool -genkeypair -keystore "$KS" -storepass "$PLIS_KS_PASS" -keypass "$PLIS_KEY_PASS" \
      -alias "$KEY_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
      -dname "CN=P.L.I.S. debug" >/dev/null
  fi
fi
OUT="dist/plis-${VERSION}${SUFFIX}.apk"
"$BT/apksigner" sign --ks "$KS" --ks-key-alias "$KEY_ALIAS" \
  --ks-pass env:PLIS_KS_PASS --key-pass env:PLIS_KEY_PASS \
  --out "$OUT" build/aligned.apk
rm -f build/release.jks

echo "== 6/6 проверка подписи"
"$BT/apksigner" verify "$OUT"

echo "== Готово: $OUT ($(du -h "$OUT" | cut -f1))"
