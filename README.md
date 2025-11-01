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