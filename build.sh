#!/usr/bin/env bash

cmake --preset ci-ninja-android-release
cmake --build build_android

exit 0


