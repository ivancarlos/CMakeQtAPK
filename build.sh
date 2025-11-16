#!/usr/bin/env bash

test -d build_android && rm -rf build_android

# .so
#cmake --preset ci-ninja-android-release
#cmake --build build_android

./android-platform-manager.sh profile-load CMakeQtAPK

# 1) Configurar (gera build_android)
cmake --preset ci-ninja-android-release

# 2) Construir o alvo 'apk'
cmake --build build_android --target apk

exit 0


