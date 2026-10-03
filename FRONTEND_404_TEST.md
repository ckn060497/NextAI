# Frontend 404 test

This package is configured to use the intentionally non-existent API URL:

`https://example.com/nexus-ai-api`

It is only for testing the Flutter frontend before the real backend is deployed.

## Expected behavior

When the app requests an endpoint that returns HTTP 404, the frontend should present its not-found/error UI rather than silently treating the response as successful.

When you deploy the real backend, replace the API URL with your real FastAPI URL.

## FlutLab

Upload this ZIP as a Flutter project. `pubspec.yaml` is at the archive root.
