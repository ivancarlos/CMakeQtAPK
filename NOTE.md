Boa, agora ficou claro o que tá pegando 👍

### 1. O que o log está dizendo

Aqui é o ponto importante:

```text
Android build platform: android-36
...
Error while executing process /home/ivan/Android/Sdk/build-tools/28.0.3/aidl ...
/home/ivan/Android/Sdk/platforms/android-36/framework.aidl:1 malformed preprocessed file line:
'@JavaOnlyStableParcelable parcelable android.accessibilityservice.AccessibilityGestureEvent;'
```

Traduzindo:

* O **androiddeployqt** escolheu usar o **SDK platform `android-36`**.
* Mas o **`aidl`** que ele está rodando é o da **build-tools 28.0.3**.
* O `framework.aidl` do Android 36 usa anotação nova (`@JavaOnlyStableParcelable`) que esse `aidl` velho **não entende**.
* Resultado: `compileDebugAidl FAILED` → build do APK falha.

Ou seja:
👉 **SDK muito novo + build-tools (e Qt) antigos = erro de AIDL.**

O resto do log (warnings de *Mapping new ns* e os `-- Skipping ... qsvgicon ...`) é barulho, pode ignorar por enquanto.

---

### 2. Como resolver (caminho mais simples)

Você está com Qt 5.15.2 + NDK r20b, que foram pensados pra APIs tipo 23–30.
Misturar isso com **platform android-36** é pedir dor de cabeça.

O mais tranquilo é:

#### Passo 1 – Instalar um platform mais antigo (ex: android-28) e manter build-tools 28.0.3

No terminal:

```bash
cd "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"

./sdkmanager "platforms;android-28" "build-tools;28.0.3"
```

Se não tiver `cmdline-tools/latest`, pode ser algo como `cmdline-tools/bin`.

#### Passo 2 – (Opcional mas recomendado) remover o platform 36

Pra garantir que o Qt não escolha ele de novo:

```bash
./sdkmanager --uninstall "platforms;android-36"
```

Assim o androiddeployqt vai usar o **maior platform disponível** que ele encontrar, por exemplo `android-28`, que casa com as build-tools 28.0.3.

#### Passo 3 – Ajustar o preset (pra ficar coerente)

No seu `CMakePresets.json`, no preset `"android"`, você tá com:

```json
"ANDROID_PLATFORM": "23"
```

Pode subir pra 28:

```json
"ANDROID_PLATFORM": "28"
```

Isso ajuda a manter tudo consistente (CMake, NDK, SDK).

#### Passo 4 – Limpar e reconstruir

Apaga o build antigo e refaz:

```bash
rm -rf build_android

cmake --preset ci-ninja-android-release
cmake --build build_android --target apk
```

Depois procure o APK:

```bash
find build_android -name "*.apk"
```

---

### 3. Checar se não tem variável de ambiente atrapalhando

No log aparece:

```text
Android build platform: android-36
```

Mesmo você tendo `ANDROID_PLATFORM=23` no preset.
Isso pode ser porque alguma var de ambiente está mandando usar a plataforma mais alta.

Dá uma olhada rapidinho:

```bash
env | grep ANDROID_
```

Se aparecer algo como:

* `ANDROID_API_VERSION=android-36`
  ou
* `ANDROID_PLATFORM=android-36`

aí é só **remover ou ajustar**, por exemplo:

```bash
unset ANDROID_API_VERSION
export ANDROID_PLATFORM=android-28
```

(Se não aparecer nada disso, beleza, só seguir os passos 1–4 mesmo.)

---

### 4. Sobre os avisos de plugins que foram “skipped”

```text
-- Skipping ... qsvgicon_armeabi-v7a.so. It has unmet dependencies: libQt5Svg_armeabi-v7a.so,libQt5Widgets_armeabi-v7a.so.
```

Isso só significa que o Qt Android que você instalou **não tem os módulos Svg/Widgets**.
Como o exemplo usa **Qt Quick** (QML) e não Qt Widgets, esses avisos **podem ser ignorados**.

---

Se você fizer esses passos e ainda der erro, copia só o novo trecho de erro que aparecer que eu te ajudo a depurar o próximo round 👀📱

