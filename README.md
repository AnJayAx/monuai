# monuai

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

flutter clean
flutter pub get
flutter run

If the app cannot download and start itself,
- Restart ADB cleanly
adb kill-server
adb start-server
adb devices

- Flutter run again
cd "d:\SIT\AAI3001 Computer Vision\Project\monuai"
flutter run

- Install/Replace APK and launch the app
adb install -r -t "d:\SIT\AAI3001 Computer Vision\Project\monuai\build\app\outputs\flutter-apk\app-debug.apk"
adb shell am start -n com.example.monuai/com.example.monuai.MainActivity

- Upgrading flutter then attach
flutter upgrade
flutter attach

## Android Troubleshooting (Gradle Import Errors)

If VS Code shows errors like "phased build action failed" or cannot create tasks for `camera_android_camerax`:

1. These originate from the Java/Gradle import (Red Hat Java extension) not Flutter itself.
2. We disable its Gradle model import via `.vscode/settings.json` to stop noisy errors.
3. Multi-drive layout (project on `D:`; Pub cache on `C:`) can confuse Gradle during model queries. Optional fix: move project to `C:` or set `PUB_CACHE` to a folder on `D:` then run `flutter pub cache repair`.
4. Added `org.gradle.configuration-cache=false` and `org.gradle.parallel=false` in `android/gradle.properties` to avoid phased action instability.
5. Build the app using Flutter CLI commands below; ignore VS Code Java Problems panel if build succeeds.

```powershell
flutter clean
flutter pub get
flutter doctor -v
flutter run
```

If build still fails, confirm Gradle version (see `android/gradle/wrapper/gradle-wrapper.properties`). Flutter may expect a lower version; downgrade by editing `distributionUrl` to the version recommended by `flutter doctor` then repeat the steps above.