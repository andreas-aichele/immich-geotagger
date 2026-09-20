# Immich GeoTagger

A Flutter app for Android and iOS that records GPS positions in the background and applies interpolated coordinates to **Immich image assets that do not already contain a location**.

## Features

- Background GPS logging on Android and iOS
- Configurable measurement interval
- Timestamp-based linear interpolation between two GPS measurements
- Safety limit for maximum interpolation gap
- Updates only Immich images without existing GPS coordinates
- Configurable on-device retention period for location history
- Local history of photos updated by the app
- Immich API key stored using platform secure storage
- No cloud service required besides your own Immich instance

## How matching works

For a photo captured at `10:05`, with points at `10:00` and `10:10`, the app calculates the position proportionally between those points. It **never extrapolates** before the first or after the last point and rejects gaps larger than the configured maximum.

## Immich behavior

The app searches assets in the time range covered by the locally stored track, filters out assets that already have latitude/longitude, then updates matching assets through the Immich Assets API.

Immich's current API provides asset search and asset update endpoints, including latitude/longitude fields. The project uses `x-api-key` authentication.

## Getting started

1. Install Flutter 3.22+.
2. Clone this repository.
3. Generate native runners and configure permissions as described in [`docs/PLATFORM_SETUP.md`](docs/PLATFORM_SETUP.md).
4. Run:

```bash
flutter pub get
flutter test
flutter run
```

5. In Immich, create an API key with permissions sufficient to read/search assets and update assets.
6. Enter the Immich base URL and API key in Settings.
7. Start tracking.
8. After importing DSLR/mirrorless photos into Immich, tap **Sync now**.

## Installation

Prebuilt packages are available from the repository's [GitHub Releases](https://github.com/andreas-aichele/immich-geotagger/releases). Android users can install the APK directly. iOS builds are currently provided unsigned and require manual signing.

## Releases

Version tags beginning with `v` create a GitHub Release automatically.

```bash
git tag v0.1.0
git push origin v0.1.0
```

The release workflow builds and publishes:

- Android APK
- Android AAB
- unsigned iOS IPA

The iOS package is intentionally marked **unsigned**. A distributable iOS IPA requires Apple signing credentials and a provisioning profile.

## Development status

Immich GeoTagger is under active development. Sync is currently user-triggered, background behavior is subject to mobile operating-system restrictions, and camera-specific filtering is not yet available.

## Privacy

Location points remain on-device and are deleted according to the configured retention period. Only the interpolated latitude/longitude values for matched images are sent to your Immich server.

## License

MIT
