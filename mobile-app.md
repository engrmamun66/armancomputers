
### Run in Chrome (fast UI iteration only) 

```bash
flutter run -d chrome
```

Useful for quick layout checks only — this app targets Android, and flows like avatar upload (`image_picker`) behave differently on web and haven't been verified there.

### Run on Android emulator

```bash
flutter emulators --launch <emulator_id>   # or launch one from Android Studio
flutter run -d emulator-5554
```

`api_config.dart`'s default (`10.0.2.2`) already matches the emulator — no edit needed.

### Run on a real Android device
```bash
flutter devices
flutter run -d <device_id>
```

### Build APK

```bash
cd mobile-app
flutter build apk --debug      # debug APK, faster build, unoptimized
flutter build apk --release    # release APK, optimized + minified
```

Output:
- Debug: `build/app/outputs/flutter-apk/app-debug.apk`
- Release: `build/app/outputs/flutter-apk/app-release.apk`

Install to a connected/emulated device without going through `flutter run`:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
