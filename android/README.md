# Nexus AI Android project

This Android module is included so the Flutter project can build an APK directly.
`local.properties` is intentionally not included because it contains a machine-specific Flutter SDK path; Flutter/Android Studio creates it automatically.

The `gradlew` scripts download Gradle 8.10.2 on first use if it is not already available.
