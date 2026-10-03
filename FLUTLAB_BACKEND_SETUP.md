# FlutLab + Nexus AI backend

The Flutter app is configured to use the FastAPI backend through the compile-time `API_URL` value.

## Important

`10.0.2.2:8000` only works when an Android emulator can reach a FastAPI server running on the host computer. A FlutLab-hosted build cannot use `10.0.2.2` to reach your local computer.

For FlutLab, deploy the `backend/` directory to a public HTTPS URL, for example:

`https://your-api.example.com`

Then build/run the Flutter project with:

```bash
flutter build apk --dart-define=API_URL=https://your-api.example.com
```

Or, for web:

```bash
flutter run -d chrome --dart-define=API_URL=https://your-api.example.com
```

The backend's `/health` endpoint should return JSON containing `ok: true` before the Flutter app is expected to work.

## Local development

Android emulator:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8000
```

Physical Android phone on the same LAN:

```bash
flutter run --dart-define=API_URL=http://YOUR_COMPUTER_LAN_IP:8000
```

Flutter web on the same computer as the backend:

```bash
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000
```

The backend keeps AI credentials server-side in `backend/.env`; do not put an AI API key into Flutter.
