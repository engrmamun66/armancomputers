
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

1. On the device: Settings → About phone → tap "Build number" 7× to unlock Developer Options → enable **USB debugging**.
2. Connect via USB and accept the RSA fingerprint prompt on the device.
3. Find your machine's LAN IP (macOS Wi-Fi: `ipconfig getifaddr en0`) and start the backend bound to it (same command as above: `php artisan serve --host=0.0.0.0 --port=8000`).
4. Edit `baseUrl`/`origin` in `lib/core/api_config.dart` to `http://<your-lan-ip>:8000` (device and host machine must be on the same Wi-Fi/LAN).
5. Confirm the device shows up, then run:

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
