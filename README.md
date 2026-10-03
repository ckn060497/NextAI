# Nexus AI — Full Working MVP

Cross-platform all-in-one AI workspace: Android + Web frontend and FastAPI backend.

## What works now
- Email/password registration and login
- JWT authentication
- Persistent chats and messages
- AI provider abstraction
- Built-in demo AI provider (works without API keys)
- Optional OpenAI-compatible provider through environment variables
- File upload and file metadata
- Projects
- Agents with configurable system prompts
- Research endpoint
- Image-generation endpoint abstraction
- Usage endpoint
- SQLite by default; PostgreSQL-ready architecture
- Responsive Flutter UI

## Quick start

### Backend
```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate
# Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

The API runs at http://127.0.0.1:8000.

### Flutter frontend
Use Flutter 3.x.

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

For Android emulator, the backend URL is normally `http://10.0.2.2:8000`.
For a physical phone, use the computer's LAN IP, e.g. `http://192.168.1.10:8000`.

The app defaults to demo mode, so it works immediately. Set the API URL at build time:
```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8000
```

## Optional real AI provider

Copy `.env.example` to `.env` and set:
- `AI_PROVIDER=openai_compatible`
- `AI_BASE_URL`
- `AI_API_KEY`
- `AI_MODEL`

Only the backend sees the API key.

## Production checklist
Use HTTPS, PostgreSQL, object storage, a secret manager, email verification, refresh-token rotation, rate limiting, malware scanning for uploads, background workers, observability, and provider-specific safety controls before production deployment.


## Nexus AI frontend ↔ backend configuration

The Flutter app reads the backend URL from the compile-time `API_URL` variable. The source default is `http://10.0.2.2:8000`, which is appropriate for an Android emulator when FastAPI is running on the host computer.

Examples:

- Android emulator: `flutter run --dart-define=API_URL=http://10.0.2.2:8000`
- Physical Android device on the same LAN: `flutter run --dart-define=API_URL=http://192.168.1.10:8000` (replace with the computer's LAN IP)
- Deployed backend: `flutter build apk --dart-define=API_URL=https://api.example.com`
- Flutter web served on the same computer as the backend: `flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000`

The backend exposes `/health`, authentication, chats/messages, projects, agents, files, research, images, and usage endpoints. The Flutter API client now checks HTTP errors, handles timeouts/network failures, and sends the JWT on authenticated requests and file uploads.

### FlutLab

FlutLab can build the Flutter frontend, but it does not make the Python FastAPI server available at `10.0.2.2`. For a FlutLab build to reach the backend, deploy the `backend/` service to a publicly reachable HTTPS URL and build/run the Flutter project with that URL as `API_URL`. Keep AI provider secrets in the backend environment; never put the AI API key in Flutter.
