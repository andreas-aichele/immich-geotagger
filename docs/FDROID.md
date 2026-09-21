# F-Droid publishing notes

Immich GeoTagger is prepared for source builds in the official F-Droid repository.

## Package ID

`io.github.andreasaichele.immichgeotagger`

This ID is stable and should not be changed after the first public F-Droid release.

## Free software dependencies

Android location tracking uses `libre_location`, which relies on the AOSP `LocationManager` and does not require Google Play Services.

The app source is licensed under MIT. `libre_location` is licensed under Apache-2.0.

## Flutter version

CI currently builds with Flutter 3.47.5. An F-Droid build recipe should pin the same Flutter source version, for example with:

```yaml
srclibs:
  - flutter@3.47.5
```

and build with the repository lockfile:

```sh
export PUB_CACHE=$(pwd)/.pub-cache
$$flutter$$/bin/flutter config --no-analytics
$$flutter$$/bin/flutter pub get --enforce-lockfile
$$flutter$$/bin/flutter build apk --release --build-name=<version> --build-number=<versionCode>
```

The expected APK is:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Version codes

Release tags use `vMAJOR.MINOR.PATCH`. The first F-Droid candidate is **v1.0.0** with Android version code **1000000**.

The deterministic Android version code is:

```text
MAJOR * 1,000,000 + MINOR * 1,000 + PATCH
```

Examples:

- `v1.0.0` -> `1000000`
- `v1.1.0` -> `1001000`
- `v1.0.0` -> `1000000`

GitHub release builds use the same mapping so F-Droid can reproduce the version metadata.

## Store metadata

Localized Fastlane metadata is available in:

```text
fastlane/metadata/android/
```

for English, German, French, Spanish, and Dutch.

## Submission

The official F-Droid submission still requires a merge request to the F-Droid `fdroiddata` repository containing the package build metadata. That should be created from the first tag using the stable package ID above.
