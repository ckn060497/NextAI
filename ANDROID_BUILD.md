# Nexus AI Android build

This project now includes a complete Flutter Android platform project.

## Requirements
- Flutter 3.x
- Android Studio / Android SDK
- JDK 17

## Build APK
From the `frontend` directory:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

APK:
`build/app/outputs/flutter-apk/app-release.apk`

## Backend URL

The app defaults to `http://10.0.2.2:8000`, which is correct for an Android emulator when FastAPI is running on the development computer.

For a physical Android phone, replace the URL with the computer's LAN IP:

```bash
flutter build apk --release --dart-define=API_URL=http://192.168.1.10:8000
```

Make sure the FastAPI server is reachable from the phone and that the computer firewall allows port 8000.

## Debug APK

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8000
```

## Backend

Run the backend separately:

```bash
cd ../backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

The Android manifest permits cleartext HTTP because the supplied MVP uses a local HTTP backend. Use HTTPS for production.
