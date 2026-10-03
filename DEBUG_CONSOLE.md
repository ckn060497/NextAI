# Nexus AI Debug Console

This version adds an in-app **Debug Console** available from the bug icon in the Home screen.

It logs:
- startup and API URL
- GET/POST/upload requests
- HTTP status codes
- API errors and backend connection failures
- Flutter framework errors
- uncaught asynchronous errors

Important: build-time failures (pub get, Dart compilation, Gradle/Xcode/Web compilation) happen before the app starts, so they cannot be displayed by Dart code. Those must still be read from FlutLab's Build output.
