Beleza, vamos ajustar isso 😄

Você hoje tem 2 “mundos” diferentes:

* **Docker** (onde o exemplo original usava `/usr/local/Qt`, `/opt/android-sdk`, `/opt/android-ndk`)
* **Seu PC local**, onde você:

  * instalou **Qt com aqt** em `~/qt`
  * aparentemente tem o **Android SDK/NDK** em `~/Android/Sdk` (pelo caminho do `toolchainFile`)

Então, no `CMakePresets.json` faz mais sentido **apontar para o que você realmente tem em casa**, e não para aqueles caminhos de `/opt` e `/usr/local/Qt` que eram do projeto original / Docker.

---

## 1. Onde está o Qt instalado pelo aqt?

Com esse comando:

```bash
mkdir ~/qt
cd ~/qt
aqt install-qt linux android 5.15.2
```

O `aqt` normalmente cria algo como:

```text
/home/ivan/qt/5.15.2/gcc_64       # Qt desktop
/home/ivan/qt/5.15.2/android      # Qt para Android (no caso do arch "android")
```

Você pode confirmar com:

```bash
ls ~/qt/5.15.2
```

Se aparecer `gcc_64` e `android`, é isso mesmo.

---

## 2. Versão limpa do `CMakePresets.json` adaptada para sua máquina

Aqui vai uma sugestão já “limpa” e coerente com o que você descreveu (ajustei caminhos, removi `/opt/...`, mantive só o que realmente faz sentido e ainda adicionei um preset de **Release Android**):

```json
{
    "version": 3,
    "cmakeMinimumRequired": {
        "major": 3,
        "minor": 21,
        "patch": 0
    },

    "configurePresets": [
        {
            "name": "ccache-env",
            "hidden": true,
            "environment": {
                "CCACHE_BASEDIR": "${sourceDir}",
                "CCACHE_SLOPPINESS": "pch_defines,time_macros"
            }
        },

        {
            "name": "android",
            "hidden": true,
            "toolchainFile": "/home/ivan/Android/Sdk/ndk/android-ndk-r20b/build/cmake/android.toolchain.cmake",
            "cacheVariables": {
                "ANDROID_ABI": "armeabi-v7a",
                "ANDROID_PLATFORM": "23",
                "ANDROID_SDK": "/home/ivan/Android/Sdk",
                "ANDROID_BUILD_ABI_armeabi-v7a": "ON"
            },
            "environment": {
                "JAVA_HOME": "/usr/lib/jvm/java-1.8.0-openjdk-amd64",
                "ANDROID_SDK_ROOT": "/home/ivan/Android/Sdk",
                "ANDROID_NDK_ROOT": "/home/ivan/Android/Sdk/ndk/android-ndk-r20b"
            },
            "binaryDir": "${sourceDir}/build_android"
        },

        {
            "name": "Qt-desktop",
            "hidden": true,
            "cacheVariables": {
                "CMAKE_PREFIX_PATH": "/home/ivan/qt/5.15.2/gcc_64"
            },
            "binaryDir": "${sourceDir}/build"
        },

        {
            "name": "Qt-android",
            "hidden": true,
            "cacheVariables": {
                "CMAKE_PREFIX_PATH": "/home/ivan/qt/5.15.2/android",
                "CMAKE_FIND_ROOT_PATH_MODE_PACKAGE": "BOTH"
            }
        },

        {
            "name": "ci-ninja",
            "displayName": "Ninja",
            "description": "build usando Ninja",
            "inherits": [
                "ccache-env"
            ],
            "generator": "Ninja",
            "hidden": true
        },

        {
            "name": "ci-ninja-debug",
            "displayName": "Ninja Debug",
            "inherits": [
                "Qt-desktop",
                "ci-ninja"
            ],
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Debug"
            }
        },

        {
            "name": "ci-ninja-release",
            "displayName": "Ninja Release",
            "inherits": [
                "Qt-desktop",
                "ci-ninja"
            ],
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Release"
            }
        },

        {
            "name": "ci-ninja-android-debug",
            "displayName": "Ninja Android Debug",
            "inherits": [
                "Qt-android",
                "ci-ninja",
                "android"
            ],
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Debug"
            }
        },

        {
            "name": "ci-ninja-android-release",
            "displayName": "Ninja Android Release",
            "inherits": [
                "Qt-android",
                "ci-ninja",
                "android"
            ],
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Release"
            }
        }
    ]
}
```

---

## 3. O que eu mudei / removi e por quê

* **Caminhos de Qt**

  * Antes: `CMAKE_PREFIX_PATH`: `/usr/local/Qt/gcc_64` e `/usr/local/Qt/android`
  * Agora:

    * Desktop: `/home/ivan/qt/5.15.2/gcc_64`
    * Android: `/home/ivan/qt/5.15.2/android`
      → Isso casa com a instalação via `aqt`.

* **Caminhos de SDK/NDK**

  * Tirei `/opt/android-sdk` e `/opt/android-ndk` (eram do Docker do projeto original).
  * Usei `~/Android/Sdk` em:

    * `ANDROID_SDK`
    * `ANDROID_SDK_ROOT`
    * `ANDROID_NDK_ROOT` (`/home/ivan/Android/Sdk/ndk/android-ndk-r20b`)

* **Mantive o preset `android`**
  Ele é importante porque:

  * define `toolchainFile`
  * define ABI, platform etc
  * configura o `binaryDir` para `build_android`

* **Presets Qt-desktop / Qt-android**
  Continuam sendo apenas “pacotes” de variáveis para Qt:

  * `Qt-desktop` → CMAKE_PREFIX_PATH para desktop
  * `Qt-android` → CMAKE_PREFIX_PATH para Qt Android

* **Adicionei `ci-ninja-android-release`**
  Igual ao debug, mas com `CMAKE_BUILD_TYPE=Release`.

---

## 4. Como usar

Exemplos:

* Desktop Debug:

  ```bash
  cmake --preset ci-ninja-debug
  cmake --build build
  ```

* Desktop Release:

  ```bash
  cmake --preset ci-ninja-release
  cmake --build build
  ```

* Android Debug:

  ```bash
  cmake --preset ci-ninja-android-debug
  cmake --build build_android
  ```

* Android Release:

  ```bash
  cmake --preset ci-ninja-android-release
  cmake --build build_android
  ```

---

Se você me mandar a saída de:

```bash
ls ~/qt/5.15.2
ls ~/Android/Sdk
```

eu consigo ajustar os caminhos 100% certinho pro seu ambiente real (tipo se o Qt Android estiver em `android_armv7` em vez de `android`, por exemplo).

