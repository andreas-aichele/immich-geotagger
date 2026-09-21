# Platform setup

## Local development and GitHub

Android platform sources and `pubspec.lock` are version controlled. After cloning:

```bash
flutter pub get
flutter run
```

Before starting work, pull the latest changes with a clean working tree. Use a branch for each change, run `flutter analyze` and `flutter test`, then commit and push. GitHub AI changes should also use branches and pull requests. After merging, pull the changes locally and run `flutter pub get` when dependencies changed.

Commit application code, tests, platform sources, `.metadata`, and `pubspec.lock`. Keep build output, caches, local SDK paths, IDE settings, and signing keys out of Git. Do not regenerate Android with `flutter create`; edit the tracked platform files directly.

## Android

Permissions and the app icon are already configured in `android/`. Edit `android/app/src/main/AndroidManifest.xml` when permissions need to change. The location permissions include:

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
```

Android 11+ requires the user to grant **Allow all the time** from the system app settings for reliable background tracking.

Release signing is configured in `android/app/build.gradle.kts`. GitHub Actions restores the key from the existing Android signing secrets. Local builds use debug signing unless `android/key.properties` and a keystore are provided; both are ignored by Git. The old `tool/configure_android_signing.py` is no longer needed during builds.

## iOS

iOS remains generated and ignored by Git. On macOS, prepare it with:

```bash
flutter create --platforms=ios .
python3 tool/configure_platforms.py
flutter pub get
```

The configuration script applies the settings below to iOS only. The release workflow follows the same process.

The generated `ios/Runner/Info.plist` receives:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Immich GeoTagger records your location to geotag photos from an external camera.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Immich GeoTagger records location in the background while a photo trip is active.</string>
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
```

In Xcode, enable **Signing & Capabilities → Background Modes → Location updates**.

Important iOS limitation: if the user force-quits the app, iOS normally stops continuous background location delivery until the app is opened again. Background tracking also requires a clear user-facing purpose for App Store review.
