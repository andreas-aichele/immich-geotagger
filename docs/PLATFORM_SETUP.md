# Platform setup

Generate the standard native Flutter runners once after cloning:

```bash
flutter create --platforms=android,ios .
flutter pub get
```

Then apply the permissions below. Do not overwrite `lib/`, `test/`, `pubspec.yaml`, or `analysis_options.yaml` when resolving conflicts.

## Android

Add these permissions to `android/app/src/main/AndroidManifest.xml` above `<application>`:

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
```

Android 11+ requires the user to grant **Allow all the time** from the system app settings for reliable background tracking.

## iOS

Add to `ios/Runner/Info.plist`:

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
