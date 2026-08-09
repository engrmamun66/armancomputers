
### Run in Chrome (fast UI iteration only) 

```bash
flutter run -d chrome --dart-define-from-file=.env
```

Useful for quick layout checks only — this app targets Android, and flows like avatar upload (`image_picker`) behave differently on web and haven't been verified there.

### Run on Android emulator

```bash
flutter emulators --launch <emulator_id>   # or launch one from Android Studio
flutter run -d emulator-5554 --dart-define-from-file=.env
```

### Run on a real Android device
```bash
flutter devices
flutter run -d 0G02A20X4000157C --dart-define-from-file=.env
```

### Build APK

```bash
cd mobile-app
flutter build apk --debug --dart-define-from-file=.env      # debug APK, faster build, unoptimized
flutter build apk --release --dart-define-from-file=.env    # release APK, optimized + minified
```

Output:
- Debug: `build/app/outputs/flutter-apk/app-debug.apk`
- Release: `build/app/outputs/flutter-apk/app-release.apk`

Install to a connected/emulated device without going through `flutter run`:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
