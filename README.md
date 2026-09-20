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

## Current MVP limitations

- Sync is user-triggered. A later version can schedule sync periodically.
- Tracking is intended for an explicitly active photo trip/session; mobile OS background restrictions still apply.
- The app currently matches every image without GPS in the tracked time range. Camera make/model filters are a planned enhancement.
- The native Android/iOS runner files are generated with `flutter create` so the repository stays focused on application code.

## Privacy

Location points remain on-device and are deleted according to the configured retention period. Only the interpolated latitude/longitude values for matched images are sent to your Immich server.

## License

MIT
